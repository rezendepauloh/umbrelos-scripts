#!/usr/bin/env bash
# ==============================================================================
# tests/test_http_endpoints.sh - Testes de Portas e Endpoints HTTP
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test_framework.sh"

start_suite "Endpoints HTTP e Portas de Rede" "Validação de disponibilidade das aplicações web"

HOST_IP="${TARGET_HOST}"

assert_http_status "Dockge Web UI (:5001)" "http://${HOST_IP}:5001" "200"
assert_http_status "Dozzle Log Viewer (:8888)" "http://${HOST_IP}:8888" "200|307"
assert_http_status "qBittorrent Web UI (:8085)" "http://${HOST_IP}:8085" "200"
assert_http_status "Prowlarr Indexer Manager (:9696)" "http://${HOST_IP}:9696" "200|302"
assert_http_status "Sistema Karteman App (:8091)" "http://${HOST_IP}:8091" "200|302"
assert_http_status "Evolution API (:8092)" "http://${HOST_IP}:8092" "200"
assert_http_status "Verificador Diários Oficiais (:8093)" "http://${HOST_IP}:8093" "200"
assert_http_status "Paulo Investimentos Pessoais (:8094)" "http://${HOST_IP}:8094" "200"
assert_http_status "Jellyfin Media Server (:8096)" "http://${HOST_IP}:8096" "200|302"
assert_http_status "Nextcloud Hub (:8081)" "http://${HOST_IP}:8081" "200|302"
assert_http_status "Nginx Proxy Manager (:81)" "http://${HOST_IP}:81" "200"
assert_http_status "IT-Tools (:8080)" "http://${HOST_IP}:8080" "200"
assert_http_status "Syncthing (:8384)" "http://${HOST_IP}:8384" "200"
