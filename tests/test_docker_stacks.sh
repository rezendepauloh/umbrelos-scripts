#!/usr/bin/env bash
# ==============================================================================
# tests/test_docker_stacks.sh - Testes de Containers e Stacks Customizadas
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test_framework.sh"

start_suite "Containers e Stacks Docker" "Validação de integridade dos 40+ containers"

# 1. Checar rede Docker compartilhada homelab_network
assert_cmd_success "Rede compartilhada homelab_network" "sudo docker network inspect homelab_network" "presente"

# 2. Validar containers essenciais do sistema
check_container() {
    local c_name="$1"
    local desc="$2"
    local status
    status=$(run_target_cmd "sudo docker inspect --format '{{.State.Status}}' $c_name 2>/dev/null || echo 'not_found'")
    if [ "$status" = "running" ]; then
        assert_pass "Container ${c_name}" "${desc} - running"
    else
        assert_fail "Container ${c_name} não está em execução" "Status: ${status}"
    fi
}

check_container "dockge" "Gerenciador de Stacks"
check_container "dozzle" "Visualizador de Logs"
check_container "uptime-kuma" "Monitoramento de Uptime"
check_container "qbittorrent" "Cliente BitTorrent"
check_container "prowlarr" "Gerenciador de Indexadores"
check_container "jackett" "Proxy de Indexadores"
check_container "radarr" "Gerenciador de Filmes"
check_container "sonarr" "Gerenciador de Séries"
check_container "jellyseerr" "Solicitações de Mídia"
check_container "bazarr" "Gerenciador de Legendas"
check_container "karteman-app" "Sistema Karteman App"
check_container "karteman-evolution-api" "Evolution API WhatsApp"
check_container "betor-api" "Buscador Nacional BeTor"
check_container "betor-scrapyd" "Crawler BeTor"
check_container "verifica-diarios-app" "Verificador Diários Oficiais"
check_container "paulo-investimentos-app" "Investimentos Pessoais"
check_container "jellyfin_server_1" "Jellyfin Media Server"
check_container "nextcloud_web_1" "Nextcloud Hub"
check_container "immich_server_1" "Immich Photo Backup"
check_container "home-assistant_server_1" "Home Assistant Server"
check_container "tailscale_web_1" "Tailscale VPN Server"
check_container "adguard-home_server_1" "AdGuard Home DNS"
