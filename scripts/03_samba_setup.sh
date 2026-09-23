#!/usr/bin/env bash
# ==============================================================================
# scripts/03_samba_setup.sh - Configuração do Servidor de Arquivos Samba
# ==============================================================================
# Arquitetura Nativa:
#   - Paulo / Kamila / Compartilhado -> /home/umbrel/umbrel/external/disk2
#   - Midia                          -> /home/umbrel/umbrel/external/disk1/media
#   - Backups                        -> /home/umbrel/umbrel/external/disk3/backups
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "${SCRIPT_DIR}/lib/common.sh" ]] && source "${SCRIPT_DIR}/lib/common.sh"
[[ -f "${SCRIPT_DIR}/config.env" ]] && source "${SCRIPT_DIR}/config.env"

log_step "Módulo 3: Configuração do Servidor Samba (Storage Nativo)"

# Criação de usuários no sistema caso não existam
setup_system_and_smb_user() {
    local username="$1"
    
    if ! id "$username" >/dev/null 2>&1; then
        log_info "Criando usuário de sistema: ${username}..."
        /usr/sbin/useradd -M -s /usr/sbin/nologin "$username" 2>/dev/null || useradd -M -s /usr/sbin/nologin "$username" || true
    fi

    # Configuração de senha interativa do Samba (caso não cadastrado no banco de /data)
    if ! pdbedit -L | grep -q "^${username}:"; then
        log_warn "Defina uma senha de acesso Samba para o usuário '${username}':"
        smbpasswd -a "$username"
        smbpasswd -e "$username"
        log_success "Usuário Samba '${username}' ativado!"
    else
        log_info "Usuário Samba '${username}' já existe no banco do Samba."
    fi
}

if [[ -n "${SAMBA_USER_1:-}" ]]; then
    setup_system_and_smb_user "${SAMBA_USER_1}"
fi

if [[ -n "${SAMBA_USER_2:-}" ]]; then
    setup_system_and_smb_user "${SAMBA_USER_2}"
fi

SAMBA_CONF_FILE="/etc/samba/smb.conf"

SYS_USER="${SYSTEM_USER:-umbrel}"
D1_MOUNT="${DISK1_MOUNT:-/home/umbrel/umbrel/external/disk1}"
D2_MOUNT="${DISK2_MOUNT:-/home/umbrel/umbrel/external/disk2}"
D3_MOUNT="${DISK3_MOUNT:-/home/umbrel/umbrel/external/disk3}"
DIR_MEDIA="${MEDIA_DIR:-${D1_MOUNT}/media}"
DIR_SHARED="${SHARED_DIR:-${D2_MOUNT}/shared}"
DIR_BACKUP="${LOCAL_BACKUP_DIR:-${D3_MOUNT}/backups}"

# Montar lista de usuários autorizados para pastas comuns
ALL_SMB_USERS="${SYS_USER}"
[[ -n "${SAMBA_USER_1:-}" ]] && ALL_SMB_USERS="${SAMBA_USER_1}, ${ALL_SMB_USERS}"
[[ -n "${SAMBA_USER_2:-}" ]] && ALL_SMB_USERS="${SAMBA_USER_2}, ${ALL_SMB_USERS}"

log_info "Escrevendo configurações customizadas no ${SAMBA_CONF_FILE}..."
cat << 'EOF' > "$SAMBA_CONF_FILE"
[global]
   workgroup = WORKGROUP
   server string = Umbrel Homelab Samba Server
   server role = standalone server
   security = user
   map to guest = Bad User
   dns proxy = no
   log file = /var/log/samba/%m.log
   max log size = 50
   load printers = no
   printing = bsd
   printcap name = /dev/null
   disable spoolss = yes
   vfs objects = catia fruit streams_xattr
   fruit:metadata = stream
   fruit:model = Macmini
   fruit:posix_rename = yes
   fruit:veto_appledouble = no
   fruit:wipe_intentionally_left_blank_rfork = yes
   fruit:delete_empty_adfiles = yes

   # Otimizações de performance
   socket options = TCP_NODELAY IPTOS_LOWDELAY SO_RCVBUF=131072 SO_SNDBUF=131072
   use sendfile = yes
EOF

# Compartilhamento privado para SAMBA_USER_1
if [[ -n "${SAMBA_USER_1:-}" ]]; then
    U1_NAME="${SAMBA_USER_1}"
    U1_SECTION="${U1_NAME^}"
    U1_PATH="${USER_1_DIR:-${USER_PAULO_DIR:-${D2_MOUNT}/users/${U1_NAME}}}"
    cat << EOF >> "$SAMBA_CONF_FILE"

[${U1_SECTION}]
   comment = Arquivos Pessoais ${U1_SECTION} (${D2_MOUNT})
   path = ${U1_PATH}
   valid users = ${U1_NAME}, ${SYS_USER}
   read only = no
   writable = yes
   browsable = yes
   create mask = 0775
   directory mask = 0775
   force user = ${SYS_USER}
EOF
fi

# Compartilhamento privado para SAMBA_USER_2
if [[ -n "${SAMBA_USER_2:-}" ]]; then
    U2_NAME="${SAMBA_USER_2}"
    U2_SECTION="${U2_NAME^}"
    U2_PATH="${USER_2_DIR:-${USER_KAMILA_DIR:-${D2_MOUNT}/users/${U2_NAME}}}"
    cat << EOF >> "$SAMBA_CONF_FILE"

[${U2_SECTION}]
   comment = Arquivos Pessoais ${U2_SECTION} (${D2_MOUNT})
   path = ${U2_PATH}
   valid users = ${U2_NAME}, ${SYS_USER}
   read only = no
   writable = yes
   browsable = yes
   create mask = 0775
   directory mask = 0775
   force user = ${SYS_USER}
EOF
fi

# Compartilhamentos compartilhados e de mídia/backup
cat << EOF >> "$SAMBA_CONF_FILE"

[Compartilhado]
   comment = Compartilhamento Comum (${D2_MOUNT})
   path = ${DIR_SHARED}
   valid users = ${ALL_SMB_USERS}
   read only = no
   writable = yes
   browsable = yes
   create mask = 0775
   directory mask = 0775
   force user = ${SYS_USER}

[Midia]
   comment = Mídias Homelab - Filmes, Séries, Torrents (${D1_MOUNT})
   path = ${DIR_MEDIA}
   valid users = ${ALL_SMB_USERS}
   read only = no
   writable = yes
   browsable = yes
   create mask = 0775
   directory mask = 0775
   force user = ${SYS_USER}

[Backups]
   comment = Backups Locais (${D3_MOUNT})
   path = ${DIR_BACKUP}
   valid users = ${ALL_SMB_USERS}
   read only = no
   writable = yes
   browsable = yes
   create mask = 0775
   directory mask = 0775
   force user = ${SYS_USER}
EOF

# Backup persistente em /data para sobreviver a reboots do Rugix OS
mkdir -p /data/samba
cp "$SAMBA_CONF_FILE" /data/samba/smb.conf

# Reiniciar e habilitar serviços do Samba
log_info "Reiniciando e habilitando serviço Samba (smbd e nmbd)..."
systemctl enable smbd nmbd || true
systemctl restart smbd nmbd || true

log_success "Samba configurado com sucesso e persistente na rede!"
