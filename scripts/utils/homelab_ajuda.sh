#!/usr/bin/env bash
# ==============================================================================
# scripts/utils/homelab_ajuda.sh
# ------------------------------------------------------------------------------
# Central de Ajuda Interativa e Guia de Comandos Rápidos do Homelab.
# Exibido automaticamente ao abrir o Web Terminal (ttyd) ou via terminal.
# ==============================================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

clear
echo -e "${BLUE}${BOLD}==============================================================================${NC}"
echo -e "${BLUE}${BOLD}        HOMELAB UMBRELOS — CENTRAL DE COMANDOS & RECUPERAÇÃO                  ${NC}"
echo -e "${BLUE}${BOLD}==============================================================================${NC}"
echo -e "${CYAN}Olá, Paulo! Este terminal tem acesso direto ao sistema do Mini PC.${NC}"
echo -e "Aqui estão os utilitários essenciais que você pode executar a qualquer momento:\n"

echo -e " ${BOLD}1. Diagnóstico Geral de Quedas e Saúde do Homelab:${NC}"
echo -e "    ${GREEN}./scripts/utils/homelab_verificar_quedas.sh${NC}"
echo -e "    ${DIM}↳ Escaneia discos (I/O), containers caídos, endpoints HTTP e logs de erro.${NC}\n"

echo -e " ${BOLD}2. Restauração Automática e Auto-Cura de Serviços:${NC}"
echo -e "    ${GREEN}./scripts/utils/homelab_restaurar_servicos.sh --all${NC}"
echo -e "    ${DIM}↳ Remonta os 3 HDs por UUID, re-aplica bind mounts e sobe todos os containers.${NC}\n"

echo -e " ${BOLD}3. Restauração de um Serviço Específico:${NC}"
echo -e "    ${GREEN}./scripts/utils/homelab_restaurar_servicos.sh --service immich${NC}   ${DIM}(Fotos/IA)${NC}"
echo -e "    ${GREEN}./scripts/utils/homelab_restaurar_servicos.sh --service jellyfin${NC} ${DIM}(Mídia)${NC}"
echo -e "    ${GREEN}./scripts/utils/homelab_restaurar_servicos.sh --service nextcloud${NC}${DIM}(Nuvem)${NC}"
echo -e "    ${GREEN}./scripts/utils/homelab_restaurar_servicos.sh --service ha${NC}       ${DIM}(Home Assistant)${NC}\n"

echo -e " ${BOLD}4. Auditoria e Sincronização de Backups:${NC}"
echo -e "    ${GREEN}./scripts/utils/homelab_auditar_e_sincronizar_backups.sh --check${NC}"
echo -e "    ${DIM}↳ Audita dumps SQL, fotos e dados brutos no disk3 e Pop!_OS sem transferir.${NC}\n"

echo -e " ${BOLD}5. Dashboard Rápido de Saúde & Docker:${NC}"
echo -e "    ${GREEN}./scripts/utils/homelab_dashboard_saude.sh${NC}"
echo -e "    ${DIM}↳ Visão executiva de uso de CPU, memória RAM e status dos containers.${NC}\n"

echo -e "${BLUE}${BOLD}------------------------------------------------------------------------------${NC}"
echo -e "${YELLOW}💡 DICA:${NC} Para ver esta lista novamente a qualquer momento, digite: ${BOLD}ajuda${NC} ou ${BOLD}homelab-ajuda${NC}"
echo -e "${BLUE}${BOLD}==============================================================================${NC}\n"
