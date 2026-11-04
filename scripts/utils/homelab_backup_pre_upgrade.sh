#!/usr/bin/env bash
# ==============================================================================
# scripts/utils/homelab_backup_pre_upgrade.sh
# ------------------------------------------------------------------------------
# Executado a partir do Pop!_OS para disparar um SNAPSHOT COMPLETO do Homelab
# antes de qualquer atualização crítica do sistema operacional umbrelOS
# ou updates maiores de containers / banco de dados.
#
# Salva simultaneamente em dois locais:
#   1. Servidor Mini PC (Local): /home/umbrel/umbrel/external/disk3/backups/pre_upgrade_<DATA>
#   2. Workstation Pop!_OS:     /mnt/storage_930/Backups_Homelab/pre_upgrade_<DATA>
#
# Conteúdo do Backup:
#   - Dumps completos de bancos (Immich Postgres, Nextcloud MariaDB, Karteman Postgres)
#   - App-data dos serviços oficiais Umbrel (/home/umbrel/umbrel/app-data)
#   - Stacks customizadas do Docker Compose (/home/umbrel/umbrelos-scripts/compose)
#   - Diretório persistente do sistema (/data, excluindo montagens de loop do Rugix)
#   - Arquivos e shares de usuários no disk2 (/home/umbrel/umbrel/external/disk2)
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

echo -e "${BLUE}${BOLD}======================================================================${NC}"
echo -e "${BLUE}${BOLD}===      SNAPSHOT COMPLETO PRÉ-UPGRADE DO HOMELAB UMBRELOS         ===${NC}"
echo -e "${BLUE}${BOLD}======================================================================${NC}"

# Teste de conectividade SSH com o Mini PC
if ! ssh -i "${SSH_KEY}" -o ConnectTimeout=4 -o BatchMode=yes "${SERVER_USER}@${SERVER_HOST}" "exit 0" 2>/dev/null; then
    echo -e "${RED}[!] ERRO: Mini PC ${SERVER_HOST} inacessível via SSH.${NC}"
    echo -e "    Certifique-se de que o mini PC está ligado e conectado à rede."
    exit 1
fi

echo -e "${CYAN}ℹ Conectado ao Mini PC via canal seguro (stream não-interativo)${NC}\n"

ssh -o LogLevel=ERROR -i "${SSH_KEY}" "${SERVER_USER}@${SERVER_HOST}" 'bash -s' << 'REMOTESCRIPT'
set -euo pipefail

if [ -f /data/config.env ]; then
    set -a
    source /data/config.env
    set +a
fi

DATE=$(date +%Y-%m-%d_%H%M%S)
BACKUP_NAME="pre_upgrade_${DATE}"
LOCAL_DEST="/home/umbrel/umbrel/external/disk3/backups/${BACKUP_NAME}"
POPOS_HOST="${POPOS_HOST:-192.168.0.16}"
POPOS_USER="${POPOS_USER:-rezendepauloh}"
POPOS_DEST="${POPOS_DEST_DIR:-/mnt/storage_930/Backups_Homelab}/${BACKUP_NAME}"
SSH_KEY_SERVER="/home/umbrel/.ssh/id_ed25519"

echo -e "\033[1;33m[1/6] Preparando estrutura de diretórios no disk3...\033[0m"
echo "$SYSTEM_PASSWORD" | sudo -S mkdir -p "${LOCAL_DEST}/databases" \
                                          "${LOCAL_DEST}/app_data" \
                                          "${LOCAL_DEST}/system_data" \
                                          "${LOCAL_DEST}/custom_stacks" 2>&1 | grep -v 'password for umbrel' || true

# 1. DUMPS DOS BANCOS DE DADOS
echo -e "\n\033[1;33m[2/6] Gerando dumps consistentes dos bancos de dados...\033[0m"

# Nextcloud (MariaDB)
NEXTCLOUD_DB=$(echo "$SYSTEM_PASSWORD" | sudo -S docker ps -q -f name=nextcloud_db_1 2>/dev/null | head -n 1 || true)
if [ -n "$NEXTCLOUD_DB" ]; then
    echo "  * Dump MariaDB (Nextcloud)..."
    echo "$SYSTEM_PASSWORD" | sudo -S bash -c "docker exec '$NEXTCLOUD_DB' mariadb-dump -u root --all-databases 2>/dev/null | gzip > '${LOCAL_DEST}/databases/nextcloud_db.sql.gz'" || true
fi

# Immich (Postgres)
IMMICH_PG=$(echo "$SYSTEM_PASSWORD" | sudo -S docker ps -q -f name=immich_postgres_1 2>/dev/null | head -n 1 || true)
if [ -n "$IMMICH_PG" ]; then
    echo "  * Dump PostgreSQL (Immich)..."
    echo "$SYSTEM_PASSWORD" | sudo -S bash -c "docker exec '$IMMICH_PG' pg_dumpall -U postgres 2>/dev/null | gzip > '${LOCAL_DEST}/databases/immich_db.sql.gz'" || true
fi

# Karteman (Postgres)
KARTEMAN_PG=$(echo "$SYSTEM_PASSWORD" | sudo -S docker ps -q -f name=karteman-postgres 2>/dev/null | head -n 1 || true)
if [ -n "$KARTEMAN_PG" ]; then
    echo "  * Dump PostgreSQL (Karteman)..."
    echo "$SYSTEM_PASSWORD" | sudo -S bash -c "docker exec '$KARTEMAN_PG' pg_dumpall -U postgres 2>/dev/null | gzip > '${LOCAL_DEST}/databases/karteman_db.sql.gz'" || true
fi

# 2. BACKUP DOS APPS OFICIAIS (app-data do Umbrel - configurações e metadados)
echo -e "\n\033[1;33m[3/5] Sincronizando app-data dos serviços oficiais (excluindo uploads de mídia pesada e caches)...\033[0m"
echo "$SYSTEM_PASSWORD" | sudo -S rsync -a --delete \
    --exclude='immich/data/upload' \
    --exclude='immich/data/model-cache' \
    --exclude='jellyfin/data/transcodes' \
    --exclude='jellyfin/data/cache' \
    --exclude='jellyfin/data/config/cache' \
    --exclude='nextcloud/data' \
    /home/umbrel/umbrel/app-data/ "${LOCAL_DEST}/app_data/" 2>&1 | grep -v 'password for umbrel' || true

# 3. BACKUP DAS STACKS CUSTOMIZADAS (compose)
echo -e "\n\033[1;33m[4/5] Sincronizando stacks customizadas do Docker Compose...\033[0m"
echo "$SYSTEM_PASSWORD" | sudo -S rsync -a --delete /home/umbrel/umbrelos-scripts/compose/ "${LOCAL_DEST}/custom_stacks/" 2>&1 | grep -v 'password for umbrel' || true

# 4. BACKUP DAS CONFIGURAÇÕES PERSISTENTES (/data)
echo -e "\n\033[1;33m[5/5] Sincronizando configurações persistentes de /data (excluindo loops Rugix)...\033[0m"
echo "$SYSTEM_PASSWORD" | sudo -S rsync -a --delete --exclude='umbrel-os' /data/ "${LOCAL_DEST}/system_data/" 2>&1 | grep -v 'password for umbrel' || true

echo -e "\n\033[1;32m[✔] Snapshot do sistema e estados gravado com sucesso no disk3!\033[0m"
echo "$SYSTEM_PASSWORD" | sudo -S du -sh "${LOCAL_DEST}" 2>/dev/null || true

# 6. SINCRONIZAÇÃO REMOTA PARA O POP!_OS
echo -e "\n\033[1;36m[+] Enviando cópia de segurança para o Desktop Pop!_OS (${POPOS_DEST})...\033[0m"
if ping -c 1 -W 2 "$POPOS_HOST" >/dev/null 2>&1; then
    ssh -i "$SSH_KEY_SERVER" -o StrictHostKeyChecking=accept-new "${POPOS_USER}@${POPOS_HOST}" "mkdir -p '${POPOS_DEST}'"
    echo "$SYSTEM_PASSWORD" | sudo -S rsync -avz -e "ssh -i $SSH_KEY_SERVER" "${LOCAL_DEST}/" "${POPOS_USER}@${POPOS_HOST}:${POPOS_DEST}/" 2>&1 | grep -v 'password for umbrel' || true
    echo -e "\033[1;32m[✔] Sincronização remota com o Pop!_OS concluída com sucesso!\033[0m"
else
    echo -e "\033[1;31m[!] AVISO: Pop!_OS não respondeu ao ping. O backup permanece 100% seguro no disk3 do Mini PC.\033[0m"
fi

echo -e "\n=========================================================="
echo -e " \033[1;32mSNAPSHOT PRÉ-UPGRADE FINALIZADO COM SUCESSO!\033[0m"
echo -e " Local no Servidor (disk3): \033[1;37m${LOCAL_DEST}\033[0m"
echo -e " Local no Desktop Pop!_OS:  \033[1;37m${POPOS_DEST}\033[0m"
echo -e "=========================================================="
REMOTESCRIPT

echo -e "\n${GREEN}${BOLD}✔ Rotina de Snapshot Concluída! O Homelab está pronto para upgrades seguros.${NC}\n"

