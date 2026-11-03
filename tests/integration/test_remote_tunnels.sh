#!/usr/bin/env bash
# ==============================================================================
# tests/test_remote_tunnels.sh - Testes de Túneis zrok v2 e Tailscale
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../test_framework.sh"

start_suite "Acesso Remoto Seguro" "Auditoria dos 6 túneis zrok v2 e VPN Tailscale"

test_tunnel() {
    local name="$1"
    local url="$2"
    local auth="${3:-}"
    
    local auth_opt=""
    [ -n "$auth" ] && auth_opt="-u $auth"
    
    local code
    code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 4 $auth_opt "$url" || echo "000")
    
    if [[ "$code" =~ ^(200|301|302|307|308|401)$ ]]; then
        assert_pass "Túnel ${name} online" "${url} (HTTP ${code})"
    else
        assert_fail "Túnel ${name} inacessível" "${url} (HTTP ${code})"
    fi
}

# 1. Túneis Públicos zrok v2
test_tunnel "Umbrel Dashboard" "https://umbrel-paulo.shares.zrok.io" ""
test_tunnel "Nextcloud Nuvem" "https://cloud-paulo.shares.zrok.io" ""
test_tunnel "Jellyfin Streaming" "https://jellyfin-paulo.shares.zrok.io" ""
test_tunnel "Sistema Karteman" "https://karteman-paulo.shares.zrok.io" ""
test_tunnel "Verifica Diários" "https://diarios-paulo.shares.zrok.io" "paulo:senha_oculta"
test_tunnel "Investimentos Pessoais" "https://investimentos-paulo.shares.zrok.io" "paulo:senha_oculta"

# 2. Conectividade Tailscale
if [ "$IS_LOCAL_HOST" = true ]; then
    if run_target_cmd "sudo docker exec tailscale_web_1 tailscale status" >/dev/null 2>&1; then
        assert_pass "Container Tailscale operacional no servidor" "tailscale_web_1"
    else
        assert_fail "Container Tailscale com falha" "tailscale_web_1"
    fi
else
    # Se estamos no Pop!_OS, verificamos se o IP do Tailscale responde (ou via container remoto se não tiver Tailscale local)
    if ping -c 2 -W 3 "100.88.159.41" >/dev/null 2>&1; then
        assert_pass "VPN Tailscale respondendo ao ping" "100.88.159.41"
    elif run_target_cmd "sudo docker exec tailscale_web_1 tailscale status" >/dev/null 2>&1; then
        assert_pass "VPN Tailscale ativa no servidor (verificado via container)" "100.88.159.41"
    else
        assert_fail "VPN Tailscale sem resposta" "100.88.159.41"
    fi
fi
