#!/usr/bin/env bash
# ==============================================================================
# homelab-backup-semanal.sh
# Rotina Consolidada de Backup do Homelab (disk3 local + Pop!_OS remoto)
# Política:
#   1. Snapshot completo gravado em staging no disk3 e promovido atomicamente
#   2. Dumps reais dos bancos (Immich, Nextcloud, Karteman, etc.) + dados + configs
#   3. Se o Pop!_OS (192.168.0.16) estiver online, sincroniza para /mnt/storage_930/Backups_Homelab
#   4. Retenção determinística de N backups (padrão 7): ao gerar o 8º, remove o mais antigo
# ==============================================================================

set -euo pipefail

# 1. Carregar variáveis de ambiente
CONFIG_FILE="/data/config.env"
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
elif [[ -f "/home/umbrel/umbrelos-scripts/config.env" ]]; then
    # shellcheck disable=SC1091
    source "/home/umbrel/umbrelos-scripts/config.env"
fi

SYSTEM_PASSWORD="${SYSTEM_PASSWORD:-}"
POPOS_HOST="${POPOS_HOST:-192.168.0.16}"
POPOS_USER="${POPOS_USER:-rezendepauloh}"
POPOS_DEST="${POPOS_DEST_DIR:-/mnt/storage_930/Backups_Homelab}"
SSH_KEY="${POPOS_SSH_KEY:-/home/umbrel/.ssh/id_ed25519}"
RETENTION="${BACKUP_RETENTION_COUNT:-${BACKUP_RETENTION_DAYS:-7}}"
if ! [[ "$RETENTION" =~ ^[0-9]+$ ]] || [[ "$RETENTION" -lt 1 ]]; then
    RETENTION=7
fi

DISK3_BWLIMIT="${DISK3_RSYNC_BWLIMIT:-15000}"
POPOS_BWLIMIT="${POPOS_RSYNC_BWLIMIT:-25000}"

DISK3_BACKUPS="/home/umbrel/umbrel/external/disk3/backups"
TIMESTAMP="$(date +'%Y-%m-%d_%H%M%S')"
BACKUP_NAME="backup_${TIMESTAMP}"
STAGE_DEST="${DISK3_BACKUPS}/.inprogress_${BACKUP_NAME}"
FINAL_DEST="${DISK3_BACKUPS}/${BACKUP_NAME}"
LOG_FILE="/data/homelab-backup.log"
LOCK_FILE="/run/lock/homelab-backup.lock"

# Garantir log com permissões restritas
touch "$LOG_FILE" 2>/dev/null || true
chmod 640 "$LOG_FILE" 2>/dev/null || true
exec >> "$LOG_FILE" 2>&1

# Impedir execuções simultâneas
mkdir -p "$(dirname "$LOCK_FILE")" 2>/dev/null || true
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    echo "[!] Outra instância de homelab-backup-semanal.sh já está em execução ($(date)). Abortando."
    exit 0
fi

echo "========================================================================"
echo "=== INÍCIO DA ROTINA DE BACKUP CONSOLIDADO: $(date) ==="
echo "========================================================================"

# Helpers
run_rsync() {
    local rc=0
    nice -n 19 ionice -c3 rsync "$@" || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        return 0
    elif [[ "$rc" -eq 24 ]]; then
        echo "    [!] Aviso rsync (code 24): arquivos de origem desapareceram durante a cópia (não fatal)."
        return 0
    else
        echo "    [!] ERRO rsync (código ${rc})!"
        return "$rc"
    fi
}

apply_local_retention() {
    local target_dir="$1"
    local keep="$2"
    [[ -d "$target_dir" ]] || return 0
    mapfile -t backups < <(find "$target_dir" -maxdepth 1 -mindepth 1 -type d -name 'backup_*' -printf '%f\n' | sort -r)
    local total=${#backups[@]}
    if [[ "$total" -gt "$keep" ]]; then
        local excess=$((total - keep))
        echo "    -> Removendo ${excess} snapshot(s) antigo(s) em ${target_dir} (mantendo ${keep})..."
        for (( i=keep; i<total; i++ )); do
            local old_backup="${backups[i]}"
            if [[ -n "$old_backup" && -d "${target_dir}/${old_backup}" ]]; then
                echo "       Excluindo local: ${old_backup}"
                nice -n 19 ionice -c3 rm -rf "${target_dir}/${old_backup}" || true
            fi
        done
    else
        echo "    -> Retenção local dentro da cota (${total}/${keep} snapshots)."
    fi
}

# Verificar se disk3 está montado e gravável
if ! mountpoint -q /home/umbrel/umbrel/external/disk3; then
    echo "[!] ERRO CRÍTICO: disk3 não está montado. Abortando backup para proteger o sistema."
    exit 1
fi
if ! touch /home/umbrel/umbrel/external/disk3/.rw_check 2>/dev/null; then
    echo "[!] ERRO CRÍTICO: disk3 está somente-leitura ou com erro de I/O. Execute fsck/remontagem antes do próximo backup."
    exit 1
fi
rm -f /home/umbrel/umbrel/external/disk3/.rw_check

mkdir -p "$DISK3_BACKUPS"

# Identificar bases para deduplicação (--link-dest) antes de criar o staging atual
# 1) Snapshot completo mais recente (preferindo marcador .backup_complete)
PREV_COMPLETE=""
while IFS= read -r cand; do
    if [[ -f "${DISK3_BACKUPS}/${cand}/.backup_complete" ]]; then
        PREV_COMPLETE="${DISK3_BACKUPS}/${cand}"
        break
    fi
done < <(find "$DISK3_BACKUPS" -maxdepth 1 -mindepth 1 -type d -name 'backup_*' -printf '%f\n' | sort -r)

# Fallback legado: se nenhum snapshot tiver .backup_complete ainda, usa o mais recente com immich_photos populado
if [[ -z "$PREV_COMPLETE" ]]; then
    while IFS= read -r cand; do
        if [[ -d "${DISK3_BACKUPS}/${cand}/databases" && -d "${DISK3_BACKUPS}/${cand}/immich_photos/library" ]]; then
            PREV_COMPLETE="${DISK3_BACKUPS}/${cand}"
            break
        fi
    done < <(find "$DISK3_BACKUPS" -maxdepth 1 -mindepth 1 -type d -name 'backup_*' -printf '%f\n' | sort -r)
fi

# 2) Se houver .inprogress_* anterior de execução interrompida, aproveita o mais recente para resumir e apaga os demais
PREV_INPROGRESS=""
mapfile -t INPROG_LIST < <(find "$DISK3_BACKUPS" -maxdepth 1 -mindepth 1 -type d -name '.inprogress_backup_*' -printf '%f\n' | sort -r)
if [[ "${#INPROG_LIST[@]}" -gt 0 ]]; then
    PREV_INPROGRESS="${DISK3_BACKUPS}/${INPROG_LIST[0]}"
    for (( i=1; i<${#INPROG_LIST[@]}; i++ )); do
        echo "    -> Removendo staging órfão antigo: ${INPROG_LIST[i]}"
        nice -n 19 ionice -c3 rm -rf "${DISK3_BACKUPS}/${INPROG_LIST[i]}" || true
    done
fi

LINK_LOCAL_OPTS=()
if [[ -n "$PREV_COMPLETE" && -d "$PREV_COMPLETE" ]]; then
    LINK_LOCAL_OPTS+=("--link-dest=${PREV_COMPLETE}")
    echo "    -> Base primária de deduplicação (--link-dest): $(basename "$PREV_COMPLETE")"
fi
if [[ -n "$PREV_INPROGRESS" && -d "$PREV_INPROGRESS" && "$PREV_INPROGRESS" != "$PREV_COMPLETE" ]]; then
    LINK_LOCAL_OPTS+=("--link-dest=${PREV_INPROGRESS}")
    echo "    -> Base secundária de retomada (--link-dest): $(basename "$PREV_INPROGRESS")"
fi

mkdir -p "${STAGE_DEST}/databases"
mkdir -p "${STAGE_DEST}/configs"
mkdir -p "${STAGE_DEST}/custom_stacks"
chmod 750 "${STAGE_DEST}" "${STAGE_DEST}/databases" "${STAGE_DEST}/configs" 2>/dev/null || true

# ------------------------------------------------------------------------------
# 1. DUMPS DOS BANCOS DE DADOS
# ------------------------------------------------------------------------------
echo "[+] 1/4 Gerando dumps dos bancos de dados..."

# Immich PostgreSQL
if docker ps --format '{{.Names}}' | grep -q "immich_postgres_1"; then
    echo "    -> Dump do Immich PostgreSQL..."
    docker exec immich_postgres_1 pg_dumpall -U immich | gzip > "${STAGE_DEST}/databases/immich_db.sql.gz" || echo "    [!] Falha no dump do Immich"
fi

# Nextcloud MariaDB
if docker ps --format '{{.Names}}' | grep -q "nextcloud_db_1"; then
    echo "    -> Dump do Nextcloud MariaDB..."
    docker exec nextcloud_db_1 sh -c 'mariadb-dump -u root -p"${MYSQL_ROOT_PASSWORD:-}" --all-databases 2>/dev/null || mariadb-dump -u root --all-databases 2>/dev/null' | gzip > "${STAGE_DEST}/databases/nextcloud_db.sql.gz" || echo "    [!] Falha no dump do Nextcloud"
fi

# Karteman PostgreSQL & SQLite
if docker ps --format '{{.Names}}' | grep -q "karteman-postgres"; then
    echo "    -> Dump do Karteman PostgreSQL..."
    docker exec karteman-postgres pg_dumpall -U postgres 2>/dev/null | gzip > "${STAGE_DEST}/databases/karteman_db.sql.gz" || true
fi
if [ -f "/home/umbrel/umbrelos-scripts/compose/karteman/data/karteman.db" ]; then
    echo "    -> Backup do Karteman SQLite (karteman.db)..."
    gzip -c "/home/umbrel/umbrelos-scripts/compose/karteman/data/karteman.db" > "${STAGE_DEST}/databases/karteman_sqlite.db.gz" 2>/dev/null || true
fi

# Paulo Investimentos Pessoais (SQLite investimentos.db)
if [ -f "/home/umbrel/umbrelos-scripts/compose/paulo-investimentos-pessoais/data/investimentos.db" ]; then
    echo "    -> Backup do Paulo Investimentos (investimentos.db)..."
    gzip -c "/home/umbrel/umbrelos-scripts/compose/paulo-investimentos-pessoais/data/investimentos.db" > "${STAGE_DEST}/databases/investimentos_pessoais.db.gz" 2>/dev/null || true
fi

# Verifica Nomes Diários Oficiais (SQLite results.db)
if [ -f "/home/umbrel/umbrelos-scripts/compose/verifica-nomes-diarios-oficiais/data/results.db" ]; then
    echo "    -> Backup do Verifica Diários Oficiais (results.db)..."
    gzip -c "/home/umbrel/umbrelos-scripts/compose/verifica-nomes-diarios-oficiais/data/results.db" > "${STAGE_DEST}/databases/verifica_diarios.db.gz" 2>/dev/null || true
fi

# Jellyfin Database
if [[ -f "/home/umbrel/umbrel/app-data/jellyfin/data/data/jellyfin.db" ]]; then
    echo "    -> Cópia segura do sqlite do Jellyfin..."
    cp "/home/umbrel/umbrel/app-data/jellyfin/data/data/jellyfin.db" "${STAGE_DEST}/databases/jellyfin.db" 2>/dev/null || true
fi

# Home Assistant (Banco SQLite + Configs completas / automations / custom_components / HACS)
if [[ -d "/home/umbrel/umbrel/app-data/home-assistant/data" ]]; then
    echo "    -> Backup completo do Home Assistant (Configs + HACS + SQLite)..."
    mkdir -p "${STAGE_DEST}/configs/homeassistant"
    if [[ -f "/home/umbrel/umbrel/app-data/home-assistant/data/home-assistant_v2.db" ]]; then
        gzip -c "/home/umbrel/umbrel/app-data/home-assistant/data/home-assistant_v2.db" > "${STAGE_DEST}/databases/homeassistant_v2.db.gz" 2>/dev/null || true
    fi
    run_rsync -a --exclude="*.log*" --exclude="*.db-wal*" --exclude="*.db-shm*" --exclude="home-assistant_v2.db" \
        /home/umbrel/umbrel/app-data/home-assistant/data/ "${STAGE_DEST}/configs/homeassistant/" || true
fi

# ------------------------------------------------------------------------------
# 2. CONFIGURAÇÕES E DADOS ESSENCIAIS (disk2: users, shared e immich)
# ------------------------------------------------------------------------------
echo "[+] 2/4 Sincronizando dados essenciais de usuários, fotos e configurações (bwlimit=${DISK3_BWLIMIT} KB/s)..."

LOCAL_SYNC_OK=true

# Samba & Configs do Homelab
rsync -a /data/samba/smb.conf "${STAGE_DEST}/configs/" 2>/dev/null || true
rsync -a /data/config.env "${STAGE_DEST}/configs/" 2>/dev/null || true
chmod 600 "${STAGE_DEST}/configs/config.env" 2>/dev/null || true

# Compose das stacks customizadas (com exclusão inteligente de dados voláteis/pesados dispensáveis)
if [[ -d "/home/umbrel/umbrelos-scripts/compose" ]]; then
    echo "    -> Sincronizando custom_stacks (excluindo node_modules, caches, WAL/SHM e temporários)..."
    if ! run_rsync -a --delete --bwlimit="${DISK3_BWLIMIT}" \
        --exclude="node_modules" \
        --exclude=".venv" \
        --exclude="__pycache__" \
        --exclude="*.pyc" \
        --exclude=".git" \
        --exclude=".cache" \
        --exclude="*.tmp" \
        --exclude="*.db-wal*" \
        --exclude="*.db-shm*" \
        --exclude="*.log*" \
        /home/umbrel/umbrelos-scripts/compose/ "${STAGE_DEST}/custom_stacks/"; then
        LOCAL_SYNC_OK=false
    fi
fi

# Usuários e Arquivos Compartilhados do disk2 (Nextcloud / Samba)
if [[ "$LOCAL_SYNC_OK" == "true" && -d "/home/umbrel/umbrel/external/disk2/users" ]]; then
    echo "    -> Sincronizando pastas de usuários do disk2..."
    if ! run_rsync -a --delete --bwlimit="${DISK3_BWLIMIT}" "${LINK_LOCAL_OPTS[@]}" \
        /home/umbrel/umbrel/external/disk2/users/ "${STAGE_DEST}/nextcloud_users/"; then
        LOCAL_SYNC_OK=false
    fi
fi

if [[ "$LOCAL_SYNC_OK" == "true" && -d "/home/umbrel/umbrel/external/disk2/shared" ]]; then
    echo "    -> Sincronizando pasta compartilhada do disk2..."
    if ! run_rsync -a --delete --bwlimit="${DISK3_BWLIMIT}" "${LINK_LOCAL_OPTS[@]}" \
        /home/umbrel/umbrel/external/disk2/shared/ "${STAGE_DEST}/shared/"; then
        LOCAL_SYNC_OK=false
    fi
fi

# Fotos e Uploads do Immich no disk2
if [[ "$LOCAL_SYNC_OK" == "true" && -d "/home/umbrel/umbrel/external/disk2/immich/upload" ]]; then
    echo "    -> Sincronizando fotos e vídeos do Immich (disk2)..."
    if ! run_rsync -a --delete --bwlimit="${DISK3_BWLIMIT}" "${LINK_LOCAL_OPTS[@]}" \
        /home/umbrel/umbrel/external/disk2/immich/upload/ "${STAGE_DEST}/immich_photos/"; then
        LOCAL_SYNC_OK=false
    fi
fi

if [[ "$LOCAL_SYNC_OK" == "true" ]]; then
    touch "${STAGE_DEST}/.backup_complete"
    sync
    mv "${STAGE_DEST}" "${FINAL_DEST}"
    echo "[+] Snapshot local íntegro gravado no disk3: ${FINAL_DEST}"

    # Limpar staging anterior já aproveitado pelo --link-dest
    if [[ -n "$PREV_INPROGRESS" && -d "$PREV_INPROGRESS" ]]; then
        echo "    -> Limpando staging anterior já incorporado: $(basename "$PREV_INPROGRESS")"
        nice -n 19 ionice -c3 rm -rf "$PREV_INPROGRESS" || true
    fi
else
    echo "[!] ATENÇÃO: Snapshot local falhou durante o rsync e permanece em staging (${STAGE_DEST}) para não corromper a cadeia de hardlinks."
fi

# ------------------------------------------------------------------------------
# 3. POLÍTICA DE RETENÇÃO LOCAL NO DISK3 (Executa SEMPRE, mesmo se rsync falhar)
# ------------------------------------------------------------------------------
echo "[+] Aplicando política de retenção no disk3 (máximo ${RETENTION} snapshots válidos)..."
apply_local_retention "${DISK3_BACKUPS}" "${RETENTION}"

if [[ "$LOCAL_SYNC_OK" != "true" ]]; then
    echo "[!] Abortando sincronização remota porque o snapshot local não foi concluído."
    exit 1
fi

# ------------------------------------------------------------------------------
# 4. SINCRONIZAÇÃO REMOTA COM O POP!_OS (Se estiver online)
# ------------------------------------------------------------------------------
echo "[+] 3/4 Verificando conectividade com o Desktop Pop!_OS (${POPOS_HOST})..."

if ping -c 2 -W 2 "${POPOS_HOST}" >/dev/null 2>&1 && \
   ssh -i "${SSH_KEY}" -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new "${POPOS_USER}@${POPOS_HOST}" "exit 0" >/dev/null 2>&1; then
    echo "    -> Pop!_OS online! Preparando espelhamento remoto via rsync (bwlimit=${POPOS_BWLIMIT} KB/s)..."

    LATEST_REMOTE=$(ssh -i "${SSH_KEY}" -o BatchMode=yes "${POPOS_USER}@${POPOS_HOST}" \
        "find '${POPOS_DEST}' -maxdepth 1 -mindepth 1 -type d -name 'backup_*' -printf '%f\n' 2>/dev/null | sort -r | head -n 1" || true)

    REMOTE_STAGE="${POPOS_DEST}/.inprogress_${BACKUP_NAME}"
    REMOTE_FINAL="${POPOS_DEST}/${BACKUP_NAME}"
    ssh -i "${SSH_KEY}" -o BatchMode=yes "${POPOS_USER}@${POPOS_HOST}" "mkdir -p '${REMOTE_STAGE}'"

    LINK_DEST_OPT=()
    if [[ -n "$LATEST_REMOTE" ]]; then
        echo "    -> Utilizando backup anterior (${LATEST_REMOTE}) como base para deduplicação (hardlinks)..."
        LINK_DEST_OPT=("--link-dest=${POPOS_DEST}/${LATEST_REMOTE}")
    fi

    if run_rsync -a --delete --bwlimit="${POPOS_BWLIMIT}" "${LINK_DEST_OPT[@]}" \
        -e "ssh -i ${SSH_KEY} -o BatchMode=yes" \
        "${FINAL_DEST}/" "${POPOS_USER}@${POPOS_HOST}:${REMOTE_STAGE}/"; then
        ssh -i "${SSH_KEY}" -o BatchMode=yes "${POPOS_USER}@${POPOS_HOST}" \
            "touch '${REMOTE_STAGE}/.backup_complete' && mv '${REMOTE_STAGE}' '${REMOTE_FINAL}'"
        echo "    -> Espelhamento remoto concluído com sucesso!"
    else
        echo "    [!] Falha durante o espelhamento remoto para o Pop!_OS (staging preservado em ${REMOTE_STAGE})."
    fi

    # Retenção remota no Pop!_OS (Mantém os N mais recentes)
    echo "[+] Aplicando política de retenção remota no Pop!_OS..."
    ssh -i "${SSH_KEY}" -o BatchMode=yes "${POPOS_USER}@${POPOS_HOST}" "
        find '${POPOS_DEST}' -maxdepth 1 -mindepth 1 -type d -name 'backup_*' -printf '%f\n' 2>/dev/null | sort -r | tail -n +$((RETENTION + 1)) | while read -r old_remote; do
            if [ -n \"\$old_remote\" ] && [ -d \"${POPOS_DEST}/\${old_remote}\" ]; then
                echo \"       Excluindo remoto: \$old_remote\"
                nice -n 19 ionice -c3 rm -rf \"${POPOS_DEST}/\${old_remote}\"
            fi
        done
    "
else
    echo "    -> Pop!_OS desligado ou inacessível no momento. O backup está seguro no disk3 e será sincronizado na próxima janela."
fi

echo "========================================================================"
echo "=== ROTINA DE BACKUP CONCLUÍDA COM SUCESSO: $(date) ==="
echo "========================================================================"

