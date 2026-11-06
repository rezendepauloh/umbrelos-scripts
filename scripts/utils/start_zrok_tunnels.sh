#!/usr/bin/env bash
# ==============================================================================
# scripts/utils/start_zrok_tunnels.sh
# ------------------------------------------------------------------------------
# Inicia os túneis zrok v2 de forma sequencial com espaçamento de segurança
# para evitar Rate Limit (HTTP 429 - "service is busy") na API pública do zrok.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TUNNELS_DIR="${SCRIPT_DIR}/compose/tunnels"
ENV_FILE="/data/config.env"

[ ! -f "$ENV_FILE" ] && ENV_FILE="${SCRIPT_DIR}/config.env"

DELAY_BETWEEN_SERVICES=30 # segundos de resfriamento entre cada túnel

SERVICES=(
    "zrok-umbrel"
    "zrok-karteman"
    "zrok-diarios"
    "zrok-investimentos"
    "zrok-cloud"
    "zrok-jellyfin"
)

echo "=== Iniciando Túneis zrok v2 com Escalonamento Seguro ==="
echo "Intervalo de segurança: ${DELAY_BETWEEN_SERVICES}s entre serviços."

cd "$TUNNELS_DIR"

for svc in "${SERVICES[@]}"; do
    echo "--------------------------------------------------------"
    echo ">> Subindo serviço: $svc..."
    docker compose --env-file "$ENV_FILE" up -d "$svc"
    
    echo "Aguardando ${DELAY_BETWEEN_SERVICES}s antes do próximo túnel..."
    sleep "$DELAY_BETWEEN_SERVICES"
done

echo "========================================================"
echo "Todos os túneis foram disparados com sucesso!"
docker compose ps
