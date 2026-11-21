#!/usr/bin/env bash
# ==============================================================================
# scripts/utils/homelab_fix_mounts.sh
# ------------------------------------------------------------------------------
# Executa remotamente (via SSH no Mini PC) o modo rápido `--fix-mounts` do
# /data/bin/homelab-daemon.sh para reaplicar os volumes do Nextcloud e os bind
# mounts do Jellyfin e do Immich após atualizações da loja do umbrelOS.
#
# Uso (no Pop!_OS):
#   ./scripts/utils/homelab_fix_mounts.sh
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ENV_FILE="${REPO_ROOT}/config.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "❌ Erro: config.env não encontrado em $ENV_FILE" >&2
    exit 1
fi

# shellcheck disable=SC1090
source "$ENV_FILE"

if [ -z "${SYSTEM_PASSWORD:-}" ]; then
    echo "❌ Erro: SYSTEM_PASSWORD não definida em $ENV_FILE" >&2
    exit 1
fi

SERVER_HOST="${UMBREL_HOST:-192.168.0.8}"
SERVER_USER="${UMBREL_USER:-umbrel}"

echo "🔧 Conectando em ${SERVER_USER}@${SERVER_HOST} para reaplicar mounts (Nextcloud, Jellyfin, Immich)..."
ssh "${SERVER_USER}@${SERVER_HOST}" "echo '${SYSTEM_PASSWORD}' | sudo -S bash -c '/data/bin/homelab-daemon.sh --fix-mounts && tail -n 10 /data/homelab-daemon.log'"
echo "✅ Concluído!"
