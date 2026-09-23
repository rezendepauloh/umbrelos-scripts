#!/usr/bin/env bash
# ==============================================================================
# scripts/06_backup_popos.sh
# ------------------------------------------------------------------------------
# Rotina de Backup Automatizado do Homelab para o Desktop Pop!_OS
# Local de instalação no servidor: /data/bin/backup-para-popos.sh
#
# Características:
#   1. Ping preventivo (se o Pop!_OS estiver desligado, encerra sem erro).
#   2. Dumps de todos os bancos de dados (Immich Postgres + Nextcloud MariaDB).
#   3. Sincronização via rsync incremental sobre SSH (documentos, fotos, configs).
#   4. Retenção de 7 dias com rotação automática (mantém sempre os 7 mais recentes).
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "${SCRIPT_DIR}/lib/common.sh" ]] && source "${SCRIPT_DIR}/lib/common.sh"
[[ -f "${SCRIPT_DIR}/config.env" ]] && source "${SCRIPT_DIR}/config.env"

log_step "Módulo 6: Instalação do Backup Remoto Inteligente para Pop!_OS"

TARGET_SCRIPT="/data/bin/backup-para-popos.sh"
mkdir -p /data/bin

POPOS_IP="${POPOS_HOST:-}"
POPOS_USR="${POPOS_USER:-}"
POPOS_DIR="${POPOS_DEST_DIR:-}"
SSH_KEY_PATH="${POPOS_SSH_KEY:-/home/umbrel/.ssh/id_ed25519}"
RETENTION="${BACKUP_RETENTION_DAYS:-7}"

if [[ "${ENABLE_POPOS_BACKUP:-false}" != "true" ]] || [[ -z "${POPOS_IP}" ]] || [[ -z "${POPOS_USR}" ]] || [[ -z "${POPOS_DIR}" ]]; then
    log_warn "Backup remoto desabilitado ou variáveis POPOS_HOST/POPOS_USER/POPOS_DEST_DIR não definidas em config.env."
    return 0 2>/dev/null || exit 0
fi

SRC_USERS_DIR="${DISK2_MOUNT:-/home/umbrel/umbrel/external/disk2}/users/"
SRC_SHARED_DIR="${SHARED_DIR:-${DISK2_MOUNT:-/home/umbrel/umbrel/external/disk2}/shared}/"

log_info "Escrevendo rotina de backup em ${TARGET_SCRIPT}..."

cat << EOF > "$TARGET_SCRIPT"
#!/usr/bin/env bash
# ==============================================================================
# backup-para-popos.sh
# Backup diário inteligente do Homelab para máquina de destino remota
# Retenção: ${RETENTION} dias (rotatividade automática)
# ==============================================================================

POPOS_HOST="${POPOS_IP}"
POPOS_USER="${POPOS_USR}"
POPOS_DEST="${POPOS_DIR}"
SSH_KEY="${SSH_KEY_PATH}"
SRC_USERS="${SRC_USERS_DIR}"
SRC_SHARED="${SRC_SHARED_DIR}"
LOG="/data/homelab-popos-backup.log"
DATE=\$(date +%Y-%m-%d)
BACKUP_DIR="\${POPOS_DEST}/backup_\${DATE}"

exec >> "\$LOG" 2>&1
echo "=== INÍCIO DA ROTINA DE BACKUP: \$(date) ==="

# 1. Checa se o host de destino está online na rede local
if ! ping -c 2 -W 2 "\$POPOS_HOST" >/dev/null 2>&1; then
    echo "Host remoto (\$POPOS_HOST) desligado ou inacessível. Backup adiado para a próxima janela."
    exit 0
fi

echo "Host remoto online! Iniciando transferência para \$BACKUP_DIR..."

# 2. Garante os diretórios criados no destino
ssh -i "\$SSH_KEY" -o StrictHostKeyChecking=accept-new "\${POPOS_USER}@\${POPOS_HOST}" "mkdir -p '\${BACKUP_DIR}/databases' '\${BACKUP_DIR}/nextcloud_users' '\${BACKUP_DIR}/shared' '\${BACKUP_DIR}/configs'"

# 3. Dumps dos bancos de dados locais
echo "Gerando dumps dos bancos de dados..."
TMP_DUMP="/tmp/dumps_\$(date +%s)"
mkdir -p "\$TMP_DUMP"

# Immich Postgres
IMMICH_CONTAINER=\$(docker ps --format '{{.Names}}' | grep -E 'immich.*(postgres|database)' | head -n 1 || true)
if [ -n "\$IMMICH_CONTAINER" ]; then
    docker exec "\$IMMICH_CONTAINER" pg_dumpall -U postgres 2>/dev/null | gzip > "\${TMP_DUMP}/immich_db.sql.gz" || true
fi

# Nextcloud DB
NC_DB_CONTAINER=\$(docker ps --format '{{.Names}}' | grep -E 'nextcloud.*(db|mariadb|postgres|mysql)' | head -n 1 || true)
if [ -n "\$NC_DB_CONTAINER" ]; then
    docker exec "\$NC_DB_CONTAINER" mariadb-dump -u root --all-databases 2>/dev/null | gzip > "\${TMP_DUMP}/nextcloud_db.sql.gz" || true
fi

# Envia os dumps compactados
rsync -avz -e "ssh -i \$SSH_KEY" "\${TMP_DUMP}/" "\${POPOS_USER}@\${POPOS_HOST}:\${BACKUP_DIR}/databases/"
rm -rf "\$TMP_DUMP"

# 4. Sincroniza arquivos de usuários e compartilhados (disk2)
echo "Sincronizando arquivos de usuários e compartilhados..."
rsync -avz --delete -e "ssh -i \$SSH_KEY" "\${SRC_USERS}" "\${POPOS_USER}@\${POPOS_HOST}:\${BACKUP_DIR}/nextcloud_users/"
rsync -avz --delete -e "ssh -i \$SSH_KEY" "\${SRC_SHARED}" "\${POPOS_USER}@\${POPOS_HOST}:\${BACKUP_DIR}/shared/"

# 5. Salva cópia das configurações críticas
echo "Sincronizando configurações essenciais..."
rsync -avz -e "ssh -i \$SSH_KEY" /data/samba/smb.conf "\${POPOS_USER}@\${POPOS_HOST}:\${BACKUP_DIR}/configs/" 2>/dev/null || true

# 6. Rotatividade: Manter apenas os ${RETENTION} backups mais recentes
echo "Aplicando política de retenção de ${RETENTION} dias..."
ssh -i "\$SSH_KEY" "\${POPOS_USER}@\${POPOS_HOST}" "
    cd '\${POPOS_DEST}' && \
    ls -dt backup_* 2>/dev/null | tail -n +$((RETENTION + 1)) | xargs -r rm -rf
"

echo "=== BACKUP CONCLUÍDO COM SUCESSO: \$(date) ==="
EOF

chmod +x "$TARGET_SCRIPT"

# 4. Agendar rotina diária no Cron às 03:30 da manhã
CRON_FILE="/etc/cron.d/homelab-popos-backup"
echo "30 3 * * * root ${TARGET_SCRIPT}" > "$CRON_FILE"
chmod 644 "$CRON_FILE"

log_success "Rotina de backup para o Pop!_OS instalada e agendada para 03:30 diariamente!"
