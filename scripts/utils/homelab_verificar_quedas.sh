#!/usr/bin/env bash
# ==============================================================================
# scripts/utils/homelab_verificar_quedas.sh
# ------------------------------------------------------------------------------
# Analisador Inteligente de Serviços Caídos, Gargalos e Erros no Homelab umbrelOS.
# Detecta:
# 1. Erros silenciosos de I/O de disco (EIO), desconexões USB e montagens fantasmas.
# 2. Containers em loop de reinício (Restarting), mortos (Exited!=0) ou OOMKilled.
# 3. Serviços web com falha (502 Bad Gateway, 503, 504 Gateway Timeout, Connection Refused).
# 4. Logs recentes de erro dos containers afetados com sugestão imediata de correção.
# ==============================================================================

set -euo pipefail

# Cores e Formatação
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.env"
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

SERVER_HOST="${SERVER_HOST:-192.168.0.8}"
SERVER_USER="${SERVER_USER:-umbrel}"
SSH_KEY="${HOME}/.ssh/id_ed25519"

echo -e "${BLUE}${BOLD}==============================================================================${NC}"
echo -e "${BLUE}${BOLD}   DIAGNÓSTICO E ANÁLISE DE QUEDAS DE SERVIÇOS (Pop!_OS -> Mini PC)           ${NC}"
echo -e "${BLUE}${BOLD}==============================================================================${NC}"

# Detectar se está rodando localmente no Mini PC ou via SSH do Pop!_OS
IS_LOCAL=false
if [[ "$(hostname 2>/dev/null)" == "umbrel" ]] || [[ -f "/data/umbrel-os" ]]; then
    IS_LOCAL=true
fi

if [ "$IS_LOCAL" = false ]; then
    echo -e "${CYAN}ℹ Verificando conectividade SSH com ${SERVER_USER}@${SERVER_HOST}...${NC}"
    if ! ssh -i "${SSH_KEY}" -o ConnectTimeout=4 -o BatchMode=yes "${SERVER_USER}@${SERVER_HOST}" "exit 0" 2>/dev/null; then
        echo -e "${RED}[!] ERRO: Mini PC ${SERVER_HOST} inacessível via SSH.${NC}"
        echo -e "    Verifique se o cabo de rede está conectado ou se o mini PC está ligado."
        exit 1
    fi
    echo -e "${GREEN}[✔] Conexão SSH estabelecida com sucesso!${NC}\n"
fi

# Bloco de execução (remoto ou local)
run_audit() {
    bash -s << 'REMOTESCRIPT'
set -u

source /data/config.env 2>/dev/null || true

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

FAILURES_COUNT=0
declare -a FAILED_SERVICES=()

# ------------------------------------------------------------------------------
# 1. Auditoria de Armazenamento e Erros de I/O (Ghost Mounts / Desconexão USB)
# ------------------------------------------------------------------------------
echo -e "${BLUE}${BOLD}[1/4] Auditoria de Discos Físicos e I/O de Armazenamento:${NC}"

# Verificar integridade dos pontos de montagem essenciais
CHECK_PATHS=(
    "/home/umbrel/umbrel/external/disk1:HD1 Mídia (Seagate)"
    "/home/umbrel/umbrel/external/disk2:HD2 Nuvem & Fotos (A-DATA)"
    "/home/umbrel/umbrel/external/disk3:HD3 Backups (Samsung)"
    "/home/umbrel/umbrel/home/Downloads/media:Bind Mount Jellyfin"
    "/home/umbrel/umbrel/app-data/immich/data/upload:Bind Mount Immich Fotos"
)

IO_ERROR_DETECTED=false

for item in "${CHECK_PATHS[@]}"; do
    path="${item%%:*}"
    desc="${item#*:}"

    if [ ! -d "$path" ]; then
        echo -e "  ${YELLOW}⚠ [AUSENTE]${NC} ${desc} (${path})"
        continue
    fi

    # Teste de leitura com timeout de 10s (permite spin-up de HDs mecânicos em repouso)
    if timeout 10 ls -la "$path" >/dev/null 2>&1; then
        echo -e "  ${GREEN}✔ [OK]${NC} ${desc}: Leitura e I/O íntegros"
    else
        echo -e "  ${RED}✖ [FALHA CRÍTICA - EIO]${NC} ${desc}: Erro de leitura/I/O em ${path}"
        IO_ERROR_DETECTED=true
        FAILURES_COUNT=$((FAILURES_COUNT + 1))
        FAILED_SERVICES+=("armazenamento_${path}")
    fi
done

# Checar se há montagens apontando para dispositivos que já re-enumeraram no barramento USB
echo -e "\n  ${CYAN}Verificando correspondência entre /proc/mounts e discos ativos no barramento...${NC}"
MOUNTED_SD_DEVS=$(grep -oE '/dev/sd[a-z][0-9]' /proc/mounts | sort -u || true)
REAL_BLOCK_DEVS=$(lsblk -rn -o NAME | grep -E '^sd[a-z][0-9]' | sed 's|^|/dev/|' | sort -u || true)

GHOST_MOUNTS=false
for mdev in $MOUNTED_SD_DEVS; do
    if ! echo "$REAL_BLOCK_DEVS" | grep -qx "$mdev"; then
        echo -e "  ${RED}✖ [MONTAGEM ZUMBI DETECTADA]${NC} ${mdev} está montado mas não existe mais no lsblk!"
        echo -e "    O disco reconectou com outra letra de dispositivo. Remontagem necessária."
        GHOST_MOUNTS=true
        IO_ERROR_DETECTED=true
        FAILURES_COUNT=$((FAILURES_COUNT + 1))
    fi
done

if [ "$GHOST_MOUNTS" = false ] && [ "$IO_ERROR_DETECTED" = false ]; then
    echo -e "  ${GREEN}✔ [OK] Nenhuma anomalia de I/O ou montagem fantasma detectada.${NC}"
fi

# ------------------------------------------------------------------------------
# 2. Auditoria de Containers Docker (Loopings, OOMKilled e Status)
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}${BOLD}[2/4] Auditoria de Containers Docker (Crash Loops & OOM):${NC}"

ALL_CONTAINERS=$(docker ps -a --format '{{.Names}}|{{.Status}}|{{.State}}' 2>/dev/null || true)

CONTAINER_ISSUES=0

while IFS='|' read -r c_name c_status c_state; do
    [ -z "$c_name" ] && continue

    # Checar se container está em looping de reinício
    if echo "$c_status" | grep -qi "Restarting"; then
        echo -e "  ${RED}✖ [RESTART LOOP]${NC} Container ${BOLD}${c_name}${NC} está em reinício contínuo! (${c_status})"
        CONTAINER_ISSUES=$((CONTAINER_ISSUES + 1))
        FAILURES_COUNT=$((FAILURES_COUNT + 1))
        FAILED_SERVICES+=("container_${c_name}")
    fi

    # Checar se container morreu com exit code de erro (diferente de 0)
    if [ "$c_state" = "exited" ]; then
        exit_code=$(docker inspect --format '{{.State.ExitCode}}' "$c_name" 2>/dev/null || echo "0")
        if [ "$exit_code" -ne 0 ]; then
            echo -e "  ${RED}✖ [DEAD / EXIT ERROR]${NC} Container ${BOLD}${c_name}${NC} finalizou com erro (Código: ${exit_code})"
            CONTAINER_ISSUES=$((CONTAINER_ISSUES + 1))
            FAILURES_COUNT=$((FAILURES_COUNT + 1))
            FAILED_SERVICES+=("container_${c_name}")
        fi
    fi

    # Checar se container foi abatido por OOM (Out Of Memory Kill pelo Linux)
    oom_killed=$(docker inspect --format '{{.State.OOMKilled}}' "$c_name" 2>/dev/null || echo "false")
    if [ "$oom_killed" = "true" ]; then
        echo -e "  ${RED}✖ [OOM KILLED]${NC} Container ${BOLD}${c_name}${NC} foi morto por falta de memória RAM (Out of Memory)!"
        CONTAINER_ISSUES=$((CONTAINER_ISSUES + 1))
        FAILURES_COUNT=$((FAILURES_COUNT + 1))
        FAILED_SERVICES+=("container_${c_name}")
    fi

    # Checar healthcheck se houver
    health_status=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{end}}' "$c_name" 2>/dev/null || true)
    if [ "$health_status" = "unhealthy" ]; then
        echo -e "  ${RED}✖ [UNHEALTHY]${NC} Container ${BOLD}${c_name}${NC} falhou na checagem de saúde interna."
        CONTAINER_ISSUES=$((CONTAINER_ISSUES + 1))
        FAILURES_COUNT=$((FAILURES_COUNT + 1))
        FAILED_SERVICES+=("container_${c_name}")
    fi
done <<< "$ALL_CONTAINERS"

if [ "$CONTAINER_ISSUES" -eq 0 ]; then
    echo -e "  ${GREEN}✔ [OK] Todos os containers estão ativos sem crashes ou OOM kills.${NC}"
fi

# ------------------------------------------------------------------------------
# 3. Auditoria Ativa de Endpoints HTTP (Detecção de 502 Bad Gateway / Portas Mortas)
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}${BOLD}[3/4] Auditoria Ativa de Endpoints HTTP & Web UIs:${NC}"

# Lista de serviços: Nome | URL de Teste | Tipo
HTTP_CHECKS=(
    "Immich (Gateway Umbrel)|http://127.0.0.1/open-app/immich|gateway"
    "Immich (Container Direto)|http://immich_server_1:2283|container"
    "Nextcloud Hub|http://127.0.0.1:8081|app"
    "Jellyfin Media Server|http://127.0.0.1:8096|app"
    "Home Assistant|http://127.0.0.1:8123|app"
    "AdGuard Home DNS|http://127.0.0.1:8095|app"
    "Nginx Proxy Manager Admin|http://127.0.0.1:81|app"
    "Dockge Stacks|http://127.0.0.1:5001|app"
    "Dozzle Logs Viewer|http://127.0.0.1:8888|app"
    "qBittorrent WebUI|http://127.0.0.1:8085|app"
    "Radarr Filmes|http://127.0.0.1:7878|app"
    "Sonarr Séries|http://127.0.0.1:8989|app"
    "Prowlarr Indexers|http://127.0.0.1:9696|app"
    "Jellyseerr Requests|http://127.0.0.1:5055|app"
    "Bazarr Legendas|http://127.0.0.1:6767|app"
    "IT-Tools Developer|http://127.0.0.1:8080|app"
    "Syncthing Sync|http://127.0.0.1:8384|app"
    "BeTor API Local|http://127.0.0.1:8005/v1/items/|app"
    "Karteman App|http://127.0.0.1:8081|custom"
    "Verifica Diários App|http://127.0.0.1:8093|custom"
    "Investimentos Pessoais App|http://127.0.0.1:8094|custom"
)

HTTP_FAILURES=0

for entry in "${HTTP_CHECKS[@]}"; do
    svc_name="${entry%%|*}"
    rest="${entry#*|}"
    url="${rest%%|*}"
    tipo="${rest#*|}"

    # Para container direto do immich, usa a API interna do próprio container
    if [ "$tipo" = "container" ]; then
        code=$(docker exec immich_server_1 curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 http://localhost:2283/api/server/version 2>/dev/null || echo "000")
    else
        code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 2 "$url" 2>/dev/null || echo "000")
    fi

    case "$code" in
        200|201|204|301|302|307|308|401|403)
            echo -e "  ${GREEN}✔ [ONLINE - HTTP ${code}]${NC} ${svc_name}"
            ;;
        502)
            echo -e "  ${RED}✖ [502 BAD GATEWAY]${NC} ${svc_name} (${url}) -> Container caiu ou travou atrás do proxy!"
            HTTP_FAILURES=$((HTTP_FAILURES + 1))
            FAILURES_COUNT=$((FAILURES_COUNT + 1))
            FAILED_SERVICES+=("http_${svc_name}")
            ;;
        503|504)
            echo -e "  ${RED}✖ [HTTP ${code} GATEWAY ERROR]${NC} ${svc_name} (${url})"
            HTTP_FAILURES=$((HTTP_FAILURES + 1))
            FAILURES_COUNT=$((FAILURES_COUNT + 1))
            FAILED_SERVICES+=("http_${svc_name}")
            ;;
        500)
            echo -e "  ${RED}✖ [500 INTERNAL SERVER ERROR]${NC} ${svc_name} (${url})"
            HTTP_FAILURES=$((HTTP_FAILURES + 1))
            FAILURES_COUNT=$((FAILURES_COUNT + 1))
            FAILED_SERVICES+=("http_${svc_name}")
            ;;
        000)
            # Serviços customizados podem estar em standby; não falha a menos que seja serviço crítico
            if [[ "$svc_name" =~ (Karteman|Verifica|Investimentos) ]]; then
                echo -e "  ${YELLOW}⏸ [OFFLINE / STANDBY]${NC} ${svc_name} (Porta não respondeu)"
            else
                echo -e "  ${RED}✖ [CONNECTION REFUSED]${NC} ${svc_name} (${url}) -> Serviço totalmente fora do ar!"
                HTTP_FAILURES=$((HTTP_FAILURES + 1))
                FAILURES_COUNT=$((FAILURES_COUNT + 1))
                FAILED_SERVICES+=("http_${svc_name}")
            fi
            ;;
        *)
            echo -e "  ${YELLOW}? [HTTP ${code}]${NC} ${svc_name}"
            ;;
    esac
done

# ------------------------------------------------------------------------------
# 4. Inspeção Automática de Logs dos Containers com Falha
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}${BOLD}[4/4] Diagnóstico de Causa Raiz nos Logs de Containers:${NC}"

LOGS_EXTRACTED=0

for svc in "${FAILED_SERVICES[@]}"; do
    c_target=""
    if [[ "$svc" == *"Immich"* ]] || [[ "$svc" == *"immich"* ]]; then
        c_target="immich_server_1"
    elif [[ "$svc" == *"Jellyfin"* ]] || [[ "$svc" == *"jellyfin"* ]]; then
        c_target="jellyfin_server_1"
    elif [[ "$svc" == *"Nextcloud"* ]] || [[ "$svc" == *"nextcloud"* ]]; then
        c_target="nextcloud_web_1"
    elif [[ "$svc" == *"Home Assistant"* ]]; then
        c_target="home-assistant_server_1"
    elif [[ "$svc" == container_* ]]; then
        c_target="${svc#container_}"
    fi

    if [ -n "$c_target" ] && docker ps -a --format '{{.Names}}' | grep -qx "$c_target"; then
        echo -e "\n  ${YELLOW}Últimos logs de erro do container ${BOLD}${c_target}${NC}:${NC}"
        docker logs --tail 15 "$c_target" 2>&1 | sed 's/^/    | /' || true
        LOGS_EXTRACTED=$((LOGS_EXTRACTED + 1))
    fi
done

if [ "$LOGS_EXTRACTED" -eq 0 ]; then
    echo -e "  ${GREEN}✔ Nenhum container problemático para inspecionar logs.${NC}"
fi

# ------------------------------------------------------------------------------
# Relatório Final e Recomendação de Ação
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}${BOLD}==============================================================================${NC}"
echo -e "${BLUE}${BOLD}                     RESUMO DO DIAGNÓSTICO DO HOMELAB                         ${NC}"
echo -e "${BLUE}${BOLD}==============================================================================${NC}"

if [ "$FAILURES_COUNT" -eq 0 ]; then
    echo -e "${GREEN}${BOLD}✔ EXCELENTE: 100% dos serviços, discos e containers estão saudáveis!${NC}"
    echo -e "Nenhuma queda ou anomalia detectada no momento.\n"
else
    echo -e "${RED}${BOLD}✖ ATENÇÃO: Foram identificadas ${FAILURES_COUNT} anomalia(s) no Homelab!${NC}\n"
    if [ "$IO_ERROR_DETECTED" = true ]; then
        echo -e "  ${YELLOW}➡ Detectado erro de I/O em discos externos ou montagens zumbis.${NC}"
    fi
    if [ "$CONTAINER_ISSUES" -gt 0 ]; then
        echo -e "  ${YELLOW}➡ Detectados containers em crash loop ou abatidos por falta de memória.${NC}"
    fi
    if [ "$HTTP_FAILURES" -gt 0 ]; then
        echo -e "  ${YELLOW}➡ Detectados serviços retornando 502 Bad Gateway ou fora do ar.${NC}"
    fi

    echo -e "\n${BOLD}${CYAN}Comandos recomendados para restauração imediata:${NC}"
    echo -e "  ${BOLD}1. Restaurar tudo automaticamente:${NC}"
    echo -e "     ${GREEN}./scripts/utils/homelab_restaurar_servicos.sh --all${NC}"
    echo -e "  ${BOLD}2. Restaurar apenas o Immich (caso específico de fotos/upload):${NC}"
    echo -e "     ${GREEN}./scripts/utils/homelab_restaurar_servicos.sh --service immich${NC}"
    echo -e "  ${BOLD}3. Restaurar apenas o Jellyfin:${NC}"
    echo -e "     ${GREEN}./scripts/utils/homelab_restaurar_servicos.sh --service jellyfin${NC}\n"
fi
REMOTESCRIPT
}

if [ "$IS_LOCAL" = true ]; then
    run_audit
else
    ssh -o LogLevel=ERROR -i "${SSH_KEY}" "${SERVER_USER}@${SERVER_HOST}" "$(declare -f run_audit); run_audit"
fi
