#!/usr/bin/env bash
# ==============================================================================
# tests/run_all.sh - Executor Unificado da Suíte de Testes (Homelab umbrelOS)
# ==============================================================================
# Estilo inspirado no executor unificado do Sistema Karteman.
# Executa testes de Armazenamento, Samba, Docker e HTTP com saída colorida.
#
# Uso:
#   ./tests/run_all.sh                  # Executa todas as suítes
#   ./tests/run_all.sh storage          # Executa apenas a suíte de storage
#   ./tests/run_all.sh samba            # Executa apenas a suíte de samba
#   ./tests/run_all.sh docker           # Executa apenas a suíte de docker
#   ./tests/run_all.sh http             # Executa apenas a suíte de http
# ==============================================================================

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${TESTS_DIR}/.." && pwd)"

source "${TESTS_DIR}/test_framework.sh"

echo -e "\n${BOLD}${WHITE}========================================================================${RESET}"
echo -e "${BOLD}${CYAN}🚀 SUÍTE DE TESTES E INTEGRIDADE — HOMELAB UMBRELOS${RESET}"
echo -e "${WHITE}Ambiente de Execução: ${BOLD}$( [ "$IS_LOCAL_HOST" = true ] && echo "HOST LOCAL (mini PC)" || echo "REMOTO (Pop!_OS → ${TARGET_HOST})" )${RESET}"
echo -e "${BOLD}${WHITE}========================================================================${RESET}"

MODULE="${1:-all}"

case "$MODULE" in
    storage)
        source "${TESTS_DIR}/test_storage_and_mounts.sh"
        ;;
    samba)
        source "${TESTS_DIR}/test_samba_services.sh"
        ;;
    docker)
        source "${TESTS_DIR}/test_docker_stacks.sh"
        ;;
    http)
        source "${TESTS_DIR}/test_http_endpoints.sh"
        ;;
    all)
        source "${TESTS_DIR}/test_storage_and_mounts.sh"
        source "${TESTS_DIR}/test_samba_services.sh"
        source "${TESTS_DIR}/test_docker_stacks.sh"
        source "${TESTS_DIR}/test_http_endpoints.sh"
        ;;
    *)
        echo -e "${RED}Módulo de teste desconhecido: ${MODULE}${RESET}"
        echo "Opções válidas: storage, samba, docker, http, all"
        exit 1
        ;;
esac

SUITE_END_TIME=$(date +%s%3N 2>/dev/null || date +%s)
DURATION=$((SUITE_END_TIME - SUITE_START_TIME))
# Formatação amigável do tempo
if [ "$DURATION" -gt 1000 ]; then
    DURATION_FMT="$(echo "scale=2; $DURATION / 1000" | bc 2>/dev/null || echo "$((DURATION / 1000))")s"
else
    DURATION_FMT="${DURATION}ms"
fi

TOTAL_TESTS=$((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))

echo -e "\n${BOLD}${WHITE}========================================================================${RESET}"
if [ "$TESTS_FAILED" -eq 0 ]; then
    echo -e "${BOLD}${GREEN}✔ SUCESSO: Todos os testes passaram!${RESET}"
else
    echo -e "${BOLD}${RED}✖ ATENÇÃO: Foram encontradas falhas nos testes!${RESET}"
fi
echo -e "Total: ${BOLD}${TOTAL_TESTS}${RESET} | ${GREEN}Passou: ${TESTS_PASSED}${RESET} | ${RED}Falhas: ${TESTS_FAILED}${RESET} | ${YELLOW}Ignorados: ${TESTS_SKIPPED}${RESET} | Tempo: ${DARK_GRAY}${DURATION_FMT}${RESET}"
echo -e "${BOLD}${WHITE}========================================================================${RESET}\n"

if [ "$TESTS_FAILED" -gt 0 ]; then
    exit 1
fi
exit 0
