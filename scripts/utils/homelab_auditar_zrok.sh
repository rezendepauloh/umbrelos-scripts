#!/usr/bin/env bash
# ==============================================================================
# scripts/utils/homelab_auditar_zrok.sh
# ------------------------------------------------------------------------------
# Executado no Pop!_OS para auditar e testar a conectividade externa real dos
# 6 túneis públicos zrok v2 e do Tailscale do homelab.
# ==============================================================================

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BLUE}${BOLD}======================================================================${NC}"
echo -e "${BLUE}${BOLD}===      AUDITORIA DE ACESSO REMOTO (zrok v2 & Tailscale)          ===${NC}"
echo -e "${BLUE}${BOLD}======================================================================${NC}\n"

test_url() {
    local name="$1"
    local url="$2"
    local auth="${3:-}"
    
    local auth_opt=""
    [ -n "$auth" ] && auth_opt="-u $auth"
    
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 $auth_opt "$url" || echo "ERR")
    
    if [[ "$http_code" =~ ^(200|301|302|307|308|401)$ ]]; then
        printf "  %-32s [ \033[1;32mONLINE (HTTP %s)\033[0m ] -> %s\n" "$name" "$http_code" "$url"
    else
        printf "  %-32s [ \033[1;31mFALHA  (HTTP %s)\033[0m ] -> %s\n" "$name" "$http_code" "$url"
    fi
}

echo -e "${CYAN}${BOLD}[1/2] Testando Conectividade dos 6 Túneis Públicos zrok v2:${NC}"
test_url "Umbrel OS Dashboard" "https://umbrel-paulo.shares.zrok.io" ""
test_url "Nextcloud Nuvem" "https://cloud-paulo.shares.zrok.io" ""
test_url "Jellyfin Streaming" "https://jellyfin-paulo.shares.zrok.io" ""
test_url "Sistema Karteman" "https://karteman-paulo.shares.zrok.io" ""
test_url "Verifica Diários" "https://diarios-paulo.shares.zrok.io" "paulo:senha_oculta"
test_url "Investimentos Pessoais" "https://investimentos-paulo.shares.zrok.io" "paulo:senha_oculta"

echo -e "\n${CYAN}${BOLD}[2/2] Testando VPN Tailscale Homelab:${NC}"
TAILSCALE_HOST="100.88.159.41"
if ping -c 1 -W 2 "$TAILSCALE_HOST" >/dev/null 2>&1; then
    printf "  %-32s [ \033[1;32mONLINE (Ping OK)\033[0m ] -> %s\n" "Tailscale Mini PC" "$TAILSCALE_HOST"
else
    printf "  %-32s [ \033[1;33mINDISPONÍVEL (Ping OFF)\033[0m ] -> %s (Verifique se o Tailscale está ligado no Pop!_OS)\n" "Tailscale Mini PC" "$TAILSCALE_HOST"
fi

echo -e "\n${BLUE}${BOLD}======================================================================${NC}"
echo -e "${GREEN}${BOLD} Auditoria finalizada!${NC}"
echo -e "${BLUE}${BOLD}======================================================================${NC}\n"

