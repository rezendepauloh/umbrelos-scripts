#!/usr/bin/env bash
# ==============================================================================
# backup_completo_pre_upgrade.sh
# ------------------------------------------------------------------------------
# Realiza um snapshot/backup COMPLETO de todo o estado do Homelab antes de updates
# Destino 1: /home/umbrel/umbrel/external/disk3/backups/pre_upgrade_<DATA> (Local no HD3)
# Destino 2: rezendepauloh@192.168.0.16:/mnt/storage_930/Backups_Homelab/pre_upgrade_<DATA> (Desktop)
# ==============================================================================

set -euo pipefail

DATE=$(date +%Y-%m-%d_%H%M%S)
BACKUP_NAME="pre_upgrade_${DATE}"
LOCAL_DEST="/home/umbrel/umbrel/external/disk3/backups/${BACKUP_NAME}"
POPOS_HOST="192.168.0.16"
POPOS_USER="rezendepauloh"
POPOS_DEST="/mnt/storage_930/Backups_Homelab/${BACKUP_NAME}"
SSH_KEY="/home/umbrel/.ssh/id_ed25519"

echo "=========================================================="
echo " INICIANDO BACKUP COMPLETO PRÉ-UPGRADE: ${BACKUP_NAME}"
echo "=========================================================="

mkdir -p "${LOCAL_DEST}/databases"
mkdir -p "${LOCAL_DEST}/app_data"
mkdir -p "${LOCAL_DEST}/system_data"
mkdir -p "${LOCAL_DEST}/custom_stacks"
mkdir -p "${LOCAL_DEST}/user_files"

# 1. DUMP DOS BANCOS DE DADOS
echo "--> 1/6 Gerando dumps dos bancos de dados..."

# Nextcloud (MariaDB)
if docker ps -q -f name=nextcloud_db_1 | grep -q .; then
    echo "  * Dump MariaDB (Nextcloud)..."
    docker exec nextcloud_db_1 mariadb-dump -u root --all-databases 2>/dev/null | gzip > "${LOCAL_DEST}/databases/nextcloud_db.sql.gz" || true
fi

# Immich (Postgres)
if docker ps -q -f name=immich_postgres_1 | grep -q .; then
    echo "  * Dump PostgreSQL (Immich)..."
    docker exec immich_postgres_1 pg_dumpall -U postgres 2>/dev/null | gzip > "${LOCAL_DEST}/databases/immich_db.sql.gz" || true
fi

# Karteman (Postgres)
if docker ps -q -f name=karteman-postgres | grep -q .; then
    echo "  * Dump PostgreSQL (Karteman)..."
    docker exec karteman-postgres pg_dumpall -U postgres 2>/dev/null | gzip > "${LOCAL_DEST}/databases/karteman_db.sql.gz" || true
fi

# 2. BACKUP DOS APPS OFICIAIS (app-data do Umbrel)
echo "--> 2/6 Sincronizando app-data dos serviços oficiais..."
# Jellyfin, Nextcloud, Immich, AdGuard, Home Assistant, Tailscale
rsync -a --delete /home/umbrel/umbrel/app-data/ "${LOCAL_DEST}/app_data/"

# 3. BACKUP DAS STACKS CUSTOMIZADAS (compose)
echo "--> 3/6 Sincronizando stacks customizadas (Docker Compose)..."
rsync -a --delete /home/umbrel/umbrelos-scripts/compose/ "${LOCAL_DEST}/custom_stacks/"

# 4. BACKUP DAS CONFIGURAÇÕES DO SISTEMA E PERSISTÊNCIA (/data)
# EXCLUIR /data/umbrel-os pois é a partição de montagens e loops do sistema Rugix
echo "--> 4/6 Sincronizando diretório persistente /data (excluindo loops de sistema)..."
rsync -a --delete --exclude='umbrel-os' /data/ "${LOCAL_DEST}/system_data/"

# 5. BACKUP DE ARQUIVOS DE USUÁRIOS E SHARES (disk2)
echo "--> 5/6 Sincronizando dados de usuários e compartilhados (disk2)..."
rsync -a --delete /home/umbrel/umbrel/external/disk2/ "${LOCAL_DEST}/user_files/"

echo "--> Backup local no disk3 concluído com sucesso!"
du -sh "${LOCAL_DEST}"

# 6. SINCRONIZAR PARA O POP!_OS (Desktop - /mnt/storage_930/Backups_Homelab)
echo "--> 6/6 Enviando cópia para o Pop!_OS (${POPOS_DEST})..."
if ping -c 1 -W 2 "$POPOS_HOST" >/dev/null 2>&1; then
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new "${POPOS_USER}@${POPOS_HOST}" "mkdir -p '${POPOS_DEST}'"
    rsync -avz -e "ssh -i $SSH_KEY" "${LOCAL_DEST}/" "${POPOS_USER}@${POPOS_HOST}:${POPOS_DEST}/"
    echo "--> Sincronização com Pop!_OS concluída com sucesso!"
else
    echo "AVISO: Pop!_OS não respondeu ao ping. O backup permanece seguro no disk3."
fi

echo "=========================================================="
echo " BACKUP PRÉ-UPGRADE FINALIZADO COM SUCESSO: $(date)"
echo " Local no Servidor: ${LOCAL_DEST}"
echo " Local no Desktop:  ${POPOS_DEST}"
echo "=========================================================="
