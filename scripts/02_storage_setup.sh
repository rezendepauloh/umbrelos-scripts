#!/usr/bin/env bash
# ==============================================================================
# scripts/02_storage_setup.sh - Configuração de Armazenamento Nativo (3 TB)
# ==============================================================================
# Arquitetura Nativa:
#   - disk1 (1TB Seagate): Mídia & Downloads (Jellyfin, Arr-Stack, qBittorrent)
#   - disk2 (1TB A-DATA): Nuvem & Usuários (Nextcloud, Immich, Samba)
#   - disk3 (1TB Samsung): Backups Locais e contingência
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "${SCRIPT_DIR}/lib/common.sh" ]] && source "${SCRIPT_DIR}/lib/common.sh"
[[ -f "${SCRIPT_DIR}/config.env" ]] && source "${SCRIPT_DIR}/config.env"

log_step "Módulo 2: Configuração dos Discos Externos Nativos (3 TB)"

# 1. Criação dos pontos de montagem nativos
log_info "Garantindo pontos de montagem oficiais em /home/umbrel/umbrel/external..."
ensure_dir "${DISK1_MOUNT:-/home/umbrel/umbrel/external/disk1}" "${SYSTEM_USER}" "${SYSTEM_GROUP}" "775"
ensure_dir "${DISK2_MOUNT:-/home/umbrel/umbrel/external/disk2}" "${SYSTEM_USER}" "${SYSTEM_GROUP}" "775"
ensure_dir "${DISK3_MOUNT:-/home/umbrel/umbrel/external/disk3}" "${SYSTEM_USER}" "${SYSTEM_GROUP}" "775"

# Listar discos e UUIDs
log_info "Discos detectados atualmente no sistema:"
lsblk -o NAME,SIZE,FSTYPE,LABEL,UUID,MOUNTPOINT || true

# 2. Montar discos por Label se já não estiverem montados
mount -L disk1 "${DISK1_MOUNT}" 2>/dev/null || true
mount -L disk2 "${DISK2_MOUNT}" 2>/dev/null || true
mount -L disk3 "${DISK3_MOUNT}" 2>/dev/null || true

# 3. Criação da árvore canônica de diretórios nos discos certos
log_info "Criando subpastas de Mídia no disk1..."
ensure_dir "${MEDIA_DIR}" "${SYSTEM_USER}" "${SYSTEM_GROUP}" "775"
ensure_dir "${MOVIES_DIR}" "${SYSTEM_USER}" "${SYSTEM_GROUP}" "775"
ensure_dir "${SERIES_DIR}" "${SYSTEM_USER}" "${SYSTEM_GROUP}" "775"
ensure_dir "${MUSIC_DIR}" "${SYSTEM_USER}" "${SYSTEM_GROUP}" "775"
ensure_dir "${TORRENTS_DIR}" "${SYSTEM_USER}" "${SYSTEM_GROUP}" "775"

log_info "Criando subpastas de Nuvem e Usuários no disk2..."
ensure_dir "${IMMICH_UPLOAD_DIR}" "${SYSTEM_USER}" "${SYSTEM_GROUP}" "775"
ensure_dir "${NEXTCLOUD_DATA_DIR}" "${SYSTEM_USER}" "${SYSTEM_GROUP}" "775"
if [[ -n "${SAMBA_USER_1:-}" ]]; then
    U1_DIR="${USER_1_DIR:-${USER_PAULO_DIR:-${DISK2_MOUNT}/users/${SAMBA_USER_1}}}"
    ensure_dir "${U1_DIR}" "${SYSTEM_USER}" "${SYSTEM_GROUP}" "777"
fi
if [[ -n "${SAMBA_USER_2:-}" ]]; then
    U2_DIR="${USER_2_DIR:-${USER_KAMILA_DIR:-${DISK2_MOUNT}/users/${SAMBA_USER_2}}}"
    ensure_dir "${U2_DIR}" "${SYSTEM_USER}" "${SYSTEM_GROUP}" "777"
fi
ensure_dir "${SHARED_DIR}" "${SYSTEM_USER}" "${SYSTEM_GROUP}" "777"

log_info "Criando subpasta de Backups no disk3..."
ensure_dir "${LOCAL_BACKUP_DIR}" "${SYSTEM_USER}" "${SYSTEM_GROUP}" "775"

# 4. Instalar o Daemon Persistente e Configurações em /data
log_info "Instalando /data/bin/homelab-daemon.sh e persistindo /data/config.env..."
mkdir -p /data/bin
if [[ -f "${SCRIPT_DIR}/config.env" ]]; then
    cp -f "${SCRIPT_DIR}/config.env" /data/config.env
    chmod 600 /data/config.env
fi
cp -f "${SCRIPT_DIR}/scripts/homelab-daemon.sh" /data/bin/homelab-daemon.sh
chmod +x /data/bin/homelab-daemon.sh

# 5. Registrar no Hook Oficial do umbrelOS (/home/umbrel/umbrel/custom-hooks/pre-start)
log_info "Configurando Hook Oficial de Boot do umbrelOS (/home/umbrel/umbrel/custom-hooks/pre-start)..."
mkdir -p /home/umbrel/umbrel/custom-hooks
cat << EOF > /home/umbrel/umbrel/custom-hooks/pre-start
#!/usr/bin/env bash

# 1. Restaurar usuários do Linux para o Samba
$( [[ -n "${SAMBA_USER_1:-}" ]] && echo "id ${SAMBA_USER_1} >/dev/null 2>&1 || /usr/sbin/useradd -M -s /usr/sbin/nologin ${SAMBA_USER_1} || true" )
$( [[ -n "${SAMBA_USER_2:-}" ]] && echo "id ${SAMBA_USER_2} >/dev/null 2>&1 || /usr/sbin/useradd -M -s /usr/sbin/nologin ${SAMBA_USER_2} || true" )

# 2. Garantir smb.conf com passdb persistente
if [ -f "/data/samba/passdb.tdb" ]; then
    if ! grep -q "tdbsam:/data/samba/passdb.tdb" /etc/samba/smb.conf 2>/dev/null; then
        sed -i '/passdb backend/d' /etc/samba/smb.conf 2>/dev/null || true
        sed -i '/\[global\]/a \   passdb backend = tdbsam:/data/samba/passdb.tdb' /etc/samba/smb.conf 2>/dev/null || true
    fi
fi

# 3. Disparar o daemon independente desvinculado do cgroup
systemd-run --unit=homelab-daemon /data/bin/homelab-daemon.sh

exit 0
EOF
chmod +x /home/umbrel/umbrel/custom-hooks/pre-start
log_success "Hook Oficial de Boot do umbrelOS configurado com sucesso!"

# 6. Mapeamento Bind nativo para o Jellyfin
UMBREL_DOWNLOADS_DIR="/home/umbrel/umbrel/home/Downloads"
mkdir -p "${UMBREL_DOWNLOADS_DIR}/media" 2>/dev/null || true
mount --bind "${MEDIA_DIR}" "${UMBREL_DOWNLOADS_DIR}/media" 2>/dev/null || true
chown -R "${SYSTEM_USER}:${SYSTEM_GROUP}" "${UMBREL_DOWNLOADS_DIR}" 2>/dev/null || true
log_success "Mapeamento nativo para o Jellyfin configurado!"

log_success "Módulo de Storage Nativo (3 TB) concluído com sucesso!"
