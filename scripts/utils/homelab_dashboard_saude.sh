#!/usr/bin/env bash
# ==============================================================================
# scripts/utils/homelab_dashboard_saude.sh
# ------------------------------------------------------------------------------
# Dashboard visual executado no Pop!_OS para diagnóstico instantâneo do Mini PC:
# - Uptime, CPU, Memória RAM e Swap
# - Temperatura e Saúde SMART dos Discos (NVMe + 3 HDs Externos)
# - Horas de uso (Power-On Hours) de cada disco
# - Status de Armazenamento e Montagens
# - Saúde das Stacks Docker e alertas de quedas/desconexões USB
# ==============================================================================

set -euo pipefail

# Paleta de Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.env"
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

SERVER_HOST="${SERVER_HOST:-192.168.0.8}"
SERVER_USER="${SERVER_USER:-umbrel}"
SSH_KEY="${HOME}/.ssh/id_ed25519"

# clear removido para compatibilidade com execução sem TTY
echo -e "${BLUE}${BOLD}==============================================================================${NC}"
echo -e "${BLUE}${BOLD}           PAINEL DE SAÚDE E HARDWARE DO HOMELAB (Mini PC MP100 Pro)         ${NC}"
echo -e "${BLUE}${BOLD}==============================================================================${NC}"

# 1. Conexão SSH
echo -e "\n${CYAN}${BOLD}[1/5] Conectividade & Uptime do Servidor:${NC}"
if ! ssh -i "${SSH_KEY}" -o ConnectTimeout=3 -o BatchMode=yes "${SERVER_USER}@${SERVER_HOST}" "exit 0" 2>/dev/null; then
    echo -e "${RED}[!] ERRO: Servidor ${SERVER_HOST} inacessível via SSH.${NC}"
    exit 1
fi

ssh -i "${SSH_KEY}" "${SERVER_USER}@${SERVER_HOST}" 'bash -s' << 'EOF'
source /data/config.env 2>/dev/null || true

# Uptime e Carga
UPTIME_STR=$(uptime -p)
LOAD=$(cat /proc/loadavg | awk '{print $1, $2, $3}')
BOOT_TIME=$(who -b | awk '{print $3, $4}')

echo -e "  Tempo Ligado: \033[1;32m$UPTIME_STR\033[0m (Desde: $BOOT_TIME)"
echo -e "  Carga da CPU (1, 5, 15 min): \033[1;36m$LOAD\033[0m"

# Temperatura da CPU
TEMP_RAW=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo "0")
if [ "$TEMP_RAW" -gt 0 ]; then
    TEMP_C=$((TEMP_RAW / 1000))
    if [ "$TEMP_C" -lt 65 ]; then
        echo -e "  Temperatura CPU Intel: \033[1;32m${TEMP_C}°C (Saudável)\033[0m"
    elif [ "$TEMP_C" -lt 80 ]; then
        echo -e "  Temperatura CPU Intel: \033[1;33m${TEMP_C}°C (Atenção)\033[0m"
    else
        echo -e "  Temperatura CPU Intel: \033[1;31m${TEMP_C}°C (Alta!)\033[0m"
    fi
fi

# Memória RAM
MEM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
MEM_USED=$(free -m | awk '/Mem:/ {print $3}')
MEM_PERC=$((MEM_USED * 100 / MEM_TOTAL))
echo -e "  Memória RAM: \033[1;32m${MEM_USED} MB\033[0m / ${MEM_TOTAL} MB (${MEM_PERC}% em uso)"

EOF

# 2. Armazenamento Físico e Montagens
echo -e "\n${CYAN}${BOLD}[2/5] Armazenamento & Pontos de Montagem Nativos:${NC}"
ssh -i "${SSH_KEY}" "${SERVER_USER}@${SERVER_HOST}" 'bash -s' << 'EOF'
source /data/config.env 2>/dev/null || true

printf "  %-10s %-12s %-8s %-8s %-8s %-6s\n" "DISCO" "PAPEL" "TAM" "USADO" "LIVRE" "USO"
echo "  ------------------------------------------------------------"

check_mount() {
    local dev="$1"
    local papel="$2"
    local mnt="$3"
    if mountpoint -q "$mnt"; then
        local info=$(df -h "$mnt" | tail -n 1)
        local total=$(echo "$info" | awk '{print $2}')
        local used=$(echo "$info" | awk '{print $3}')
        local avail=$(echo "$info" | awk '{print $4}')
        local perc=$(echo "$info" | awk '{print $5}')
        printf "  \033[1;32m%-10s\033[0m %-12s %-8s %-8s %-8s %-6s\n" "$dev" "$papel" "$total" "$used" "$avail" "$perc"
    else
        printf "  \033[1;31m%-10s\033[0m %-12s \033[1;31m[NÃO MONTADO]\033[0m\n" "$dev" "$papel"
    fi
}

check_mount "NVMe" "umbrelOS/App" "/"
check_mount "disk1" "Midia/Torr" "/home/umbrel/umbrel/external/disk1"
check_mount "disk2" "Nuvem/Fotos" "/home/umbrel/umbrel/external/disk2"
check_mount "disk3" "Backups Loc" "/home/umbrel/umbrel/external/disk3"
EOF

# 3. Saúde SMART dos Discos (NVMe + HDs Externos)
echo -e "\n${CYAN}${BOLD}[3/5] Diagnóstico de Saúde SMART & Horas de Uso:${NC}"
ssh -i "${SSH_KEY}" "${SERVER_USER}@${SERVER_HOST}" 'bash -s' << 'EOF'
source /data/config.env 2>/dev/null || true

check_smart() {
    local dev="$1"
    local name="$2"
    local extra="${3:-}"

    if [ ! -b "$dev" ]; then
        echo -e "  $name ($dev): \033[1;31mDispositivo não encontrado\033[0m"
        return
    fi

    local smart_out
    smart_out=$(echo "$SYSTEM_PASSWORD" | sudo -S smartctl -H $extra "$dev" 2>/dev/null || true)
    local info_out
    info_out=$(echo "$SYSTEM_PASSWORD" | sudo -S smartctl -A $extra "$dev" 2>/dev/null || true)

    local health="DESCONHECIDO"
    if echo "$smart_out" | grep -qE "PASSED|OK"; then
        health="\033[1;32mPASSED (Saudável)\033[0m"
    elif echo "$smart_out" | grep -q "FAILED"; then
        health="\033[1;31mFAILED (Risco Crítico!)\033[0m"
    fi

    # Horas de uso e temperatura reais
    local hours=$(echo "$info_out" | grep -iE 'Power_On_Hours|Power On Hours' | awk '{print $10}' | tr -dc '0-9' || echo "")
    [ -z "$hours" ] && hours=$(echo "$info_out" | grep -iE 'Power_On_Hours|Power On Hours' | awk '{print $NF}' | tr -dc '0-9' || echo "")
    
    local temp=$(echo "$info_out" | grep -iE 'Temperature_Celsius' | awk '{print $10}' | tr -dc '0-9' || echo "")
    [ -z "$temp" ] && temp=$(echo "$info_out" | grep -iE 'Temperature:' | awk '{print $2}' | tr -dc '0-9' || echo "")

    local extra_info=""
    [ -n "$hours" ] && extra_info="Horas Ligado: ${hours}h"
    [ -n "$temp" ] && extra_info="$extra_info | Temp: ${temp}°C"

    echo -e "  $name ($dev): $health | $extra_info"
}

check_smart "/dev/nvme0n1" "SSD NVMe 1TB" ""

# Localizar dinamicamente os discos externos usando /sbin/blkid ou lsblk com sudo
DEV_DISK1=$(echo "$SYSTEM_PASSWORD" | sudo -S /sbin/blkid -U "${DISK1_UUID:-fc0b5d7b-1706-4461-9e1e-9d3f61e7bab0}" 2>/dev/null | sed 's/[0-9]*$//' || true)
DEV_DISK2=$(echo "$SYSTEM_PASSWORD" | sudo -S /sbin/blkid -U "${DISK2_UUID:-490440f1-8f2e-41fd-bc27-00632adec790}" 2>/dev/null | sed 's/[0-9]*$//' || true)
DEV_DISK3=$(echo "$SYSTEM_PASSWORD" | sudo -S /sbin/blkid -U "${DISK3_UUID:-e106affb-35da-4e93-a92d-e1ef5df32bb5}" 2>/dev/null | sed 's/[0-9]*$//' || true)

check_smart "$DEV_DISK1" "disk1 (Seagate 1TB)" "-d scsi"
check_smart "$DEV_DISK2" "disk2 (A-DATA 1TB)" "-d sat"
check_smart "$DEV_DISK3" "disk3 (Samsung 1TB)" "-d sat"
EOF

# 4. Status de Segurança e Quedas USB
echo -e "\n${CYAN}${BOLD}[4/5] Análise de Integridade de Barramento (Quedas USB Recentes):${NC}"
ssh -i "${SSH_KEY}" "${SERVER_USER}@${SERVER_HOST}" 'bash -s' << 'EOF'
source /data/config.env 2>/dev/null || true
USB_ERRORS=$(echo "$SYSTEM_PASSWORD" | sudo -S dmesg | grep -iE 'USB disconnect' | tail -n 3 || true)
if [ -n "$USB_ERRORS" ]; then
    echo -e "  \033[1;33m[!] Atenção: Foram detectados eventos de desconexão USB no histórico do boot:\033[0m"
    echo "$USB_ERRORS" | sed 's/^/      /'
    echo -e "  \033[1;36mDica: Se algum HD estiver inacessível, execute: ./scripts/utils/recuperar_hds_remoto.sh\033[0m"
else
    echo -e "  \033[1;32m[✔] Barramento USB 100% estável (Nenhum evento de desconexão).\033[0m"
fi
EOF

# 5. Status Rápido dos Containers Docker
echo -e "\n${CYAN}${BOLD}[5/5] Resumo dos Containers Docker:${NC}"
ssh -i "${SSH_KEY}" "${SERVER_USER}@${SERVER_HOST}" 'bash -s' << 'EOF'
source /data/config.env 2>/dev/null || true
TOTAL=$(echo "$SYSTEM_PASSWORD" | sudo -S docker ps -q 2>/dev/null | wc -l)
RESTARTING=$(echo "$SYSTEM_PASSWORD" | sudo -S docker ps -f status=restarting -q 2>/dev/null | wc -l)
DEAD=$(echo "$SYSTEM_PASSWORD" | sudo -S docker ps -f status=dead -q 2>/dev/null | wc -l)

echo -e "  Containers Ativos e Rodando: \033[1;32m${TOTAL}\033[0m"
if [ "$RESTARTING" -gt 0 ] || [ "$DEAD" -gt 0 ]; then
    echo -e "  \033[1;31m[!] Alerta: Existem containers travados (Restarting: $RESTARTING, Dead: $DEAD)\033[0m"
else
    echo -e "  \033[1;32m[✔] Nenhum container em falha ou looping de reinicialização.\033[0m"
fi
EOF

echo -e "\n${BLUE}${BOLD}==============================================================================${NC}"
echo -e "${GREEN}${BOLD} Diagnóstico concluído com sucesso!${NC}"
echo -e "${BLUE}${BOLD}==============================================================================${NC}\n"
