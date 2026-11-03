#!/usr/bin/env bash
# ==============================================================================
# scripts/utils/homelab_atualizar_stacks.sh
# ------------------------------------------------------------------------------
# Executado a partir do Pop!_OS para atualizar de forma inteligente as stacks
# Docker personalizadas no Mini PC (management, arr-stack, tunnels, etc.).
# Só recria o que realmente tiver atualização de imagem baixada.
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
echo -e "${BLUE}${BOLD}===      ATUALIZADOR AUTOMÁTICO DE STACKS DOCKER DO HOMELAB        ===${NC}"
echo -e "${BLUE}${BOLD}======================================================================${NC}"

# Teste de conexão
if ! ssh -i "${SSH_KEY}" -o ConnectTimeout=4 -o BatchMode=yes "${SERVER_USER}@${SERVER_HOST}" "exit 0" 2>/dev/null; then
    echo -e "${RED}[!] ERRO: Mini PC ${SERVER_HOST} inacessível via SSH.${NC}"
    exit 1
fi

ssh -i "${SSH_KEY}" -t "${SERVER_USER}@${SERVER_HOST}" 'bash -s' << 'REMOTESCRIPT'
source /data/config.env 2>/dev/null || true

COMPOSE_BASE="/home/umbrel/umbrelos-scripts/compose"
if [ ! -d "$COMPOSE_BASE" ]; then
    echo "Diretório de stacks $COMPOSE_BASE não encontrado."
    exit 1
fi

STACKS=("management" "arr-stack" "tunnels")

for stack in "${STACKS[@]}"; do
    STACK_DIR="$COMPOSE_BASE/$stack"
    if [ -f "$STACK_DIR/docker-compose.yml" ]; then
        echo -e "\n\033[1;36m[+] Verificando atualizações para a stack: $stack\033[0m"
        cd "$STACK_DIR"
        
        # Pull de novas imagens
        echo "$SYSTEM_PASSWORD" | sudo -S docker compose --env-file /home/umbrel/umbrelos-scripts/.env pull 2>&1 | grep -v 'password for umbrel' || true
        
        # Up recreation automática
        echo "$SYSTEM_PASSWORD" | sudo -S docker compose --env-file /home/umbrel/umbrelos-scripts/.env up -d 2>&1 | grep -v 'password for umbrel' || true
    fi
done

echo -e "\n\033[1;32m[✔] Todas as stacks customizadas foram verificadas e atualizadas!\033[0m"
REMOTESCRIPT

echo -e "\n${GREEN}${BOLD}======================================================================${NC}"
echo -e "${GREEN}${BOLD} Atualização concluída com sucesso!${NC}"
echo -e "${GREEN}${BOLD}======================================================================${NC}\n"

