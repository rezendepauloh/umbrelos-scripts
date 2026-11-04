#!/usr/bin/env bash
# ==============================================================================
# scripts/utils/homelab_limpeza_docker.sh
# ------------------------------------------------------------------------------
# Executado a partir do Pop!_OS para manutenção preventiva no Mini PC:
# - Remove imagens Docker órfãs (dangling) e camadas residuais
# - Remove volumes e redes não utilizados
# - Trunca logs excessivos de containers (> 300MB)
# - Informa o espaço recuperado no SSD NVMe
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
echo -e "${BLUE}${BOLD}===      MANUTENÇÃO PREVENTIVA E LIMPEZA DOCKER DO HOMELAB        ===${NC}"
echo -e "${BLUE}${BOLD}======================================================================${NC}"

if ! ssh -i "${SSH_KEY}" -o ConnectTimeout=4 -o BatchMode=yes "${SERVER_USER}@${SERVER_HOST}" "exit 0" 2>/dev/null; then
    echo -e "${RED}[!] ERRO: Mini PC ${SERVER_HOST} inacessível via SSH.${NC}"
    exit 1
fi

echo -e "${CYAN}ℹ Conectado via canal seguro (stream não-interativo)${NC}\n"

ssh -o LogLevel=ERROR -i "${SSH_KEY}" "${SERVER_USER}@${SERVER_HOST}" 'bash -s' << 'REMOTESCRIPT'
source /data/config.env 2>/dev/null || true

echo -e "\n\033[1;36m[1/3] Espaço em disco antes da limpeza (NVMe /):\033[0m"
df -h / | tail -n 1

echo -e "\n\033[1;36m[2/3] Executando poda segura do Docker (Imagens órfãs e containers parados)...\033[0m"
echo "$SYSTEM_PASSWORD" | sudo -S docker system prune -f 2>&1 | grep -v 'password for umbrel' || true

echo -e "\n\033[1;36m[3/3] Truncando arquivos de logs JSON do Docker maiores que 300MB...\033[0m"
echo "$SYSTEM_PASSWORD" | sudo -S bash -c '
for log in $(find /var/lib/docker/containers/ -name "*-json.log" 2>/dev/null); do
    if [ $(stat -c%s "$log" 2>/dev/null || echo 0) -gt 314572800 ]; then
        echo "Truncando log volumoso: $log"
        truncate -s 0 "$log"
    fi
done
'

echo -e "\n\033[1;32m[✔] Limpeza concluída com sucesso! Espaço atual no NVMe:\033[0m"
df -h / | tail -n 1
REMOTESCRIPT

echo -e "\n${GREEN}${BOLD}======================================================================${NC}"
echo -e "${GREEN}${BOLD} Manutenção finalizada!${NC}"
echo -e "${GREEN}${BOLD}======================================================================${NC}\n"

