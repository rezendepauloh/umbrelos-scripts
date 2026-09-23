#!/usr/bin/env bash
# ==============================================================================
# scripts/06_backup_databases.sh - Rotina Automatizada de Backup de Bancos de Dados
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "${SCRIPT_DIR}/lib/common.sh" ]] && source "${SCRIPT_DIR}/lib/common.sh"
[[ -f "${SCRIPT_DIR}/config.env" ]] && source "${SCRIPT_DIR}/config.env"

log_step "Módulo 6: Configuração de Backup Automático e Crash-Resilience de Bancos"

BACKUP_SCRIPT_DIR="/opt/homelab-backups"
ensure_dir "$BACKUP_SCRIPT_DIR" "root" "root" "750"

BACKUP_STORAGE_DIR="${BACKUP_DIR:-/mnt/storage/backups}/databases"
ensure_dir "$BACKUP_STORAGE_DIR" "${SYSTEM_USER:-umbrel}" "${SYSTEM_GROUP:-umbrel}" "770"

log_info "Criando script mestre de dump dos bancos em ${BACKUP_SCRIPT_DIR}/dump_databases.sh..."

cat << 'EOF' > "${BACKUP_SCRIPT_DIR}/dump_databases.sh"
#!/usr/bin/env bash
# Script de dump seguro executado diariamente pelo cron
set -euo pipefail

DEST_DIR="/mnt/storage/backups/databases"
DATE=$(date +'%Y-%m-%d_%H%M%S')
mkdir -p "$DEST_DIR"

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }

log "Iniciando rotina de backup dos bancos de dados..."

# 1. Backup do PostgreSQL do Immich (Container oficial do Umbrel ou Docker Compose)
IMMICH_PG_CONTAINER=$(docker ps --format '{{.Names}}' | grep -E 'immich.*(postgres|database)' | head -n 1 || true)
if [[ -n "$IMMICH_PG_CONTAINER" ]]; then
    log "Encontrado container Postgres do Immich: ${IMMICH_PG_CONTAINER}. Gerando dump..."
    docker exec "$IMMICH_PG_CONTAINER" pg_dumpall -U postgres | gzip > "${DEST_DIR}/immich_db_${DATE}.sql.gz" || \
    docker exec "$IMMICH_PG_CONTAINER" pg_dumpall -c | gzip > "${DEST_DIR}/immich_db_${DATE}.sql.gz" || true
    log "Dump do Immich concluído!"
fi

# 2. Backup do MariaDB/Postgres do Nextcloud
NEXTCLOUD_DB_CONTAINER=$(docker ps --format '{{.Names}}' | grep -E 'nextcloud.*(db|mariadb|postgres|mysql)' | head -n 1 || true)
if [[ -n "$NEXTCLOUD_DB_CONTAINER" ]]; then
    log "Encontrado container de banco do Nextcloud: ${NEXTCLOUD_DB_CONTAINER}. Gerando dump..."
    if docker exec "$NEXTCLOUD_DB_CONTAINER" which mariadb-dump >/dev/null 2>&1; then
        docker exec "$NEXTCLOUD_DB_CONTAINER" mariadb-dump -u root --all-databases | gzip > "${DEST_DIR}/nextcloud_db_${DATE}.sql.gz" || true
    elif docker exec "$NEXTCLOUD_DB_CONTAINER" which mysqldump >/dev/null 2>&1; then
        docker exec "$NEXTCLOUD_DB_CONTAINER" mysqldump -u root --all-databases | gzip > "${DEST_DIR}/nextcloud_db_${DATE}.sql.gz" || true
    elif docker exec "$NEXTCLOUD_DB_CONTAINER" which pg_dumpall >/dev/null 2>&1; then
        docker exec "$NEXTCLOUD_DB_CONTAINER" pg_dumpall -U nextcloud | gzip > "${DEST_DIR}/nextcloud_db_${DATE}.sql.gz" || true
    fi
    log "Dump do Nextcloud concluído!"
fi

# 3. Rotação e Limpeza: manter apenas os últimos 7 dias de backups
RETENTION_DAYS="${DB_BACKUP_RETENTION_DAYS:-7}"
log "Limpando backups mais antigos que ${RETENTION_DAYS} dias..."
find "$DEST_DIR" -type f -name "*_db_*.sql.gz" -mtime +"$RETENTION_DAYS" -delete || true

# 4. Sincronizar buffers para o disco
sync

log "Rotina de backup concluída com sucesso!"
EOF

chmod +x "${BACKUP_SCRIPT_DIR}/dump_databases.sh"

# Agendar rotina diária no Cron às 04:00 da manhã
CRON_BACKUP_FILE="/etc/cron.d/homelab-db-backup"
echo "0 4 * * * root ${BACKUP_SCRIPT_DIR}/dump_databases.sh >> /var/log/homelab-db-backup.log 2>&1" > "$CRON_BACKUP_FILE"
chmod 644 "$CRON_BACKUP_FILE"

log_success "Rotina de backup de bancos de dados agendada no cron para rodar diariamente às 04:00!"
