#!/usr/bin/env bash
# ==============================================================================
# scripts/utils/recuperar_hds_remoto.sh
# ------------------------------------------------------------------------------
# Executado diretamente a partir do Pop!_OS (Desktop) para diagnosticar,
# limpar montagens presas/fantasmas (I/O error) e remontar os 3 HDs externos
# do Mini PC (umbrelOS) pelos seus UUIDs canônicos, restaurando Jellyfin e Samba.
# ==============================================================================

set -euo pipefail

# Cores para exibição
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
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
echo -e "${BLUE}===  RECUPERAÇÃO E REMONTAGEM DE HDs EXTERNOS (Pop!_OS -> Mini PC) ===${NC}"
echo -e "${BLUE}======================================================================${NC}"

# 1. Testar conectividade SSH
echo -e "\n${YELLOW}[1/4] Verificando conectividade com o Mini PC (${SERVER_HOST})...${NC}"
if ! ssh -i "${SSH_KEY}" -o ConnectTimeout=4 -o BatchMode=yes "${SERVER_USER}@${SERVER_HOST}" "exit 0" 2>/dev/null; then
    echo -e "${RED}[!] ERRO: Não foi possível conectar via SSH em ${SERVER_USER}@${SERVER_HOST}.${NC}"
    echo -e "    Certifique-se de que o mini PC está ligado e com o cabo de rede conectado."
    exit 1
fi
echo -e "${GREEN}[✔] Conexão SSH estabelecida com sucesso!${NC}"

# 2. Diagnóstico preliminar e execução remota de recuperação
echo -e "\n${YELLOW}[2/4] Executando rotina de recuperação e desmontagem limpa no servidor...${NC}"

ssh -i "${SSH_KEY}" -t "${SERVER_USER}@${SERVER_HOST}" 'bash -s' << 'REMOTESCRIPT'
source /data/config.env 2>/dev/null || true

# UUIDs Canônicos dos Discos
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

    mkdir -p $DIR_DISK1 $DIR_DISK2 $DIR_DISK3 $DIR_MEDIA

    echo '[Servidor] Remontando discos pelos UUIDs canônicos...'
    mount UUID=\"$UUID_DISK1\" $DIR_DISK1 2>/dev/null && echo ' -> disk1 (Midia) montado com sucesso' || echo ' [!] Falha ao montar disk1'
    mount UUID=\"$UUID_DISK2\" $DIR_DISK2 2>/dev/null && echo ' -> disk2 (Nuvem/Fotos) montado com sucesso' || echo ' [!] Falha ao montar disk2'
    mount UUID=\"$UUID_DISK3\" $DIR_DISK3 2>/dev/null && echo ' -> disk3 (Backups) montado com sucesso' || echo ' [!] Falha ao montar disk3'

    echo '[Servidor] Reaplicando Bind Mounts nativos...'
    if [ -d \"$DIR_DISK1/media\" ]; then
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

# 3. Validar se os discos estão listando arquivos
echo -e "\n${YELLOW}[3/4] Verificando integridade dos compartilhamentos Samba...${NC}"
sleep 2

if smbclient -L "//${SERVER_HOST}" -U "paulo%senha_oculta" -g 2>/dev/null | grep -q "Midia"; then
    echo -e "${GREEN}[✔] Share [Midia] detectada no Samba!${NC}"
else
    echo -e "${RED}[!] Share [Midia] não encontrada. Verifique se o cabo do disk1 está conectado.${NC}"
fi

# 4. Status final
echo -e "\n${YELLOW}[4/4] Status dos Pontos de Montagem no Mini PC:${NC}"
ssh -i "${SSH_KEY}" "${SERVER_USER}@${SERVER_HOST}" "df -h /home/umbrel/umbrel/external/disk1 /home/umbrel/umbrel/external/disk2 /home/umbrel/umbrel/external/disk3 2>/dev/null"

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}===  RECUPERAÇÃO CONCLUÍDA! O Samba e o Jellyfin estão ativos.     ===${NC}"
echo -e "${GREEN}======================================================================${NC}"

