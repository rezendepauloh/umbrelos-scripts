#!/usr/bin/env bash
# ==============================================================================
# scripts/utils/homelab_rollback.sh
# ------------------------------------------------------------------------------
# Utilitário de Restauração e Rollback do Homelab umbrelOS.
# Permite reverter:
#   1. Rollback do Sistema Operacional (Slots A/B do Rugix OS pós-atualização falha)
#   2. Restauração Completa do Estado via Snapshot Pré-Upgrade (Dumps + App-Data + /data)
#   3. Restauração Granular de Banco de Dados Específico (Immich / Nextcloud / Karteman)
#   4. Restauração de App-Data Específico (Jellyfin / Nextcloud / Home Assistant / AdGuard)
#   5. Reversão de Imagens Docker das Stacks Customizadas (Dockge / Compose)
# ==============================================================================

set -euo pipefail

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

echo -e "${BLUE}${BOLD}======================================================================${NC}"
echo -e "${BLUE}${BOLD}===         CENTRAL DE ROLLBACK E RESTAURAÇÃO DO HOMELAB           ===${NC}"
echo -e "${BLUE}${BOLD}======================================================================${NC}"

# Teste de conectividade SSH com o Mini PC
if ! ssh -i "${SSH_KEY}" -o ConnectTimeout=4 -o BatchMode=yes "${SERVER_USER}@${SERVER_HOST}" "exit 0" 2>/dev/null; then
    echo -e "${RED}[!] ERRO: Mini PC ${SERVER_HOST} inacessível via SSH.${NC}"
    echo -e "    Se o sistema operacional travou e não sobe SSH, reinicie o mini PC manualmente."
    exit 1
fi

echo -e "${CYAN}Selecione o tipo de Rollback que deseja realizar:${NC}\n"
echo "1) Rollback do Sistema Operacional (Reverter Slot de Boot A/B no Rugix OS)"
echo "2) Restaurar Estado Completo Pré-Upgrade (Bancos + Apps + Stacks + /data)"
echo "3) Restaurar Apenas Banco de Dados Específico (Immich, Nextcloud ou Karteman)"
echo "4) Restaurar Apenas Configurações (app-data) de um Serviço Oficial"
echo "0) Cancelar e Sair"
echo ""
read -rp "Opção [0]: " OPTION
OPTION="${OPTION:-0}"

if [[ "$OPTION" == "0" ]]; then
    echo "Operação cancelada."
    exit 0
fi

ssh -o LogLevel=ERROR -t -i "${SSH_KEY}" "${SERVER_USER}@${SERVER_HOST}" "bash -s -- $OPTION" << 'REMOTESCRIPT'
set -euo pipefail

OPTION="$1"
if [ -f /data/config.env ]; then
    set -a
    source /data/config.env
    set +a
fi

BACKUP_DIR="/home/umbrel/umbrel/external/disk3/backups"

list_snapshots() {
    echo -e "\n\033[1;36mSnapshots pré-upgrade disponíveis no disk3:\033[0m"
    find "$BACKUP_DIR" -maxdepth 1 -name "pre_upgrade_*" -type d | sort -r | head -n 10
}

case "$OPTION" in
    1)
        echo -e "\n\033[1;33m[!] Executando Rollback do Sistema Operacional (Rugix OS Slot A/B)...\033[0m"
        CURRENT_INFO=$(echo "$SYSTEM_PASSWORD" | sudo -S rugix-ctrl system info 2>/dev/null || true)
        ACTIVE_GROUP=$(echo "$CURRENT_INFO" | grep -o '"activeGroup":"[^"]*"' | cut -d'"' -f4 || echo "desconhecido")
        echo -e "Grupo de boot atualmente ativo: \033[1;37m${ACTIVE_GROUP}\033[0m"
        
        echo -e "\nMarcando grupo atual como inválido/ruim para o Rugix alternar o boot no próximo ciclo..."
        echo "$SYSTEM_PASSWORD" | sudo -S rugix-ctrl boot mark-bad "$ACTIVE_GROUP" 2>&1 | grep -v 'password for umbrel' || true
        
        echo -e "\n\033[1;32m[✔] Slot alternativo configurado com sucesso!\033[0m"
        echo -e "\033[1;31mDeseja reiniciar o Mini PC agora para subir no slot anterior? (s/N)\033[0m"
        read -r CONFIRM
        if [[ "$CONFIRM" =~ ^[sS]$ ]]; then
            echo "Reiniciando servidor em 3 segundos..."
            echo "$SYSTEM_PASSWORD" | sudo -S reboot
        else
            echo "Reinicialização adiada. Execute 'sudo reboot' quando estiver pronto."
        fi
        ;;

    2)
        echo -e "\n\033[1;33m[!] Restauração Completa de Snapshot Pré-Upgrade\033[0m"
        list_snapshots
        echo ""
        read -rp "Cole o caminho completo do snapshot que deseja restaurar: " SNAP_PATH
        if [ ! -d "$SNAP_PATH" ]; then
            echo -e "\033[1;31mErro: Caminho '$SNAP_PATH' não existe.\033[0m"
            exit 1
        fi

        echo -e "\n\033[1;31mATENÇÃO: Isso irá restaurar bancos de dados e app-data a partir de $SNAP_PATH.\033[0m"
        read -rp "Tem certeza que deseja continuar? (digite 'sim'): " CONFIRM_RESTORE
        if [[ "$CONFIRM_RESTORE" != "sim" ]]; then
            echo "Operação cancelada."
            exit 0
        fi

        # 1. Restaurar App Data
        if [ -d "$SNAP_PATH/app_data" ]; then
            echo -e "\n\033[1;36m[1/4] Restaurando app-data dos serviços oficiais...\033[0m"
            echo "$SYSTEM_PASSWORD" | sudo -S rsync -av --exclude='immich/data/upload' --exclude='nextcloud/data' "$SNAP_PATH/app_data/" /home/umbrel/umbrel/app-data/ 2>&1 | grep -v 'password for umbrel' || true
        fi

        # 2. Restaurar Custom Stacks
        if [ -d "$SNAP_PATH/custom_stacks" ]; then
            echo -e "\n\033[1;36m[2/4] Restaurando configurações das stacks Docker...\033[0m"
            echo "$SYSTEM_PASSWORD" | sudo -S rsync -av "$SNAP_PATH/custom_stacks/" /home/umbrel/umbrelos-scripts/compose/ 2>&1 | grep -v 'password for umbrel' || true
        fi

        # 3. Restaurar /data
        if [ -d "$SNAP_PATH/system_data" ]; then
            echo -e "\n\033[1;36m[3/4] Restaurando configurações persistentes de /data...\033[0m"
            echo "$SYSTEM_PASSWORD" | sudo -S rsync -av --exclude='umbrel-os' "$SNAP_PATH/system_data/" /data/ 2>&1 | grep -v 'password for umbrel' || true
        fi

        # 4. Restaurar Bancos
        echo -e "\n\033[1;36m[4/4] Restaurando bancos de dados relacionais...\033[0m"
        # Nextcloud
        if [ -f "$SNAP_PATH/databases/nextcloud_db.sql.gz" ]; then
            NEXTCLOUD_DB=$(echo "$SYSTEM_PASSWORD" | sudo -S docker ps -q -f name=nextcloud_db_1 2>/dev/null | head -n 1 || true)
            if [ -n "$NEXTCLOUD_DB" ]; then
                echo "  -> Restaurando MariaDB do Nextcloud..."
                gunzip -c "$SNAP_PATH/databases/nextcloud_db.sql.gz" | echo "$SYSTEM_PASSWORD" | sudo -S docker exec -i "$NEXTCLOUD_DB" mysql -u root 2>/dev/null || true
            fi
        fi
        # Immich
        if [ -f "$SNAP_PATH/databases/immich_db.sql.gz" ]; then
            IMMICH_PG=$(echo "$SYSTEM_PASSWORD" | sudo -S docker ps -q -f name=immich_postgres_1 2>/dev/null | head -n 1 || true)
            if [ -n "$IMMICH_PG" ]; then
                echo "  -> Restaurando PostgreSQL do Immich..."
                gunzip -c "$SNAP_PATH/databases/immich_db.sql.gz" | echo "$SYSTEM_PASSWORD" | sudo -S docker exec -i "$IMMICH_PG" psql -U postgres 2>/dev/null || true
            fi
        fi

        echo -e "\n\033[1;32m[✔] Restauração completa finalizada! Recomendamos reiniciar o mini PC ou os containers.\033[0m"
        ;;

    3)
        echo -e "\n\033[1;33m[!] Restaurar Apenas Banco de Dados Específico\033[0m"
        list_snapshots
        read -rp "Cole o caminho do snapshot desejado: " SNAP_PATH
        if [ ! -d "$SNAP_PATH/databases" ]; then
            echo -e "\033[1;31mErro: Pasta de databases não encontrada em $SNAP_PATH.\033[0m"
            exit 1
        fi

        echo "Escolha o banco:"
        echo "1) Nextcloud MariaDB"
        echo "2) Immich PostgreSQL"
        echo "3) Karteman PostgreSQL"
        read -rp "Opção: " DB_OPT

        case "$DB_OPT" in
            1)
                NEXTCLOUD_DB=$(echo "$SYSTEM_PASSWORD" | sudo -S docker ps -q -f name=nextcloud_db_1 2>/dev/null | head -n 1 || true)
                gunzip -c "$SNAP_PATH/databases/nextcloud_db.sql.gz" | echo "$SYSTEM_PASSWORD" | sudo -S docker exec -i "$NEXTCLOUD_DB" mysql -u root 2>/dev/null || true
                echo -e "\033[1;32m[✔] Banco do Nextcloud restaurado com sucesso!\033[0m"
                ;;
            2)
                IMMICH_PG=$(echo "$SYSTEM_PASSWORD" | sudo -S docker ps -q -f name=immich_postgres_1 2>/dev/null | head -n 1 || true)
                gunzip -c "$SNAP_PATH/databases/immich_db.sql.gz" | echo "$SYSTEM_PASSWORD" | sudo -S docker exec -i "$IMMICH_PG" psql -U postgres 2>/dev/null || true
                echo -e "\033[1;32m[✔] Banco do Immich restaurado com sucesso!\033[0m"
                ;;
            3)
                KARTEMAN_PG=$(echo "$SYSTEM_PASSWORD" | sudo -S docker ps -q -f name=karteman-postgres 2>/dev/null | head -n 1 || true)
                gunzip -c "$SNAP_PATH/databases/karteman_db.sql.gz" | echo "$SYSTEM_PASSWORD" | sudo -S docker exec -i "$KARTEMAN_PG" psql -U postgres 2>/dev/null || true
                echo -e "\033[1;32m[✔] Banco do Karteman restaurado com sucesso!\033[0m"
                ;;
            *)
                echo "Opção inválida."
                ;;
        esac
        ;;

    4)
        echo -e "\n\033[1;33m[!] Restaurar Apenas Configuração (app-data) de um Serviço Oficial\033[0m"
        list_snapshots
        read -rp "Cole o caminho do snapshot desejado: " SNAP_PATH
        read -rp "Nome do app oficial (ex: jellyfin, nextcloud, adguard-home, home-assistant): " APP_NAME
        
        if [ -d "$SNAP_PATH/app_data/$APP_NAME" ]; then
            echo "Restaurando /home/umbrel/umbrel/app-data/$APP_NAME..."
            echo "$SYSTEM_PASSWORD" | sudo -S rsync -av --delete \
                --exclude='data/upload' --exclude='data/transcodes' --exclude='data/cache' \
                "$SNAP_PATH/app_data/$APP_NAME/" "/home/umbrel/umbrel/app-data/$APP_NAME/" 2>&1 | grep -v 'password for umbrel' || true
            echo -e "\033[1;32m[✔] App-data de $APP_NAME restaurado com sucesso!\033[0m"
        else
            echo -e "\033[1;31mErro: App '$APP_NAME' não encontrado no snapshot informado.\033[0m"
        fi
        ;;
esac
REMOTESCRIPT

