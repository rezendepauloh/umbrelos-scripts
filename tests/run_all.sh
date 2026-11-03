#!/usr/bin/env bash
# ==============================================================================
# tests/run_all.sh - Orquestrador Geral de Testes (Bash & Python)
# Suporta:
#   ./tests/run_all.sh               -> Roda tudo (Unitários locais + Integração remota)
#   ./tests/run_all.sh --unit        -> Roda apenas testes unitários locais (sintaxe, YAML, configs)
#   ./tests/run_all.sh --integration -> Roda apenas testes de integração no servidor
#   ./tests/run_all.sh --bash        -> Roda suíte clássica puramente em Bash
# ==============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Se Python 3 estiver disponível e não for forçado modo --bash, usamos o runner moderno
if command -v python3 >/dev/null 2>&1 && [ "${1:-}" != "--bash" ]; then
    exec python3 "${SCRIPT_DIR}/run_all.py" "$@"
fi

# Fallback: Modo puramente Bash
source "${SCRIPT_DIR}/test_framework.sh"

echo -e "${BOLD}${CYAN}========================================================================${RESET}"
echo -e "${BOLD}${WHITE}🚀 SUÍTE DE TESTES E INTEGRIDADE — HOMELAB UMBRELOS (BASH RUNNER)${RESET}"
if [ "$IS_LOCAL_HOST" = true ]; then
    echo -e "${BOLD}${WHITE}Ambiente de Execução:${RESET} ${GREEN}LOCAL (Direto no Servidor Umbrel)${RESET}"
else
    echo -e "${BOLD}${WHITE}Ambiente de Execução:${RESET} ${YELLOW}REMOTO (Pop!_OS → ${TARGET_HOST})${RESET}"
fi
echo -e "${BOLD}${CYAN}========================================================================${RESET}"

export TESTS_PASSED=0
export TESTS_FAILED=0
export TESTS_SKIPPED=0

run_subsuite() {
    local script_file="$1"
    if [ -f "${SCRIPT_DIR}/integration/${script_file}" ]; then
        bash "${SCRIPT_DIR}/integration/${script_file}"
    elif [ -f "${SCRIPT_DIR}/${script_file}" ]; then
        bash "${SCRIPT_DIR}/${script_file}"
    fi
}

run_subsuite "test_storage_and_mounts.sh"
run_subsuite "test_samba_services.sh"
run_subsuite "test_docker_stacks.sh"
run_subsuite "test_http_endpoints.sh"
run_subsuite "test_remote_tunnels.sh"

TOTAL_TESTS=$((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))

echo -e "\n${BOLD}${CYAN}========================================================================${RESET}"
if [ "$TESTS_FAILED" -eq 0 ]; then
    echo -e "${BOLD}${GREEN}✔ SUCESSO: Todos os testes passaram!${RESET}"
else
    echo -e "${BOLD}${RED}✖ ATENÇÃO: Foram encontradas falhas nos testes!${RESET}"
fi
echo -e "Total: ${BOLD}${TOTAL_TESTS}${RESET} | Passou: ${GREEN}${TESTS_PASSED}${RESET} | Falhas: ${RED}${TESTS_FAILED}${RESET} | Ignorados: ${YELLOW}${TESTS_SKIPPED}${RESET}"
echo -e "${BOLD}${CYAN}========================================================================${RESET}\n"

if [ "$TESTS_FAILED" -gt 0 ]; then
    exit 1
fi
exit 0
