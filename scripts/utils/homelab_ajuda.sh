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
DIM='\033[2m'
NC='\033[0m'

clear
echo -e "${BLUE}${BOLD}==============================================================================${NC}"
echo -e "${BLUE}${BOLD}        HOMELAB UMBRELOS — CENTRAL DE COMANDOS & RECUPERAÇÃO                  ${NC}"
echo -e "${BLUE}${BOLD}==============================================================================${NC}"
echo -e "${CYAN}Olá, Paulo! Este terminal tem acesso direto ao sistema do Mini PC.${NC}"
echo -e "Aqui estão os utilitários essenciais que você pode executar a qualquer momento:\n"

echo -e " ${BOLD}1. Diagnóstico, Saúde e Rede:${NC}"
echo -e "    ${GREEN}./scripts/utils/homelab_verificar_quedas.sh${NC}"
echo -e "    ${DIM}↳ Escaneia discos (I/O), containers caídos, endpoints HTTP e logs de erro.${NC}"
echo -e "    ${GREEN}./scripts/utils/homelab_dashboard_saude.sh${NC}"
echo -e "    ${DIM}↳ Visão executiva de uso de CPU, memória RAM e status dos containers.${NC}"
echo -e "    ${GREEN}./scripts/utils/homelab_verificar_dns.sh${NC}"
echo -e "    ${DIM}↳ Testa resolução DNS local (*.pk.local) e saúde do AdGuard Home.${NC}\n"

echo -e " ${BOLD}2. Restauração & Correções Rápidas:${NC}"
echo -e "    ${GREEN}./scripts/utils/homelab_restaurar_servicos.sh --all${NC}"
echo -e "    ${DIM}↳ Remonta os 3 HDs por UUID, re-aplica bind mounts e sobe todos os containers.${NC}"
echo -e "    ${GREEN}./scripts/utils/homelab_restaurar_servicos.sh --service <nome>${NC} ${DIM}(immich|jellyfin|nextcloud|ha)${NC}"
echo -e "    ${DIM}↳ Restaura um serviço específico.${NC}"
echo -e "    ${GREEN}./scripts/utils/fix_nextcloud_volumes.sh${NC}"
echo -e "    ${DIM}↳ Reinjeta /storage/users e /storage/shared no Nextcloud após update da loja.${NC}\n"

echo -e " ${BOLD}3. Manutenção de Stacks & Docker:${NC}"
echo -e "    ${GREEN}./scripts/utils/homelab_atualizar_stacks.sh${NC}"
echo -e "    ${DIM}↳ Atualiza imagens e recria stacks customizadas (management, arr-stack, betor, etc.).${NC}"
echo -e "    ${GREEN}./scripts/utils/homelab_limpeza_docker.sh${NC}"
echo -e "    ${DIM}↳ Remove imagens órfãs e libera espaço em disco com segurança.${NC}"
echo -e "    ${GREEN}./scripts/utils/homelab_hardlinks.sh${NC}"
echo -e "    ${DIM}↳ Verifica/corrige hardlinks entre downloads e biblioteca de mídia.${NC}"
echo -e "    ${GREEN}./scripts/utils/homelab_rollback.sh${NC}"
echo -e "    ${DIM}↳ Reverte alterações em stacks ou configurações em caso de falha.${NC}\n"

echo -e " ${BOLD}4. Backups & Segurança (Zrok):${NC}"
echo -e "    ${GREEN}./scripts/utils/homelab_auditar_e_sincronizar_backups.sh --check${NC}"
echo -e "    ${DIM}↳ Audita dumps SQL, fotos e dados brutos no disk3 e Pop!_OS sem transferir.${NC}"
echo -e "    ${GREEN}./scripts/utils/homelab_backup_pre_upgrade.sh${NC}"
echo -e "    ${DIM}↳ Gera snapshot completo antes de upgrades maiores do umbrelOS.${NC}"
echo -e "    ${GREEN}./scripts/utils/homelab_auditar_zrok.sh${NC}"
echo -e "    ${DIM}↳ Verifica status e segurança dos túneis públicos Zrok.${NC}\n"

echo -e "${BLUE}${BOLD}------------------------------------------------------------------------------${NC}"
echo -e "${YELLOW}💡 DICA:${NC} Para ver esta lista novamente a qualquer momento, digite: ${BOLD}ajuda${NC} ou ${BOLD}homelab-ajuda${NC}"
echo -e "${BLUE}${BOLD}==============================================================================${NC}\n"
