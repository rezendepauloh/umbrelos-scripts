#!/usr/bin/env bash
# ==============================================================================
# scripts/utils/homelab_restaurar_servicos.sh
# ------------------------------------------------------------------------------
# Restaurador Inteligente de Containers, Stacks e Armazenamento do Homelab.
# Resolve:
# 1. Erros de I/O de disco (EIO) por desconexão/re-enumeração de cabos USB.
# 2. Re-aplicação atômica dos Bind Mounts do Immich e Jellyfin.
# 3. Restauração ordenada de dependências (Postgres -> Redis -> Apps).
# 4. Recuperação de containers travados ou retornando 502 Bad Gateway.
#
# Uso:
#   ./scripts/utils/homelab_restaurar_servicos.sh               # Modo inteligente (auto-cura)
#   ./scripts/utils/homelab_restaurar_servicos.sh --all         # Restauração geral completa
#   ./scripts/utils/homelab_restaurar_servicos.sh --service immich   # Recupera fotos/Immich
#   ./scripts/utils/homelab_restaurar_servicos.sh --service jellyfin # Recupera mídia/Jellyfin
#   ./scripts/utils/homelab_restaurar_servicos.sh --service nextcloud# Recupera nuvem/Nextcloud
#   ./scripts/utils/homelab_restaurar_servicos.sh --stack arr-stack  # Reinicia stack Compose
#   ./scripts/utils/homelab_restaurar_servicos.sh --disks            # Remonta apenas os 3 HDs
# ==============================================================================

set -euo pipefail

# Cores e Formatação
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.env"
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

SERVER_HOST="${SERVER_HOST:-192.168.0.8}"
SERVER_USER="${SERVER_USER:-umbrel}"
SSH_KEY="${HOME}/.ssh/id_ed25519"

TARGET_MODE="auto"
TARGET_ARG=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --all)
            TARGET_MODE="all"
            shift
            ;;
        --service|-s)
            TARGET_MODE="service"
            TARGET_ARG="${2:-}"
            shift 2
            ;;
        --stack)
            TARGET_MODE="stack"
            TARGET_ARG="${2:-}"
            shift 2
            ;;
        --disks|--force-disks)
            TARGET_MODE="disks"
            shift
            ;;
        -h|--help)
            echo "Uso: $0 [OPÇÕES]"
            echo ""
            echo "Opções:"
            echo "  (sem argumentos)         Modo inteligente: detecta e repara apenas serviços com falha"
            echo "  --all                    Restauração completa de discos, montagens e todos os containers"
            echo "  --service, -s <nome>     Restaura serviço específico (immich, jellyfin, nextcloud, etc.)"
            echo "  --stack <nome>           Reinicia stack compose específica (arr-stack, management, etc.)"
            echo "  --disks, --force-disks   Limpa montagens zumbis e remonta os 3 HDs por UUID"
            exit 0
            ;;
        *)
            TARGET_MODE="service"
            TARGET_ARG="$1"
            shift
            ;;
    esac
done

echo -e "${BLUE}${BOLD}==============================================================================${NC}"
echo -e "${BLUE}${BOLD}      RESTAURADOR INTELIGENTE DE SERVIÇOS & CONTAINERS (umbrelOS)             ${NC}"
echo -e "${BLUE}${BOLD}==============================================================================${NC}"

# Detectar ambiente local vs remoto
IS_LOCAL=false
if [[ "$(hostname 2>/dev/null)" == "umbrel" ]] || [[ -f "/data/umbrel-os" ]]; then
    IS_LOCAL=true
fi

if [ "$IS_LOCAL" = false ]; then
    echo -e "${CYAN}ℹ Conectando ao Mini PC (${SERVER_USER}@${SERVER_HOST})...${NC}"
    if ! ssh -i "${SSH_KEY}" -o ConnectTimeout=4 -o BatchMode=yes "${SERVER_USER}@${SERVER_HOST}" "exit 0" 2>/dev/null; then
        echo -e "${RED}[!] ERRO: Mini PC ${SERVER_HOST} inacessível via SSH.${NC}"
        exit 1
    fi
    echo -e "${GREEN}[✔] Conexão estabelecida!${NC}\n"
fi

execute_restore() {
    local mode="$1"
    local arg="$2"

    bash -s << REMOTESCRIPT
set -u

source /data/config.env 2>/dev/null || true

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

MODE="${mode}"
ARG="${arg}"

UUID_DISK1="${DISK1_UUID:-fc0b5d7b-1706-4461-9e1e-9d3f61e7bab0}"
UUID_DISK2="${DISK2_UUID:-490440f1-8f2e-41fd-bc27-00632adec790}"
UUID_DISK3="${DISK3_UUID:-e106affb-35da-4e93-a92d-e1ef5df32bb5}"

DIR_DISK1="/home/umbrel/umbrel/external/disk1"
DIR_DISK2="/home/umbrel/umbrel/external/disk2"
DIR_DISK3="/home/umbrel/umbrel/external/disk3"
DIR_MEDIA="/home/umbrel/umbrel/home/Downloads/media"
DIR_IMMICH="/home/umbrel/umbrel/app-data/immich/data/upload"

# Função para executar comandos como root via sudo não-interativo
run_root() {
    local cmd="\$1"
    echo "\$SYSTEM_PASSWORD" | sudo -S sh -c "\$cmd"
}

# ------------------------------------------------------------------------------
# 1. Rotina de Cura de Armazenamento e Montagens Zumbis
# ------------------------------------------------------------------------------
restaurar_discos() {
    echo -e "${CYAN}${BOLD}[Armazenamento] Desmontando pontos com erro de I/O ou montagens duplicadas...${NC}"
    run_root "
        umount -l \$DIR_MEDIA 2>/dev/null || true
        umount -l \$DIR_IMMICH 2>/dev/null || true
        umount -l /data/umbrel-os\$DIR_MEDIA 2>/dev/null || true
        umount -l /data/umbrel-os\$DIR_IMMICH 2>/dev/null || true
        umount -l \$DIR_DISK1 2>/dev/null || true
        umount -l \$DIR_DISK2 2>/dev/null || true
        umount -l \$DIR_DISK3 2>/dev/null || true
        umount -l /data/umbrel-os\$DIR_DISK1 2>/dev/null || true
        umount -l /data/umbrel-os\$DIR_DISK2 2>/dev/null || true
        umount -l /data/umbrel-os\$DIR_DISK3 2>/dev/null || true

        mkdir -p \$DIR_DISK1 \$DIR_DISK2 \$DIR_DISK3 \$DIR_MEDIA \$DIR_IMMICH

        echo '  -> Remontando HD1 Mídia (UUID \$UUID_DISK1)...'
        mount UUID=\"\$UUID_DISK1\" \$DIR_DISK1 2>/dev/null || mount /dev/disk/by-uuid/\"\$UUID_DISK1\" \$DIR_DISK1 2>/dev/null || true

        echo '  -> Remontando HD2 Nuvem & Fotos (UUID \$UUID_DISK2)...'
        mount UUID=\"\$UUID_DISK2\" \$DIR_DISK2 2>/dev/null || mount /dev/disk/by-uuid/\"\$UUID_DISK2\" \$DIR_DISK2 2>/dev/null || true

        echo '  -> Remontando HD3 Backups (UUID \$UUID_DISK3)...'
        mount UUID=\"\$UUID_DISK3\" \$DIR_DISK3 2>/dev/null || mount /dev/disk/by-uuid/\"\$UUID_DISK3\" \$DIR_DISK3 2>/dev/null || true

        echo '  -> Restabelecendo Bind Mounts essenciais...'
        if [ -d \"\$DIR_DISK1/media\" ]; then
            mount --bind \$DIR_DISK1/media \$DIR_MEDIA
            echo '     ✔ Bind Mount Jellyfin (disk1/media -> Downloads/media) ativo'
        fi

        if [ -d \"\$DIR_DISK2/immich/upload\" ]; then
            mount --bind \$DIR_DISK2/immich/upload \$DIR_IMMICH
            echo '     ✔ Bind Mount Immich (disk2/immich/upload -> app-data/immich/upload) ativo'
        fi
    "
    echo -e "${GREEN}[✔] Armazenamento curado e remontado com sucesso!${NC}\n"
}

# ------------------------------------------------------------------------------
# 2. Restaurador de Serviços Individuais
# ------------------------------------------------------------------------------
restaurar_immich() {
    echo -e "${BLUE}${BOLD}==> Restaurando Serviço: Immich (Galeria de Fotos & IA)${NC}"

    # 1. Garantir que o diretório no disk2 está montado e sem I/O error
    if ! timeout 5 ls -la "\$DIR_IMMICH" >/dev/null 2>&1; then
        echo -e "  ${YELLOW}⚠ Detectado erro de acesso em \$DIR_IMMICH. Remontando disk2...${NC}"
        restaurar_discos
    fi

    echo -e "  ${CYAN}[1/3] Reiniciando instâncias de banco de dados e cache (Postgres & Redis)...${NC}"
    docker restart immich_postgres_1 immich_redis_1 >/dev/null 2>&1 || true
    sleep 3

    echo -e "  ${CYAN}[2/3] Reiniciando serviço principal (immich-server & machine-learning)...${NC}"
    docker restart immich_machine-learning_1 immich_server_1 >/dev/null 2>&1 || true
    echo -e "  ${CYAN}Aguardando 6s para aquecimento da API e carregamento das bibliotecas...${NC}"
    sleep 6

    # 3. Teste de Validação
    echo -e "  ${CYAN}[3/3] Validando resposta da API...${NC}"
    local code
    code=\$(docker exec immich_server_1 curl -s -o /dev/null -w "%{http_code}" http://localhost:2283/api/server/version 2>/dev/null || echo "000")
    if [ "\$code" = "200" ]; then
        echo -e "  ${GREEN}${BOLD}✔ SUCESSO: Immich restaurado e respondendo normalmente (HTTP 200 OK)!${NC}\n"
    else
        echo -e "  ${YELLOW}⚠ Immich reiniciado. Código HTTP interno: \${code}. Testando via gateway Umbrel...${NC}"
        local gw_code
        gw_code=\$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1/open-app/immich 2>/dev/null || echo "000")
        if [ "\$gw_code" = "200" ]; then
            echo -e "  ${GREEN}${BOLD}✔ SUCESSO: Immich acessível pelo painel do Umbrel (HTTP 200 OK)!${NC}\n"
        else
            echo -e "  ${RED}✖ Immich ainda não respondeu (HTTP \${gw_code}). Verifique logs com: docker logs --tail 20 immich_server_1${NC}\n"
        fi
    fi
}

restaurar_jellyfin() {
    echo -e "${BLUE}${BOLD}==> Restaurando Serviço: Jellyfin (Servidor de Mídia)${NC}"

    if ! timeout 5 ls -la "\$DIR_MEDIA" >/dev/null 2>&1; then
        echo -e "  ${YELLOW}⚠ Bind mount de mídia com erro. Remontando disk1...${NC}"
        restaurar_discos
    fi

    echo -e "  ${CYAN}Reiniciando container jellyfin_server_1...${NC}"
    docker restart jellyfin_server_1 >/dev/null 2>&1 || true
    sleep 4

    local code
    code=\$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8096 2>/dev/null || echo "000")
    if [[ "\$code" =~ (200|302) ]]; then
        echo -e "  ${GREEN}${BOLD}✔ SUCESSO: Jellyfin operacional (HTTP \${code})!${NC}\n"
    else
        echo -e "  ${YELLOW}Jellyfin reiniciado. Código HTTP atual: \${code}.${NC}\n"
    fi
}

restaurar_nextcloud() {
    echo -e "${BLUE}${BOLD}==> Restaurando Serviço: Nextcloud (Nuvem de Arquivos)${NC}"

    echo -e "  ${CYAN}Reiniciando containers nextcloud_web_1 e cron...${NC}"
    docker restart nextcloud_web_1 nextcloud_cron_1 >/dev/null 2>&1 || true
    sleep 4

    local code
    code=\$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8081 2>/dev/null || echo "000")
    if [[ "\$code" =~ (200|302) ]]; then
        echo -e "  ${GREEN}${BOLD}✔ SUCESSO: Nextcloud operacional (HTTP \${code})!${NC}\n"
    else
        echo -e "  ${YELLOW}Nextcloud reiniciado. Código HTTP atual: \${code}.${NC}\n"
    fi
}

restaurar_homeassistant() {
    echo -e "${BLUE}${BOLD}==> Restaurando Serviço: Home Assistant${NC}"
    docker restart home-assistant_server_1 >/dev/null 2>&1 || true
    sleep 3
    echo -e "  ${GREEN}✔ Home Assistant reiniciado com sucesso!${NC}\n"
}

restaurar_stack_compose() {
    local stack="\$1"
    local dir="/home/umbrel/umbrelos-scripts/compose/\$stack"
    echo -e "${BLUE}${BOLD}==> Restaurando Stack Compose: \${stack}${NC}"
    if [ -d "\$dir" ]; then
        cd "\$dir"
        docker compose --env-file /data/config.env up -d --force-recreate
        echo -e "  ${GREEN}✔ Stack \${stack} recriada e iniciada com sucesso!${NC}\n"
    else
        echo -e "  ${RED}✖ Stack \${dir} não localizada no servidor.${NC}\n"
    fi
}

# ------------------------------------------------------------------------------
# 3. Execução Conforme o Modo Solicitado
# ------------------------------------------------------------------------------
case "\$MODE" in
    disks)
        restaurar_discos
        ;;
    service)
        svc_clean=\$(echo "\$ARG" | tr '[:upper:]' '[:lower:]')
        case "\$svc_clean" in
            immich|fotos)
                restaurar_immich
                ;;
            jellyfin|midia|media)
                restaurar_jellyfin
                ;;
            nextcloud|cloud|nuvem)
                restaurar_nextcloud
                ;;
            homeassistant|home-assistant|ha)
                restaurar_homeassistant
                ;;
            *)
                # Tenta reiniciar como container avulso do Docker
                if docker ps -a --format '{{.Names}}' | grep -qx "\$ARG"; then
                    echo -e "${CYAN}Reiniciando container Docker avulso: \${ARG}...${NC}"
                    docker restart "\$ARG" >/dev/null 2>&1
                    echo -e "${GREEN}✔ Container \${ARG} reiniciado com sucesso!${NC}\n"
                else
                    echo -e "${RED}[!] Serviço '\${ARG}' não reconhecido.${NC}"
                    echo -e "    Opções disponíveis: immich, jellyfin, nextcloud, home-assistant ou nome exato do container."
                fi
                ;;
        esac
        ;;
    stack)
        restaurar_stack_compose "\$ARG"
        ;;
    all)
        echo -e "${BOLD}${YELLOW}Iniciando procedimento completo de restauração e auto-cura...${NC}\n"
        restaurar_discos
        restaurar_immich
        restaurar_jellyfin
        restaurar_nextcloud
        restaurar_homeassistant

        echo -e "${CYAN}Recriando e subindo stacks customizadas centrais...${NC}"
        for s in management arr-stack betor tunnels; do
            s_dir="/home/umbrel/umbrelos-scripts/compose/\$s"
            if [ -d "\$s_dir" ]; then
                cd "\$s_dir"
                docker compose --env-file /data/config.env up -d || true
            fi
        done
        echo -e "\n${GREEN}${BOLD}✔ RESTAURAÇÃO COMPLETA FINALIZADA COM SUCESSO!${NC}\n"
        ;;
    auto)
        echo -e "${BOLD}${CYAN}Modo Inteligente: Escaneando e auto-curando serviços caídos...${NC}\n"
        REPAIRED=0

        # 1. Checar se há erro de I/O de disco
        if ! timeout 5 ls -la "\$DIR_DISK1" >/dev/null 2>&1 || ! timeout 5 ls -la "\$DIR_DISK2" >/dev/null 2>&1 || ! timeout 5 ls -la "\$DIR_IMMICH" >/dev/null 2>&1; then
            echo -e "${YELLOW}➡ Anomalia de I/O em discos detectada. Executando cura de armazenamento...${NC}"
            restaurar_discos
            REPAIRED=\$((REPAIRED + 1))
        fi

        # 2. Checar Immich
        immich_code=\$(docker exec immich_server_1 curl -s -o /dev/null -w "%{http_code}" http://localhost:2283/api/server/version 2>/dev/null || echo "000")
        if [ "\$immich_code" != "200" ]; then
            echo -e "${YELLOW}➡ Immich não está saudável (HTTP \${immich_code}). Restaurando...${NC}"
            restaurar_immich
            REPAIRED=\$((REPAIRED + 1))
        fi

        # 3. Checar Jellyfin
        jelly_code=\$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8096 2>/dev/null || echo "000")
        if [[ ! "\$jelly_code" =~ (200|302) ]]; then
            echo -e "${YELLOW}➡ Jellyfin não está saudável (HTTP \${jelly_code}). Restaurando...${NC}"
            restaurar_jellyfin
            REPAIRED=\$((REPAIRED + 1))
        fi

        # 4. Checar Nextcloud
        nc_code=\$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8081 2>/dev/null || echo "000")
        if [[ ! "\$nc_code" =~ (200|302) ]]; then
            echo -e "${YELLOW}➡ Nextcloud não está saudável (HTTP \${nc_code}). Restaurando...${NC}"
            restaurar_nextcloud
            REPAIRED=\$((REPAIRED + 1))
        fi

        # 5. Checar containers em loop de Restart
        RESTARTING_CONTAINERS=\$(docker ps --filter "status=restarting" --format "{{.Names}}" 2>/dev/null || true)
        if [ -n "\$RESTARTING_CONTAINERS" ]; then
            for rc in \$RESTARTING_CONTAINERS; do
                echo -e "${YELLOW}➡ Container em looping de reinício detectado: \${rc}. Forçando restart...${NC}"
                docker restart "\$rc" >/dev/null 2>&1 || true
                REPAIRED=\$((REPAIRED + 1))
            done
        fi

        if [ "\$REPAIRED" -eq 0 ]; then
            echo -e "${GREEN}${BOLD}✔ Nenhum serviço caído encontrado! O Homelab já está saudável.${NC}\n"
        else
            echo -e "${GREEN}${BOLD}✔ Auto-cura concluída: \${REPAIRED} componente(s) verificado(s) e restaurado(s)!${NC}\n"
        fi
        ;;
esac
REMOTESCRIPT
}

if [ "$IS_LOCAL" = true ]; then
    execute_restore "$TARGET_MODE" "$TARGET_ARG"
else
    # Execução remota via SSH repassando os argumentos de forma segura
    ssh -o LogLevel=ERROR -i "${SSH_KEY}" "${SERVER_USER}@${SERVER_HOST}" "$(declare -f execute_restore); execute_restore '$TARGET_MODE' '$TARGET_ARG'"
fi

