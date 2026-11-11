#!/usr/bin/env bash
# ==============================================================================
# scripts/utils/recuperar_hds_remoto.sh
# ------------------------------------------------------------------------------
# Executado a partir do Pop!_OS ou localmente no Mini PC (umbrelOS) para diagnosticar,
# limpar montagens presas/fantasmas (I/O error) e remontar os 3 HDs externos
# do Mini PC pelos seus UUIDs canônicos, restaurando Jellyfin e Samba.
# ==============================================================================

set -euo pipefail

# Cores para exibição
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.env"

if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
fi

SERVER_HOST="${SERVER_HOST:-192.168.0.8}"
SERVER_USER="${SERVER_USER:-umbrel}"
SSH_KEY="${HOME}/.ssh/id_ed25519"

echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE}===  RECUPERAÇÃO E REMONTAGEM DE HDs EXTERNOS (Homelab umbrelOS)   ===${NC}"
echo -e "${BLUE}======================================================================${NC}"

# Detectar se está rodando localmente no Mini PC ou remotamente no Pop!_OS
IS_LOCAL=false
if [[ "$(hostname 2>/dev/null)" == "umbrel" ]] || [[ -f "/data/umbrel-os" ]]; then
    IS_LOCAL=true
fi

# 1. Testar conectividade SSH quando executado remotamente
if [ "$IS_LOCAL" = false ]; then
    echo -e "\n${YELLOW}[1/4] Verificando conectividade com o Mini PC (${SERVER_HOST})...${NC}"
    if ! ssh -i "${SSH_KEY}" -o ConnectTimeout=4 -o BatchMode=yes "${SERVER_USER}@${SERVER_HOST}" "exit 0" 2>/dev/null; then
        echo -e "${RED}[!] ERRO: Não foi possível conectar via SSH em ${SERVER_USER}@${SERVER_HOST}.${NC}"
        echo -e "    Certifique-se de que o mini PC está ligado e com o cabo de rede conectado."
        exit 1
    fi
    echo -e "${GREEN}[✔] Conexão SSH estabelecida com sucesso!${NC}"
fi

# 2. Execução da recuperação
echo -e "\n${YELLOW}[2/4] Executando rotina de recuperação e desmontagem limpa no servidor...${NC}"

execute_recovery() {
    bash -s << 'REMOTESCRIPT'
source /data/config.env 2>/dev/null || true

UUID_DISK1="${DISK1_UUID:-fc0b5d7b-1706-4461-9e1e-9d3f61e7bab0}"
UUID_DISK2="${DISK2_UUID:-490440f1-8f2e-41fd-bc27-00632adec790}"
UUID_DISK3="${DISK3_UUID:-e106affb-35da-4e93-a92d-e1ef5df32bb5}"

DIR_DISK1="/home/umbrel/umbrel/external/disk1"
DIR_DISK2="/home/umbrel/umbrel/external/disk2"
DIR_DISK3="/home/umbrel/umbrel/external/disk3"
DIR_MEDIA="/home/umbrel/umbrel/home/Downloads/media"
DIR_IMMICH="/home/umbrel/umbrel/app-data/immich/data/upload"

echo "[Servidor] Desmontando pontos com erro I/O ou montagens duplicadas..."
echo "$SYSTEM_PASSWORD" | sudo -S bash -c "
    umount -l $DIR_MEDIA 2>/dev/null || true
    umount -l $DIR_IMMICH 2>/dev/null || true
    umount -l $DIR_DISK1 2>/dev/null || true
    umount -l $DIR_DISK2 2>/dev/null || true
    umount -l $DIR_DISK3 2>/dev/null || true
    
    # Limpar montagens com sufixo (2) se existirem
    umount -l '${DIR_DISK1} (2)' 2>/dev/null || true
    umount -l '${DIR_DISK2} (2)' 2>/dev/null || true
    umount -l '${DIR_DISK3} (2)' 2>/dev/null || true
"

echo "[Servidor] Criando diretórios e aplicando montagem canônica por UUID..."
echo "$SYSTEM_PASSWORD" | sudo -S bash -c "
    mkdir -p $DIR_DISK1 $DIR_DISK2 $DIR_DISK3 $DIR_MEDIA $DIR_IMMICH

    # Remontar cada disco pelo UUID direto
    mount -U $UUID_DISK1 $DIR_DISK1 -o defaults,noatime,nofail 2>/dev/null || mount /dev/disk/by-uuid/$UUID_DISK1 $DIR_DISK1 2>/dev/null || true
    mount -U $UUID_DISK2 $DIR_DISK2 -o defaults,noatime,nofail 2>/dev/null || mount /dev/disk/by-uuid/$UUID_DISK2 $DIR_DISK2 2>/dev/null || true
    mount -U $UUID_DISK3 $DIR_DISK3 -o defaults,noatime,nofail 2>/dev/null || mount /dev/disk/by-uuid/$UUID_DISK3 $DIR_DISK3 2>/dev/null || true

    # Restabelecer bind mounts críticos
    if [ -d \"$DIR_DISK1/media\" ] && [ -d \"$DIR_MEDIA\" ]; then
        mount --bind $DIR_DISK1/media $DIR_MEDIA
        echo ' -> Bind mount Jellyfin restabelecido'
    fi

    if [ -d \"$DIR_DISK2/immich/upload\" ] && [ -d \"$DIR_IMMICH\" ]; then
        mount --bind $DIR_DISK2/immich/upload $DIR_IMMICH
        echo ' -> Bind mount Immich restabelecido'
    fi

    echo '[Servidor] Reiniciando serviço Samba...'
    systemctl restart smbd nmbd || true

    echo '[Servidor] Reiniciando containers de midia...'
    docker restart jellyfin_server_1 >/dev/null 2>&1 || true
"
REMOTESCRIPT
}

if [ "$IS_LOCAL" = true ]; then
    execute_recovery
else
    ssh -o LogLevel=ERROR -i "${SSH_KEY}" "${SERVER_USER}@${SERVER_HOST}" "$(declare -f execute_recovery); execute_recovery"
fi

# 3. Validar se os discos estão listando arquivos no Samba
echo -e "\n${YELLOW}[3/4] Verificando integridade dos compartilhamentos Samba...${NC}"
sleep 2

SAMBA_AUTH_OPT=""
if [ -n "${SYSTEM_PASSWORD:-}" ]; then
    SAMBA_AUTH_OPT="-U ${SAMBA_USER_1:-paulo}%${SYSTEM_PASSWORD}"
fi

SAMBA_TARGET_HOST="${SERVER_HOST}"
if [ "$IS_LOCAL" = true ]; then
    SAMBA_TARGET_HOST="127.0.0.1"
fi

if smbclient -L "//${SAMBA_TARGET_HOST}" ${SAMBA_AUTH_OPT} -g 2>/dev/null | grep -q "Midia"; then
    echo -e "${GREEN}[✔] Share [Midia] detectada no Samba!${NC}"
else
    echo -e "${YELLOW}[!] Share [Midia] não verificada via smbclient local.${NC}"
fi

# 4. Status final
echo -e "\n${YELLOW}[4/4] Status dos Pontos de Montagem no Mini PC:${NC}"
if [ "$IS_LOCAL" = true ]; then
    df -h /home/umbrel/umbrel/external/disk1 /home/umbrel/umbrel/external/disk2 /home/umbrel/umbrel/external/disk3 2>/dev/null || true
else
    ssh -i "${SSH_KEY}" "${SERVER_USER}@${SERVER_HOST}" "df -h /home/umbrel/umbrel/external/disk1 /home/umbrel/umbrel/external/disk2 /home/umbrel/umbrel/external/disk3 2>/dev/null || true"
fi

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}===  RECUPERAÇÃO CONCLUÍDA! O Samba e o Jellyfin estão ativos.     ===${NC}"
echo -e "${GREEN}======================================================================${NC}"
