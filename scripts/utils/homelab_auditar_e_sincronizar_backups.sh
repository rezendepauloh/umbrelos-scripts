#!/usr/bin/env bash
# ==============================================================================
# scripts/utils/homelab_auditar_e_sincronizar_backups.sh
# ------------------------------------------------------------------------------
# Auditor e Sincronizador Ativo de Backups:
#   1. Compara os backups existentes no disk3 (Mini PC) e no Pop!_OS local.
#   2. Exibe o status e integridade detalhada de:
#      - Bancos de dados: Immich (PostgreSQL), Nextcloud (PostgreSQL), Karteman.
#      - Dados brutos incrementais: Fotos/Vídeos Immich (immich_photos),
#        Documentos de Usuários Nextcloud (nextcloud_users) e Compartilhados (shared).
#   3. Identifica snapshots e dados faltantes no Pop!_OS.
#   4. Executa a sincronização segura via rsync com deduplicação (--link-dest)
#      e privilégios elevados (--rsync-path="sudo rsync").
#   5. Aplica estritamente a política de 7 backups: ao atingir o 8º, remove o mais antigo.
#
# Uso:
#   ./scripts/utils/homelab_auditar_e_sincronizar_backups.sh         # Auditoria + Sincronização automática
#   ./scripts/utils/homelab_auditar_e_sincronizar_backups.sh --check # Apenas audita bancos e dados sem sincronizar
#   ./scripts/utils/homelab_auditar_e_sincronizar_backups.sh --sync  # Força sincronização imediata
# ==============================================================================

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.env"
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

SERVER_HOST="${SERVER_HOST:-192.168.0.8}"
SERVER_USER="${SERVER_USER:-umbrel}"
SSH_KEY="${HOME}/.ssh/id_ed25519"
RETENTION="${BACKUP_RETENTION_COUNT:-7}"

REMOTE_DISK3_DIR="/home/umbrel/umbrel/external/disk3/backups"
LOCAL_BACKUP_DIR="${POPOS_DEST_DIR:-/mnt/storage_930/Backups_Homelab}"

ACTION_MODE="all"
if [[ "${1:-}" == "--check" ]]; then
    ACTION_MODE="check"
elif [[ "${1:-}" == "--sync" ]]; then
    ACTION_MODE="sync"
fi

echo -e "${BLUE}${BOLD}==============================================================================${NC}"
echo -e "${BLUE}${BOLD}   AUDITORIA E SINCRONIZAÇÃO DE BACKUPS (Mini PC disk3 <-> Pop!_OS)           ${NC}"
echo -e "${BLUE}${BOLD}==============================================================================${NC}"

# 1. Testar conectividade com o Mini PC
echo -e "${CYAN}ℹ Testando conexão SSH com ${SERVER_USER}@${SERVER_HOST}...${NC}"
if ! ssh -i "${SSH_KEY}" -o ConnectTimeout=4 -o BatchMode=yes "${SERVER_USER}@${SERVER_HOST}" "exit 0" 2>/dev/null; then
    echo -e "${RED}[!] ERRO: Mini PC ${SERVER_HOST} inacessível via SSH.${NC}"
    exit 1
fi
echo -e "${GREEN}[✔] Conectado ao Mini PC com sucesso!${NC}\n"

# 2. Obter lista de backups no disk3
echo -e "${BLUE}${BOLD}[1/4] Levantando snapshots disponíveis no disk3 (Mini PC):${NC}"
DISK3_BACKUPS_RAW=$(ssh -i "${SSH_KEY}" "${SERVER_USER}@${SERVER_HOST}" "
    if [ -d '${REMOTE_DISK3_DIR}' ]; then
        cd '${REMOTE_DISK3_DIR}' && ls -dt backup_* 2>/dev/null || true
    fi
")

mapfile -t REMOTE_LIST < <(echo "$DISK3_BACKUPS_RAW" | grep '^backup_' || true)
TOTAL_REMOTE=${#REMOTE_LIST[@]}

if [ "$TOTAL_REMOTE" -eq 0 ]; then
    echo -e "  ${YELLOW}⚠ Nenhum diretório 'backup_*' localizado no disk3!${NC}"
else
    echo -e "  Encontrados ${BOLD}${TOTAL_REMOTE}${NC} snapshot(s) no disk3:"
    for b in "${REMOTE_LIST[@]}"; do
        echo -e "    📁 ${CYAN}${b}${NC}"
    done
fi

# 3. Obter lista de backups no Pop!_OS
echo -e "\n${BLUE}${BOLD}[2/4] Levantando snapshots armazenados localmente no Pop!_OS:${NC}"
mkdir -p "${LOCAL_BACKUP_DIR}"

mapfile -t LOCAL_LIST < <(cd "${LOCAL_BACKUP_DIR}" && ls -dt backup_* 2>/dev/null | grep '^backup_' || true)
TOTAL_LOCAL=${#LOCAL_LIST[@]}

if [ "$TOTAL_LOCAL" -eq 0 ]; then
    echo -e "  ${YELLOW}⚠ Nenhum snapshot local localizado em ${LOCAL_BACKUP_DIR}!${NC}"
else
    echo -e "  Encontrados ${BOLD}${TOTAL_LOCAL}${NC} snapshot(s) no Pop!_OS:"
    for b in "${LOCAL_LIST[@]}"; do
        echo -e "    💾 ${GREEN}${b}${NC}"
    done
fi

# 4. Auditoria de Integridade: Bancos de Dados E Dados Brutos (Immich & Nextcloud)
LATEST_DISK3="${REMOTE_LIST[0]:-}"
if [ -n "$LATEST_DISK3" ]; then
    echo -e "\n${BLUE}${BOLD}[3/4] Auditoria Detalhada do Snapshot Mais Recente (${LATEST_DISK3}):${NC}"
    
    AUDIT_OUTPUT=$(ssh -i "${SSH_KEY}" "${SERVER_USER}@${SERVER_HOST}" "
        source /data/config.env 2>/dev/null || true
        echo \"\$SYSTEM_PASSWORD\" | sudo -S bash -c '
            SNAP_DIR=\"${REMOTE_DISK3_DIR}/${LATEST_DISK3}\"
            echo \"---BANCOS---\"
            if [ -d \"\$SNAP_DIR/databases\" ]; then
                for f in \"\$SNAP_DIR/databases\"/*; do
                    if [ -f \"\$f\" ]; then
                        echo \"\$(basename \"\$f\")|\$(du -h \"\$f\" | cut -f1)\"
                    fi
                done
            fi
            echo \"---DADOS---\"
            for item in immich_photos nextcloud_users shared custom_stacks configs; do
                if [ -d \"\$SNAP_DIR/\$item\" ]; then
                    sz=\$(du -sh \"\$SNAP_DIR/\$item\" 2>/dev/null | cut -f1)
                    echo \"\$item|\$sz|PRESENTE\"
                else
                    echo \"\$item|0|AUSENTE\"
                fi
            done
            echo \"---ORIGEM_DISK2---\"
            echo \"disk2_immich|\$(du -sh /home/umbrel/umbrel/external/disk2/immich/upload 2>/dev/null | cut -f1)\"
            echo \"disk2_nextcloud|\$(du -sh /home/umbrel/umbrel/external/disk2/users 2>/dev/null | cut -f1)\"
            echo \"disk2_shared|\$(du -sh /home/umbrel/umbrel/external/disk2/shared 2>/dev/null | cut -f1)\"
        ' 2>/dev/null
    ")

    CURRENT_SECTION=""
    echo -e "  ${BOLD}A. Dumps SQL de Bancos de Dados:${NC}"
    while IFS='|' read -r col1 col2 col3; do
        if [[ "$col1" == "---BANCOS---" ]]; then
            CURRENT_SECTION="bancos"
            continue
        elif [[ "$col1" == "---DADOS---" ]]; then
            CURRENT_SECTION="dados"
            echo -e "\n  ${BOLD}B. Dados de Usuário e Mídia (Backups Incrementais):${NC}"
            continue
        elif [[ "$col1" == "---ORIGEM_DISK2---" ]]; then
            CURRENT_SECTION="origem"
            echo -e "\n  ${BOLD}C. Comparativo com Dados Ativos no disk2 (Produção):${NC}"
            continue
        fi

        if [[ "$CURRENT_SECTION" == "bancos" && -n "$col1" ]]; then
            if [[ "$col1" == *"immich"* ]]; then
                echo -e "    ✔ Immich DB (${BOLD}${col1}${NC}): ${GREEN}${col2}${NC}"
            elif [[ "$col1" == *"nextcloud"* ]]; then
                echo -e "    ✔ Nextcloud DB (${BOLD}${col1}${NC}): ${GREEN}${col2}${NC}"
            elif [[ "$col1" == *"homeassistant"* ]]; then
                echo -e "    ✔ Home Assistant DB (${BOLD}${col1}${NC}): ${GREEN}${col2}${NC}"
            elif [[ "$col1" == *"karteman"* ]]; then
                echo -e "    ✔ Karteman DB (${BOLD}${col1}${NC}): ${GREEN}${col2}${NC}"
            elif [[ "$col1" == *"investimentos"* ]]; then
                echo -e "    ✔ Paulo Investimentos DB (${BOLD}${col1}${NC}): ${GREEN}${col2}${NC}"
            elif [[ "$col1" == *"diarios"* ]]; then
                echo -e "    ✔ Verifica Diários DB (${BOLD}${col1}${NC}): ${GREEN}${col2}${NC}"
            else
                echo -e "    ✔ Banco (${BOLD}${col1}${NC}): ${GREEN}${col2}${NC}"
            fi
        elif [[ "$CURRENT_SECTION" == "dados" && -n "$col1" ]]; then
            item_name="$col1"
            item_size="$col2"
            item_status="${col3:-}"
            if [[ "$item_status" == "PRESENTE" ]]; then
                case "$item_name" in
                    immich_photos)
                        echo -e "    ✔ [OK] Fotos & Vídeos Immich (${BOLD}immich_photos/${NC}): ${GREEN}${item_size}${NC}"
                        ;;
                    nextcloud_users)
                        echo -e "    ✔ [OK] Arquivos Nextcloud (${BOLD}nextcloud_users/${NC}): ${GREEN}${item_size}${NC}"
                        ;;
                    shared)
                        echo -e "    ✔ [OK] Compartilhamentos Samba (${BOLD}shared/${NC}): ${GREEN}${item_size}${NC}"
                        ;;
                    custom_stacks)
                        echo -e "    ✔ [OK] Stacks Docker Customizadas (${BOLD}custom_stacks/${NC}): ${GREEN}${item_size}${NC}"
                        ;;
                    configs)
                        echo -e "    ✔ [OK] Configurações de Apps (${BOLD}configs/${NC}): ${GREEN}${item_size}${NC}"
                        ;;
                esac
            else
                echo -e "    ${RED}✖ [FALTA] ${item_name} NÃO encontrado no snapshot!${NC}"
            fi
        elif [[ "$CURRENT_SECTION" == "origem" && -n "$col1" ]]; then
            case "$col1" in
                disk2_immich)
                    echo -e "    • Tamanho ativo Immich no disk2: ${CYAN}${col2}${NC}"
                    ;;
                disk2_nextcloud)
                    echo -e "    • Tamanho ativo Nextcloud no disk2: ${CYAN}${col2}${NC}"
                    ;;
                disk2_shared)
                    echo -e "    • Tamanho ativo Shared no disk2: ${CYAN}${col2}${NC}"
                    ;;
            esac
        fi
    done <<< "$AUDIT_OUTPUT"
fi

# 5. Identificar Snapshots Faltantes no Pop!_OS
declare -a MISSING_LOCAL=()
for rb in "${REMOTE_LIST[@]}"; do
    found=false
    for lb in "${LOCAL_LIST[@]}"; do
        if [[ "$rb" == "$lb" ]]; then
            found=true
            break
        fi
    done
    if [ "$found" = false ]; then
        MISSING_LOCAL+=("$rb")
    fi
done

TOTAL_MISSING=${#MISSING_LOCAL[@]}

echo -e "\n${BLUE}${BOLD}[4/4] Diagnóstico de Sincronização:${NC}"
if [ "$TOTAL_MISSING" -eq 0 ]; then
    echo -e "  ${GREEN}✔ Todos os snapshots do disk3 já estão sincronizados no seu Pop!_OS!${NC}"
else
    echo -e "  ${YELLOW}⚠ Existem ${BOLD}${TOTAL_MISSING}${NC} snapshot(s) no disk3 que AINDA NÃO estão no Pop!_OS:${NC}"
    for mb in "${MISSING_LOCAL[@]}"; do
        echo -e "    ➡ ${BOLD}${mb}${NC}"
    done
fi

if [[ "$ACTION_MODE" == "check" ]]; then
    echo -e "\n${CYAN}Modo verificação concluído. Nenhuma transferência foi executada.${NC}"
    exit 0
fi

# 6. Sincronização Puxando do Mini PC para o Pop!_OS
if [ "$TOTAL_MISSING" -gt 0 ]; then
    echo -e "\n${BOLD}${YELLOW}Iniciando sincronização completa (Bancos + Dados brutos) para o Pop!_OS via rsync...${NC}"
    
    # Processar do mais antigo para o mais recente para preservar cadeias de hardlink
    for (( idx=${#MISSING_LOCAL[@]}-1 ; idx>=0 ; idx-- )) ; do
        target_snap="${MISSING_LOCAL[idx]}"
        echo -e "\n${CYAN}==> Sincronizando: ${BOLD}${target_snap}${NC}..."
        
        # Encontrar o snapshot local mais recente já existente para servir de --link-dest (deduplicação)
        PREV_LOCAL=$(cd "${LOCAL_BACKUP_DIR}" && ls -dt backup_* 2>/dev/null | grep -v "${target_snap}" | head -n 1 || true)
        LINK_DEST_FLAG=""
        if [ -n "$PREV_LOCAL" ] && [ -d "${LOCAL_BACKUP_DIR}/${PREV_LOCAL}" ]; then
            echo -e "    Deduplicação ativada via hardlinks com: ${BOLD}${PREV_LOCAL}${NC}"
            LINK_DEST_FLAG="--link-dest=${LOCAL_BACKUP_DIR}/${PREV_LOCAL}"
        fi

        mkdir -p "${LOCAL_BACKUP_DIR}/${target_snap}"

        if ! rsync -avz --progress --exclude="*.mongodb*" --exclude="diagnostic.data*" --exclude="journal*" $LINK_DEST_FLAG \
            --rsync-path="sudo /usr/bin/rsync" \
            -e "ssh -i ${SSH_KEY}" \
            "${SERVER_USER}@${SERVER_HOST}:${REMOTE_DISK3_DIR}/${target_snap}/" \
            "${LOCAL_BACKUP_DIR}/${target_snap}/"; then
            echo -e "    ${RED}✖ Falha na sincronização do snapshot ${target_snap}!${NC}"
            exit 1
        fi

        echo -e "    ${GREEN}✔ Snapshot ${target_snap} sincronizado com sucesso no Pop!_OS!${NC}"
    done
fi

# 7. Política Estrita de Retenção (Mantém os 7 mais recentes; o 8º é eliminado)
echo -e "\n${BLUE}${BOLD}Aplicando política de retenção estrita (${RETENTION} backups mantidos):${NC}"

# No Pop!_OS:
cd "${LOCAL_BACKUP_DIR}"
mapfile -t UPDATED_LOCAL < <(ls -dt backup_* 2>/dev/null | grep '^backup_' || true)
LOCAL_COUNT=${#UPDATED_LOCAL[@]}

if [ "$LOCAL_COUNT" -gt "$RETENTION" ]; then
    EXCESS=$((LOCAL_COUNT - RETENTION))
    echo -e "  ${YELLOW}➡ Pop!_OS possui ${LOCAL_COUNT} backups (limite: ${RETENTION}). Excluindo ${EXCESS} mais antigo(s)...${NC}"
    for (( i=RETENTION; i<LOCAL_COUNT; i++ )); do
        old_dir="${UPDATED_LOCAL[i]}"
        if [ -n "$old_dir" ] && [ -d "$old_dir" ]; then
            echo -e "     🗑 Removendo localmente: ${BOLD}${old_dir}${NC}"
            rm -rf "$old_dir"
        fi
    done
else
    echo -e "  ✔ Pop!_OS dentro da cota de retenção (${LOCAL_COUNT}/${RETENTION})."
fi

# No Mini PC (disk3):
ssh -i "${SSH_KEY}" "${SERVER_USER}@${SERVER_HOST}" "
    source /data/config.env 2>/dev/null || true
    echo \"\$SYSTEM_PASSWORD\" | sudo -S bash -c '
        cd \"${REMOTE_DISK3_DIR}\" 2>/dev/null || exit 0
        BACKUPS=\$(ls -dt backup_* 2>/dev/null | grep \"^backup_\" || true)
        COUNT=\$(echo \"\$BACKUPS\" | grep -c \"^backup_\" || true)
        RET=\"${RETENTION}\"
        if [ \"\$COUNT\" -gt \"\$RET\" ]; then
            echo \"  ➡ disk3 possui \$COUNT backups. Removendo excedentes antigos...\"
            echo \"\$BACKUPS\" | tail -n +\"\$((RET + 1))\" | while read -r ob; do
                if [ -n \"\$ob\" ] && [ -d \"\$ob\" ]; then
                    echo \"     🗑 Removendo disk3: \$ob\"
                    rm -rf \"\$ob\"
                fi
            done
        else
            echo \"  ✔ disk3 dentro da cota de retenção (\$COUNT/\$RET).\"
        fi
    '
"

echo -e "\n${GREEN}${BOLD}==============================================================================${NC}"
echo -e "${GREEN}${BOLD}✔ PROCESSO DE AUDITORIA E SINCRONIZAÇÃO CONCLUÍDO COM SUCESSO!                 ${NC}"
echo -e "${GREEN}${BOLD}==============================================================================${NC}\n"
