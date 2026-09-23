#!/usr/bin/env bash
# ==============================================================================
# setup_umbrelos.sh - Orquestrador Geral Pós-Instalação para umbrelOS Homelab
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Carregar funções comuns
source "${SCRIPT_DIR}/lib/common.sh"

# Verificar privilégios de root
check_root

# Carregar arquivo de configuração (se existir) ou o modelo padrão
CONFIG_FILE="${SCRIPT_DIR}/config.env"
if [[ ! -f "$CONFIG_FILE" ]]; then
    log_warn "Arquivo 'config.env' não encontrado. Copiando do 'config.env.example'..."
    cp "${SCRIPT_DIR}/config.env.example" "$CONFIG_FILE"
fi

source "$CONFIG_FILE"

# Banner de Inicialização
clear 2>/dev/null || true
echo -e "${BOLD}${CYAN}"
echo "================================================================================"
echo "          umbrelOS Homelab Setup - Blackview MP100 Pro (i5-12450H)              "
echo "================================================================================"
echo -e "${NC}"
echo -e "Usuário do Sistema : ${GREEN}${SYSTEM_USER}${NC}"
echo -e "Usuários Samba     : ${GREEN}${SAMBA_USER_1}, ${SAMBA_USER_2}${NC}"
echo -e "Storage Base       : ${GREEN}${STORAGE_BASE_DIR}${NC}"
echo "================================================================================"
echo ""

# Menu ou Execução Direta
show_menu() {
    echo -e "${BOLD}Selecione a operação desejada:${NC}"
    echo "1) Instalação Completa (Todos os módulos recomendados)"
    echo "2) Módulo 1: Preparação do Sistema e Utilitários"
    echo "3) Módulo 2: Configuração de Discos e Storage"
    echo "4) Módulo 3: Configuração do Servidor Samba"
    echo "5) Módulo 4: Subir Stacks Docker Complementares (Dockge, Arr, etc.)"
    echo "6) Módulo 5: Segurança, SSH e Tailscale"
    echo "7) Módulo 6: Blindagem Contra Queda de Energia e Backup de Bancos"
    echo "0) Sair"
    echo ""
    read -rp "Opção [1]: " OPTION
    OPTION="${OPTION:-1}"
}

run_module_1() {
    source "${SCRIPT_DIR}/scripts/01_system_prep.sh"
}

run_module_2() {
    source "${SCRIPT_DIR}/scripts/02_storage_setup.sh"
}

run_module_3() {
    source "${SCRIPT_DIR}/scripts/03_samba_setup.sh"
}

run_module_4() {
    source "${SCRIPT_DIR}/scripts/04_docker_custom_stacks.sh"
}

run_module_5() {
    source "${SCRIPT_DIR}/scripts/05_security_network.sh"
}

run_module_6() {
    source "${SCRIPT_DIR}/scripts/06_backup_popos.sh"
}

run_all() {
    if [[ "${ENABLE_SYSTEM_PREP:-true}" == "true" ]]; then run_module_1; fi
    if [[ "${ENABLE_STORAGE_SETUP:-true}" == "true" ]]; then run_module_2; fi
    if [[ "${ENABLE_SAMBA_SETUP:-true}" == "true" ]]; then run_module_3; fi
    if [[ "${ENABLE_DOCKER_STACKS:-true}" == "true" ]]; then run_module_4; fi
    if [[ "${ENABLE_SECURITY_HARDENING:-true}" == "true" ]]; then run_module_5; fi
    if [[ "${ENABLE_CRASH_RESILIENCE:-true}" == "true" ]]; then run_module_6; fi
    
    echo ""
    echo -e "${BOLD}${GREEN}================================================================================${NC}"
    echo -e "${BOLD}${GREEN}        PARABÉNS! A INSTALAÇÃO DO SEU HOMELAB FOI CONCLUÍDA COM SUCESSO!        ${NC}"
    echo -e "${BOLD}${GREEN}================================================================================${NC}"
    echo ""
    echo -e "${BOLD}Acessos Rápidos:${NC}"
    echo -e "  - Dashboard umbrelOS : ${CYAN}http://umbrel.local${NC} ou pelo IP da máquina"
    echo -e "  - Nginx Proxy Mgr    : ${CYAN}http://umbrel.local:${NPM_WEB_PORT:-81}${NC} (Admin: admin@example.com / changeme)"
    echo -e "  - Dockge (Stacks)    : ${CYAN}http://umbrel.local:${DOCKGE_PORT}${NC}"
    echo -e "  - Uptime Kuma        : ${CYAN}http://umbrel.local:${UPTIME_KUMA_PORT}${NC}"
    echo -e "  - IT-Tools           : ${CYAN}http://umbrel.local:${IT_TOOLS_PORT}${NC}"
    echo -e "  - Syncthing Web UI   : ${CYAN}http://umbrel.local:${SYNCTHING_WEB_PORT:-8384}${NC}"
    echo -e "  - Jellyseerr         : ${CYAN}http://umbrel.local:${JELLYSEERR_PORT}${NC}"
    echo -e "  - Radarr / Sonarr    : ${CYAN}http://umbrel.local:${RADARR_PORT}${NC} / ${CYAN}http://umbrel.local:${SONARR_PORT}${NC}"
    echo -e "  - Prowlarr / Jackett : ${CYAN}http://umbrel.local:${PROWLARR_PORT}${NC} / ${CYAN}http://umbrel.local:${JACKETT_PORT}${NC}"
    echo -e "  - qBittorrent Web    : ${CYAN}http://umbrel.local:${QBITTORRENT_WEB_PORT}${NC}"
    echo -e "  - Compartilhamentos  : ${CYAN}smb://umbrel.local/Media${NC}"
    echo ""
}

# Processamento da opção
if [[ "${1:-}" == "--all" ]]; then
    run_all
else
    show_menu
    case "$OPTION" in
        1) run_all ;;
        2) run_module_1 ;;
        3) run_module_2 ;;
        4) run_module_3 ;;
        5) run_module_4 ;;
        6) run_module_5 ;;
        0) exit 0 ;;
        *) log_error "Opção inválida."; exit 1 ;;
    esac
fi
