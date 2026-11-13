#!/usr/bin/env bash
# ==============================================================================
# tests/test_remote_tunnels.sh - Testes de Túneis zrok v2 e Tailscale
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../test_framework.sh"

start_suite "Acesso Remoto Seguro" "Auditoria dos 5 túneis zrok v2, blindagem Basic Auth e VPN Tailscale"

test_tunnel() {
    local name="$1"
    local url="$2"
    local auth="${3:-}"
    local expected="${4:-200|301|302|307|308}"
    
    local auth_opt=""
    [ -n "$auth" ] && auth_opt="-u $auth"
    
    local code
    code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 4 $auth_opt "$url" || echo "000")
    
    if [[ "$code" =~ ^(${expected})$ ]]; then
        assert_pass "Túnel ${name}" "${url} (HTTP ${code})"
    else
        assert_fail "Túnel ${name} fora do padrão esperado (${expected})" "${url} (HTTP ${code})"
    fi
}

# 1. Túneis Públicos zrok v2 e Blindagem de Segurança
AUTH_PAULO=""
[ -n "${SYSTEM_PASSWORD:-}" ] && AUTH_PAULO="${SAMBA_USER_1:-paulo}:${SYSTEM_PASSWORD}"

AUTH_KAMILA=""
[ -n "${KAMILA_PASSWORD:-}" ] && AUTH_KAMILA="${SAMBA_USER_2:-kamila}:${KAMILA_PASSWORD}"

# Garantir que o painel administrativo umbrelOS NÃO está exposto publicamente no zrok
test_tunnel "Umbrel Dashboard Bloqueado na Internet (Segurança)" "https://umbrel-paulo.shares.zrok.io" "" "404|000"

# Garantir que os túneis protegidos exigem Basic Auth (retornam 401 sem credenciais)
test_tunnel "Verifica Diários (Bloqueio Anônimo 401)" "https://diarios-paulo.shares.zrok.io" "" "401"
test_tunnel "Investimentos Pessoais (Bloqueio Anônimo 401)" "https://investimentos-paulo.shares.zrok.io" "" "401"

test_tunnel "Nextcloud Nuvem online" "https://cloud-paulo.shares.zrok.io" ""
test_tunnel "Jellyfin Streaming online" "https://jellyfin-paulo.shares.zrok.io" ""
test_tunnel "Sistema Karteman online" "https://karteman-paulo.shares.zrok.io" ""
test_tunnel "Verifica Diários (Paulo) autenticado" "https://diarios-paulo.shares.zrok.io" "$AUTH_PAULO" "200|301|302|307|308"
test_tunnel "Verifica Diários (Kamila) autenticado" "https://diarios-paulo.shares.zrok.io" "$AUTH_KAMILA" "200|301|302|308"
test_tunnel "Investimentos Pessoais (Paulo) autenticado" "https://investimentos-paulo.shares.zrok.io" "$AUTH_PAULO" "200|301|302|307|308"
test_tunnel "Investimentos Pessoais (Kamila) autenticado" "https://investimentos-paulo.shares.zrok.io" "$AUTH_KAMILA" "200|301|302|307|308"

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
