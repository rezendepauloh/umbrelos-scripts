#!/usr/bin/env bash
# ==============================================================================
# tests/test_framework.sh - Framework de Testes em Bash (Estilo Karteman)
# ==============================================================================

# Cores e Formatação ANSI
RESET="\033[0m"
BOLD="\033[1m"
GREEN="\033[32m"
RED="\033[31m"
YELLOW="\033[33m"
CYAN="\033[36m"
WHITE="\033[37m"
DARK_GRAY="\033[90m"

TESTS_PASSED=${TESTS_PASSED:-0}
TESTS_FAILED=${TESTS_FAILED:-0}
TESTS_SKIPPED=${TESTS_SKIPPED:-0}
SUITE_START_TIME=${SUITE_START_TIME:-$(date +%s%3N 2>/dev/null || date +%s)}

# Detectar se estamos rodando localmente no Pop!_OS ou dentro do próprio Umbrel
TARGET_HOST="${TARGET_HOST:-192.168.0.8}"
SSH_USER="${SSH_USER:-umbrel}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519}"

IS_LOCAL_HOST=false
if [[ "$(hostname 2>/dev/null)" == "umbrel" ]] || [[ -f "/data/umbrel-os" ]] || [[ -f "/data/bin/homelab-daemon.sh" ]]; then
    IS_LOCAL_HOST=true
fi

# Executa comando no destino (local ou remoto via SSH)
run_target_cmd() {
    local cmd="$1"
    if [ "$IS_LOCAL_HOST" = true ]; then
        eval "$cmd"
    else
        ssh -i "$SSH_KEY" -o ConnectTimeout=5 -o StrictHostKeyChecking=no "${SSH_USER}@${TARGET_HOST}" "$cmd"
    fi
}

start_suite() {
    local suite_name="$1"
    local suite_desc="$2"
    echo -e "\n${CYAN}▶ Executando Suíte: ${BOLD}${suite_name}${RESET} ${DARK_GRAY}(${suite_desc})${RESET}"
}

assert_pass() {
    local test_name="$1"
    local detail="${2:-}"
    ((TESTS_PASSED++))
    if [ -n "$detail" ]; then
        echo -e " ${GREEN}✔ PASS${RESET} ${test_name} ${DARK_GRAY}(${detail})${RESET}"
    else
        echo -e " ${GREEN}✔ PASS${RESET} ${test_name}"
    fi
}

assert_fail() {
    local test_name="$1"
    local reason="${2:-Erro desconhecido}"
    ((TESTS_FAILED++))
    echo -e " ${RED}✖ FAIL${RESET} ${BOLD}${test_name}${RESET} → ${YELLOW}${reason}${RESET}"
}

assert_skip() {
    local test_name="$1"
    local reason="${2:-Ignorado}"
    ((TESTS_SKIPPED++))
    echo -e " ${YELLOW}⚡ SKIP${RESET} ${DARK_GRAY}${test_name} (${reason})${RESET}"
}

# Asserção de código de retorno 0
assert_cmd_success() {
    local test_name="$1"
    local cmd="$2"
    local detail="${3:-}"

    if run_target_cmd "$cmd" >/dev/null 2>&1; then
        assert_pass "$test_name" "$detail"
        return 0
    else
        assert_fail "$test_name" "Comando falhou: $cmd"
        return 1
    fi
}

# Asserção de resposta HTTP
assert_http_status() {
    local test_name="$1"
    local url="$2"
    local expected_pattern="${3:-200|301|302|307}"

    local actual_code
    actual_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 4 -m 6 "$url" 2>/dev/null || echo "000")

    if [[ "$actual_code" =~ ^($expected_pattern)$ ]]; then
        assert_pass "$test_name" "HTTP $actual_code"
        return 0
    else
        assert_fail "$test_name" "Esperado HTTP $expected_pattern, recebido HTTP $actual_code ($url)"
        return 1
    fi
}
