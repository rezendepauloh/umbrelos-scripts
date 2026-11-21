#!/usr/bin/env bash
# ==============================================================================
# scripts/utils/homelab_betor_sync.sh
# ------------------------------------------------------------------------------
# Verifica remotamente (via SSH no Mini PC) se o timer systemd do BeTor
# (`homelab-betor-sync.timer`) está ativo e rodou corretamente.
# Com a flag `--run`, dispara a sincronização manualmente na hora.
#
# Uso (no Pop!_OS):
#   ./scripts/utils/homelab_betor_sync.sh         # Verifica status em tabela
#   ./scripts/utils/homelab_betor_sync.sh --run   # Dispara a raspagem manualmente
# ==============================================================================
set -euo pipefail

RUN_NOW=false
RESCHEDULE=false
for arg in "$@"; do
    case "$arg" in
        --run) RUN_NOW=true ;;
        --reschedule) RESCHEDULE=true ;;
        -h|--help)
            echo "Uso: $0 [--run | --reschedule]"
            echo "  (sem flags)   Verifica o status do timer e da última raspagem do BeTor"
            echo "  --run         Executa a raspagem agora mesmo (sem alterar o agendamento do timer)"
            echo "  --reschedule  Dispara via systemd e reagenda o próximo ciclo de 6h a partir de agora"
            exit 0
            ;;
        *)
            echo "❌ Opção desconhecida: $arg" >&2
            exit 1
            ;;
    esac
done

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
RESET='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ENV_FILE="${REPO_ROOT}/config.env"

if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}❌ Erro: config.env não encontrado em $ENV_FILE${RESET}" >&2
    exit 1
fi

# shellcheck disable=SC1090
source "$ENV_FILE"

if [ -z "${SYSTEM_PASSWORD:-}" ]; then
    echo -e "${RED}❌ Erro: SYSTEM_PASSWORD não definida em $ENV_FILE${RESET}" >&2
    exit 1
fi

SERVER_HOST="${UMBREL_HOST:-192.168.0.8}"
SERVER_USER="${UMBREL_USER:-umbrel}"

if [ "$RUN_NOW" = true ]; then
    echo -e "\n${CYAN}🚀 Executando raspagem do BeTor agora em ${BOLD}${SERVER_HOST}${RESET}${CYAN} (sem alterar o timer)...${RESET}"
    out=$(ssh "${SERVER_USER}@${SERVER_HOST}" "echo '${SYSTEM_PASSWORD}' | sudo -S docker exec prowlarr curl -s -X POST -H 'Content-Type: application/json' -d '{\"deep\": 1}' http://betor-api:8000/v1/scrape/" 2>/dev/null || true)
    ok_count=$(echo "$out" | grep -o '"status":"ok"' | wc -l || true)
    if [ "$ok_count" -gt 0 ]; then
        echo -e "${GREEN}✔ Raspagem iniciada com sucesso (${BOLD}${ok_count} spiders${RESET}${GREEN} agendadas no Scrapyd)!${RESET}\n"
    else
        echo -e "${YELLOW}⚠ Resposta inesperada do BeTor. Verifique se o container betor-api está rodando.${RESET}\n"
    fi
    exit 0
fi

if [ "$RESCHEDULE" = true ]; then
    echo -e "\n${CYAN}🔄 Reagendando ciclo de 6h do BeTor em ${BOLD}${SERVER_HOST}${RESET}${CYAN}...${RESET}"
    out=$(ssh "${SERVER_USER}@${SERVER_HOST}" "echo '${SYSTEM_PASSWORD}' | sudo -S bash -c 'systemctl start homelab-betor-sync.service && journalctl -u homelab-betor-sync.service -n 5 --no-pager'" 2>/dev/null || true)
    ok_count=$(echo "$out" | grep -o '"status":"ok"' | wc -l || true)
    if [ "$ok_count" -gt 0 ]; then
        echo -e "${GREEN}✔ Executado e reagendado para daqui a 6h (${BOLD}${ok_count} spiders${RESET}${GREEN} agendadas)!${RESET}\n"
    else
        echo -e "${YELLOW}⚠ Serviço executado. Verifique o status com ./scripts/utils/homelab_betor_sync.sh${RESET}\n"
    fi
    exit 0
fi

raw=$(ssh "${SERVER_USER}@${SERVER_HOST}" "echo '${SYSTEM_PASSWORD}' | sudo -S bash -c '
    active=\$(systemctl is-active homelab-betor-sync.timer 2>/dev/null || echo inactive)
    last=\$(systemctl show homelab-betor-sync.service -p ExecMainStartTimestamp --value 2>/dev/null || echo \"-\")
    next=\$(systemctl list-timers homelab-betor-sync.timer --no-pager --no-legend 2>/dev/null | awk \"{print \\\$1, \\\$2, \\\$3}\" || echo \"-\")
    result=\$(systemctl show homelab-betor-sync.service -p Result --value 2>/dev/null || echo \"-\")
    ok_count=\$(journalctl -u homelab-betor-sync.service -n 5 --no-pager 2>/dev/null | grep -o \"\\\"status\\\":\\\"ok\\\"\" | wc -l || echo 0)
    echo \"\${active}|\${last}|\${next}|\${result}|\${ok_count}\"
'" 2>/dev/null)

IFS='|' read -r t_active t_last t_next s_result ok_count <<< "$raw"

fmt_pt_date() {
    local raw_d="$1"
    [ -z "$raw_d" ] || [ "$raw_d" = "-" ] && echo "-" && return
    local en_d
    en_d=$(date -d "$raw_d" "+%a %d/%m/%Y %H:%M:%S" 2>/dev/null || echo "$raw_d")
    echo "$en_d" | sed -e 's/^Sun/Dom/' -e 's/^Mon/Seg/' -e 's/^Tue/Ter/' -e 's/^Wed/Qua/' -e 's/^Thu/Qui/' -e 's/^Fri/Sex/' -e 's/^Sat/Sab/'
}

t_last_fmt=$(fmt_pt_date "$t_last")
t_next_fmt=$(fmt_pt_date "$t_next")

if [ "$t_active" = "active" ]; then
    timer_txt="● Ativo"
    timer_str="${GREEN}${timer_txt}${RESET}"
else
    timer_txt="✖ Inativo"
    timer_str="${RED}${timer_txt}${RESET}"
fi

if [ "$s_result" = "success" ] && [ "${ok_count:-0}" -gt 0 ]; then
    res_txt="✔ OK (${ok_count} spiders)"
    res_str="${GREEN}${res_txt}${RESET}"
elif [ "$s_result" = "success" ]; then
    res_txt="✔ OK"
    res_str="${GREEN}${res_txt}${RESET}"
else
    res_txt="✖ ${s_result}"
    res_str="${RED}${res_txt}${RESET}"
fi

print_row() {
    local label="$1"
    local val_colored="$2"
    local val_plain="$3"
    local l_len=${#label}
    local v_len=${#val_plain}
    local l_pad=$((20 - l_len))
    local v_pad=$((40 - v_len))
    [ $l_pad -lt 0 ] && l_pad=0
    [ $v_pad -lt 0 ] && v_pad=0
    printf "${CYAN}│${RESET} %s%*s ${CYAN}│${RESET} %b%*s ${CYAN}│${RESET}\n" "$label" "$l_pad" "" "$val_colored" "$v_pad" ""
}

echo ""
echo -e "${CYAN}┌──────────────────────┬──────────────────────────────────────────┐${RESET}"
echo -e "${CYAN}│ ${BOLD}BETOR SYNC (6h)${RESET}${CYAN}      │ ${BOLD}STATUS ATUAL${RESET}${CYAN}                             │${RESET}"
echo -e "${CYAN}├──────────────────────┼──────────────────────────────────────────┤${RESET}"
print_row "Timer systemd"    "$timer_str"  "$timer_txt"
print_row "Última execução"  "$t_last_fmt" "$t_last_fmt"
print_row "Próxima execução" "$t_next_fmt" "$t_next_fmt"
print_row "Último resultado" "$res_str"    "$res_txt"
echo -e "${CYAN}└──────────────────────┴──────────────────────────────────────────┘${RESET}"
echo ""
