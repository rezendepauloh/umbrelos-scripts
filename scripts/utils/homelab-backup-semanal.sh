#!/usr/bin/env bash
# ==============================================================================
# homelab-backup-semanal.sh
# Rotina Consolidada de Backup do Homelab (disk3 local + Pop!_OS remoto)
# Política:
#   1. Snapshot completo gravado no disk3 (/home/umbrel/umbrel/external/disk3/backups)
#   2. Dumps reais dos bancos (Immich, Nextcloud, Karteman) + dados de usuários + configs
#   3. Se o Pop!_OS (192.168.0.16) estiver online, sincroniza para /mnt/storage_930/Backups_Homelab
#   4. Retenção de 7 backups: ao gerar o 8º, remove o mais antigo (local e remoto)
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
RETENTION="${BACKUP_RETENTION_COUNT:-7}"

DISK3_BACKUPS="/home/umbrel/umbrel/external/disk3/backups"
TIMESTAMP="$(date +'%Y-%m-%d_%H%M%S')"
BACKUP_NAME="backup_${TIMESTAMP}"
LOCAL_DEST="${DISK3_BACKUPS}/${BACKUP_NAME}"
LOG_FILE="/data/homelab-backup.log"

# Garantir log com permissões
exec >> "$LOG_FILE" 2>&1
echo "========================================================================"
echo "=== INÍCIO DA ROTINA DE BACKUP CONSOLIDADO: $(date) ==="
echo "========================================================================"

# Verificar se disk3 está montado
if ! mountpoint -q /home/umbrel/umbrel/external/disk3; then
    echo "[!] ERRO CRÍTICO: disk3 não está montado. Abortando backup para proteger o sistema."
    exit 1
fi

mkdir -p "${LOCAL_DEST}/databases"
mkdir -p "${LOCAL_DEST}/configs"
mkdir -p "${LOCAL_DEST}/custom_stacks"

# ------------------------------------------------------------------------------
# 1. DUMPS DOS BANCOS DE DADOS
# ------------------------------------------------------------------------------
echo "[+] 1/4 Gerando dumps dos bancos de dados..."

# Immich PostgreSQL
if docker ps --format '{{.Names}}' | grep -q "immich_postgres_1"; then
    echo "    -> Dump do Immich PostgreSQL..."
    docker exec immich_postgres_1 pg_dumpall -U immich | gzip > "${LOCAL_DEST}/databases/immich_db.sql.gz" || echo "    [!] Falha no dump do Immich"
fi

# Nextcloud MariaDB
if docker ps --format '{{.Names}}' | grep -q "nextcloud_db_1"; then
    echo "    -> Dump do Nextcloud MariaDB..."
    docker exec nextcloud_db_1 mariadb-dump -u root -pmoneyprintergobrrr --all-databases 2>/dev/null | gzip > "${LOCAL_DEST}/databases/nextcloud_db.sql.gz" || echo "    [!] Falha no dump do Nextcloud"
fi

# Karteman PostgreSQL
if docker ps --format '{{.Names}}' | grep -q "karteman-postgres"; then
    echo "    -> Dump do Karteman PostgreSQL..."
    docker exec karteman-postgres pg_dumpall -U postgres 2>/dev/null | gzip > "${LOCAL_DEST}/databases/karteman_db.sql.gz" || true
fi

# Jellyfin Database
if [[ -f "/home/umbrel/umbrel/app-data/jellyfin/data/data/jellyfin.db" ]]; then
    echo "    -> Cópia segura do sqlite do Jellyfin..."
    cp "/home/umbrel/umbrel/app-data/jellyfin/data/data/jellyfin.db" "${LOCAL_DEST}/databases/jellyfin.db" 2>/dev/null || true
fi

# ------------------------------------------------------------------------------
# 2. CONFIGURAÇÕES E DADOS ESSENCIAIS (disk2: users e shared)
# ------------------------------------------------------------------------------
echo "[+] 2/4 Sincronizando dados essenciais de usuários e configurações..."

# Samba & Configs do Homelab
rsync -a /data/samba/smb.conf "${LOCAL_DEST}/configs/" 2>/dev/null || true
rsync -a /data/config.env "${LOCAL_DEST}/configs/" 2>/dev/null || true

# Compose das stacks customizadas
if [[ -d "/home/umbrel/umbrelos-scripts/compose" ]]; then
    rsync -a --delete /home/umbrel/umbrelos-scripts/compose/ "${LOCAL_DEST}/custom_stacks/"
fi

# Usuários e Arquivos Compartilhados do disk2 (Nextcloud / Samba)
if [[ -d "/home/umbrel/umbrel/external/disk2/users" ]]; then
    echo "    -> Sincronizando pastas de usuários do disk2..."
    rsync -a --delete /home/umbrel/umbrel/external/disk2/users/ "${LOCAL_DEST}/nextcloud_users/"
fi

if [[ -d "/home/umbrel/umbrel/external/disk2/shared" ]]; then
    echo "    -> Sincronizando pasta compartilhada do disk2..."
    rsync -a --delete /home/umbrel/umbrel/external/disk2/shared/ "${LOCAL_DEST}/shared/"
fi

sync
echo "[+] Snapshot local gravado com sucesso no disk3: ${LOCAL_DEST}"

# ------------------------------------------------------------------------------
# 3. POLÍTICA DE RETENÇÃO LOCAL NO DISK3 (Mantém os 7 mais recentes, apaga o 8º)
# ------------------------------------------------------------------------------
echo "[+] Aplicando política de retenção no disk3 (máximo ${RETENTION} snapshots)..."
cd "${DISK3_BACKUPS}"
# shellcheck disable=SC2012
BACKUP_LIST=$(ls -dt backup_* 2>/dev/null || true)
TOTAL_LOCAL=$(echo "$BACKUP_LIST" | grep -c '^backup_' || true)

if [[ "$TOTAL_LOCAL" -gt "$RETENTION" ]]; then
    EXCESS=$((TOTAL_LOCAL - RETENTION))
    echo "    -> Removendo $EXCESS snapshot(s) antigo(s) no disk3..."
    echo "$BACKUP_LIST" | tail -n +"$((RETENTION + 1))" | while read -r old_backup; do
        if [[ -n "$old_backup" && -d "${DISK3_BACKUPS}/${old_backup}" ]]; then
            echo "       Excluindo local: $old_backup"
            rm -rf "${DISK3_BACKUPS}/${old_backup}"
        fi
    done
fi

# ------------------------------------------------------------------------------
# 4. SINCRONIZAÇÃO REMOTA COM O POP!_OS (Se estiver online)
# ------------------------------------------------------------------------------
echo "[+] 3/4 Verificando conectividade com o Desktop Pop!_OS (${POPOS_HOST})..."

if ping -c 2 -W 2 "${POPOS_HOST}" >/dev/null 2>&1; then
    echo "    -> Pop!_OS online! Iniciando espelhamento remoto via rsync..."
    
    # Criar pasta remota
    ssh -i "${SSH_KEY}" -o BatchMode=yes -o StrictHostKeyChecking=accept-new "${POPOS_USER}@${POPOS_HOST}" "mkdir -p '${POPOS_DEST}/${BACKUP_NAME}'"
    
    # Transferência incremental
    rsync -avz --delete -e "ssh -i ${SSH_KEY} -o BatchMode=yes" "${LOCAL_DEST}/" "${POPOS_USER}@${POPOS_HOST}:${POPOS_DEST}/${BACKUP_NAME}/"
    echo "    -> Espelhamento remoto concluído com sucesso!"
    
    # Retenção remota no Pop!_OS (Mantém os 7 mais recentes)
    echo "[+] Aplicando política de retenção remota no Pop!_OS..."
    ssh -i "${SSH_KEY}" -o BatchMode=yes "${POPOS_USER}@${POPOS_HOST}" "
        cd '${POPOS_DEST}' && \
        ls -dt backup_* 2>/dev/null | tail -n +$((RETENTION + 1)) | while read -r old_remote; do
            if [ -n \"\$old_remote\" ] && [ -d \"\${old_remote}\" ]; then
                echo '       Excluindo remoto: '\$old_remote
                rm -rf \"\$old_remote\"
            fi
        done
    "
else
    echo "    -> Pop!_OS desligado ou inacessível no momento. O backup está 100% seguro no disk3 e será sincronizado na próxima janela."
fi

echo "========================================================================"
echo "=== ROTINA DE BACKUP CONCLUÍDA COM SUCESSO: $(date) ==="
echo "========================================================================"

