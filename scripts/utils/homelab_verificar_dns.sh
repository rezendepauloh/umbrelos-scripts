#!/usr/bin/env bash
# ==============================================================================
# scripts/utils/homelab_verificar_dns.sh
# ------------------------------------------------------------------------------
# Diagnostica e corrige a resolução DNS local (*.pk.local -> 192.168.0.8):
# 1. Testa se o AdGuard Home (192.168.0.8:53) está respondendo e resolvendo *.pk.local
# 2. Testa se o Nginx Proxy Manager (:8088 / :8443) está respondendo aos domínios
# 3. Verifica a configuração de DNS do Pop!_OS (NetworkManager)
#
# Uso:
#   ./scripts/utils/homelab_verificar_dns.sh        # Apenas diagnostica
#   ./scripts/utils/homelab_verificar_dns.sh --fix  # Diagnostica e corrige falhas
# ==============================================================================

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

FIX_MODE=false
for arg in "$@"; do
    case "$arg" in
        --fix) FIX_MODE=true ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.env"
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

SERVER_HOST="${SERVER_HOST:-192.168.0.8}"
SERVER_USER="${SERVER_USER:-umbrel}"
SSH_KEY="${HOME}/.ssh/id_ed25519"

TEST_DOMAINS=(
    "umbrel.pk.local"
    "adguard.pk.local"
    "npm.pk.local"
    "proxy.pk.local"
    "fotos.pk.local"
    "nuvem.pk.local"
    "jellyfin.pk.local"
    "home.pk.local"
    "dockge.pk.local"
    "dozzle.pk.local"
    "status.pk.local"
    "tools.pk.local"
    "it.pk.local"
    "syncthing.pk.local"
    "pedidos.pk.local"
    "filmes.pk.local"
    "radarr.pk.local"
    "series.pk.local"
    "sonarr.pk.local"
    "trackers.pk.local"
    "prowlarr.pk.local"
    "legendas.pk.local"
    "bazarr.pk.local"
    "torrent.pk.local"
    "jackett.pk.local"
    "coolify.pk.local"
    "karteman.pk.local"
    "diarios.pk.local"
    "investimentos.pk.local"
    "financas.pk.local"
)
ERRORS=0

echo -e "${BLUE}${BOLD}======================================================================${NC}"
echo -e "${BLUE}${BOLD}===        DIAGNÓSTICO E CORREÇÃO DE DNS LOCAL (*.pk.local)        ===${NC}"
echo -e "${BLUE}${BOLD}======================================================================${NC}"
$FIX_MODE && echo -e "${YELLOW}ℹ Modo --fix ativado: correções automáticas serão aplicadas se necessário.${NC}\n"

# ------------------------------------------------------------------------------
# 1. Testar resolução DNS no sistema local (Pop!_OS)
# ------------------------------------------------------------------------------
echo -e "${CYAN}[1/3] Testando resolução local de domínios *.pk.local...${NC}"
for domain in "${TEST_DOMAINS[@]}"; do
    resolved_ip=$(getent hosts "$domain" 2>/dev/null | awk '{print $1}' | head -n1 || true)
    if [ "$resolved_ip" = "$SERVER_HOST" ]; then
        echo -e "  ${GREEN}[✔]${NC} $domain -> $resolved_ip"
    else
        echo -e "  ${RED}[✘]${NC} $domain -> '${resolved_ip:-NÃO RESOLVIDO}' (esperado: $SERVER_HOST)"
        ERRORS=$((ERRORS + 1))
    fi
done

# ------------------------------------------------------------------------------
# 2. Testar porta DNS (53) e Proxy Reverso (8088 / 8443) no Mini PC
# ------------------------------------------------------------------------------
echo -e "\n${CYAN}[2/3] Testando serviços de DNS e Proxy Reverso em ${SERVER_HOST}...${NC}"
if nc -zu -w 2 "$SERVER_HOST" 53 2>/dev/null || nc -z -w 2 "$SERVER_HOST" 53 2>/dev/null; then
    echo -e "  ${GREEN}[✔]${NC} Porta DNS (53) acessível em ${SERVER_HOST}"
else
    echo -e "  ${RED}[✘]${NC} Porta DNS (53) inacessível em ${SERVER_HOST}"
    ERRORS=$((ERRORS + 1))
fi

if curl -s -o /dev/null -m 3 -w "%{http_code}" "http://fotos.pk.local:8088/" | grep -qE "^(200|301|302)$"; then
    echo -e "  ${GREEN}[✔]${NC} Nginx Proxy Manager HTTP (:8088) respondendo para fotos.pk.local"
else
    echo -e "  ${YELLOW}[!]${NC} Nginx Proxy Manager HTTP (:8088) não respondeu como esperado para fotos.pk.local"
    ERRORS=$((ERRORS + 1))
fi

if curl -sk -o /dev/null -m 3 -w "%{http_code}" "https://fotos.pk.local:8443/" | grep -qE "^(200|301|302)$"; then
    echo -e "  ${GREEN}[✔]${NC} Nginx Proxy Manager HTTPS (:8443) respondendo para fotos.pk.local"
else
    echo -e "  ${YELLOW}[!]${NC} Nginx Proxy Manager HTTPS (:8443) não respondeu como esperado para fotos.pk.local"
    ERRORS=$((ERRORS + 1))
fi

# ------------------------------------------------------------------------------
# 3. Verificar configuração de DNS no Pop!_OS (NetworkManager)
# ------------------------------------------------------------------------------
echo -e "\n${CYAN}[3/3] Verificando DNS configurado no Pop!_OS (NetworkManager)...${NC}"
ACTIVE_CONN=$(nmcli -t -f NAME,TYPE,DEVICE connection show --active | grep -E ':802-3-ethernet:|:802-11-wireless:' | head -n1 | cut -d: -f1 || true)
if [ -n "$ACTIVE_CONN" ]; then
    CURRENT_DNS=$(nmcli -g ipv4.dns connection show "$ACTIVE_CONN" 2>/dev/null || true)
    if echo "$CURRENT_DNS" | grep -q "$SERVER_HOST"; then
        echo -e "  ${GREEN}[✔]${NC} Conexão '${ACTIVE_CONN}' usa DNS ${SERVER_HOST}"
    else
        echo -e "  ${RED}[✘]${NC} Conexão '${ACTIVE_CONN}' não está usando DNS ${SERVER_HOST} (atual: '${CURRENT_DNS:-automático}')"
        ERRORS=$((ERRORS + 1))
        if $FIX_MODE; then
            echo -e "  ${YELLOW}→ Aplicando DNS ${SERVER_HOST} e domínio ~pk.local em '${ACTIVE_CONN}'...${NC}"
            nmcli connection modify "$ACTIVE_CONN" ipv4.dns "$SERVER_HOST" ipv4.dns-search "~pk.local" ipv4.ignore-auto-dns yes
            nmcli connection up "$ACTIVE_CONN" >/dev/null
            echo -e "  ${GREEN}[✔]${NC} DNS local corrigido no Pop!_OS!"
        fi
    fi
else
    echo -e "  ${YELLOW}[!]${NC} Nenhuma conexão Ethernet/Wi-Fi ativa detectada via nmcli."
fi

# ------------------------------------------------------------------------------
# Correção remota no servidor (se --fix e ainda houver erros)
# ------------------------------------------------------------------------------
if $FIX_MODE && [ "$ERRORS" -gt 0 ]; then
    echo -e "\n${CYAN}[FIX] Verificando/reiniciando AdGuard Home no Mini PC (${SERVER_HOST})...${NC}"
    if ssh -i "${SSH_KEY}" -o ConnectTimeout=4 -o BatchMode=yes "${SERVER_USER}@${SERVER_HOST}" "exit 0" 2>/dev/null; then
        ssh -o LogLevel=ERROR -i "${SSH_KEY}" "${SERVER_USER}@${SERVER_HOST}" "echo '${SYSTEM_PASSWORD:-}' | sudo -S docker restart adguard-home_server_1 2>/dev/null || echo '${SYSTEM_PASSWORD:-}' | sudo -S docker ps --filter name=adguard -q | xargs -r sudo docker restart" || true
        echo -e "  ${GREEN}[✔]${NC} Solicitação de reinício do AdGuard Home enviada."
    else
        echo -e "  ${RED}[✘]${NC} Não foi possível conectar via SSH para reiniciar serviços no Mini PC."
    fi
fi

echo ""
if [ "$ERRORS" -eq 0 ]; then
    echo -e "${GREEN}${BOLD}[✔] Tudo certo! DNS local e Proxy Reverso (*.pk.local) estão 100% operacionais.${NC}"
else
    if $FIX_MODE; then
        echo -e "${YELLOW}${BOLD}[!] Correções aplicadas. Rode novamente sem --fix para confirmar.${NC}"
    else
        echo -e "${RED}${BOLD}[!] Foram encontrados ${ERRORS} problema(s). Rode com --fix para tentar corrigir:${NC}"
        echo -e "    ./scripts/utils/homelab_verificar_dns.sh --fix"
    fi
    exit 1
fi

