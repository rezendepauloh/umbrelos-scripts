#!/usr/bin/env bash
# ==============================================================================
# scripts/04_docker_custom_stacks.sh - Implantação das Stacks Docker Complementares
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "${SCRIPT_DIR}/lib/common.sh" ]] && source "${SCRIPT_DIR}/lib/common.sh"
[[ -f "${SCRIPT_DIR}/config.env" ]] && source "${SCRIPT_DIR}/config.env"

log_step "Módulo 4: Implantação das Stacks Docker Customizadas"

# Verificar se Docker e Docker Compose estão disponíveis
if ! command_exists docker; then
    log_error "Docker não encontrado. No umbrelOS o Docker já vem pré-instalado por padrão."
    exit 1
fi

COMPOSE_CMD=""
if docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
elif command_exists docker-compose; then
    COMPOSE_CMD="docker-compose"
else
    log_error "Plugin docker-compose ou docker compose não localizado."
    exit 1
fi

log_info "Utilizando comando do Compose: ${COMPOSE_CMD}"

# Garantir a criação da rede Docker compartilhada homelab_network
if ! docker network inspect homelab_network >/dev/null 2>&1; then
    log_info "Criando rede Docker compartilhada: homelab_network..."
    docker network create homelab_network
fi

# Criar arquivo .env unificado para as stacks
ENV_FILE="${SCRIPT_DIR}/.env"
log_info "Sincronizando variáveis em ${ENV_FILE}..."

cat <<EOF > "$ENV_FILE"
TIMEZONE=${TIMEZONE}
MEDIA_DIR=${MEDIA_DIR}
MOVIES_DIR=${MOVIES_DIR}
SERIES_DIR=${SERIES_DIR}
MUSIC_DIR=${MUSIC_DIR}
TORRENTS_DIR=${TORRENTS_DIR}
IMMICH_UPLOAD_DIR=${IMMICH_UPLOAD_DIR}
NEXTCLOUD_DATA_DIR=${NEXTCLOUD_DATA_DIR}
POPOS_HOST=${POPOS_HOST:-}
STORAGE_BASE_DIR=${STORAGE_BASE_DIR:-${DISK2_MOUNT:-/home/umbrel/umbrel/external/disk2}}
DOCKGE_PORT=${DOCKGE_PORT}
UPTIME_KUMA_PORT=${UPTIME_KUMA_PORT}
IT_TOOLS_PORT=${IT_TOOLS_PORT}
SYNCTHING_WEB_PORT=${SYNCTHING_WEB_PORT}
SYNCTHING_TRANSFER_PORT=${SYNCTHING_TRANSFER_PORT}
SYNCTHING_DISCOVERY_PORT=${SYNCTHING_DISCOVERY_PORT}
HOMELAB_DOMAIN=${HOMELAB_DOMAIN:-pk.local}
NPM_WEB_PORT=${NPM_WEB_PORT:-81}
NPM_HTTP_PORT=${NPM_HTTP_PORT:-8088}
NPM_HTTPS_PORT=${NPM_HTTPS_PORT:-8443}
JELLYSEERR_PORT=${JELLYSEERR_PORT}
RADARR_PORT=${RADARR_PORT}
SONARR_PORT=${SONARR_PORT}
BAZARR_PORT=${BAZARR_PORT}
PROWLARR_PORT=${PROWLARR_PORT}
JACKETT_PORT=${JACKETT_PORT}
QBITTORRENT_WEB_PORT=${QBITTORRENT_WEB_PORT}
QBITTORRENT_TORRENT_PORT=${QBITTORRENT_TORRENT_PORT}
EOF

# Subir Stack de Gerenciamento (Dockge, Uptime Kuma, IT-Tools)
log_info "Inicializando Stack de Gerenciamento (Dockge, Uptime Kuma, IT-Tools)..."
pushd "${SCRIPT_DIR}/compose/management" >/dev/null
${COMPOSE_CMD} --env-file "${ENV_FILE}" up -d
popd >/dev/null

# Subir Stack Arr & Download (qBittorrent, Prowlarr, Radarr, Sonarr, Bazarr, Jellyseerr)
log_info "Inicializando Stack Arr e qBittorrent..."
pushd "${SCRIPT_DIR}/compose/arr-stack" >/dev/null
${COMPOSE_CMD} --env-file "${ENV_FILE}" up -d
popd >/dev/null

# Ajuste automático do qBittorrent para aceitar Nginx Proxy Manager
# 2. Criar diretórios de dados persistentes para cada aplicação
mkdir -p "${SCRIPT_DIR}/compose/arr-stack/data"/{qbittorrent/config,prowlarr/config,jackett/config,radarr/config,sonarr/config,bazarr/config,jellyseerr/config,flaresolverr}
QBIT_CONF="${SCRIPT_DIR}/compose/arr-stack/data/qbittorrent/config/qBittorrent/qBittorrent.conf"
if [[ -f "$QBIT_CONF" ]] || [[ -d "${SCRIPT_DIR}/compose/arr-stack/data/qbittorrent/config" ]]; then
    mkdir -p "$(dirname "$QBIT_CONF")"
    sed -i '/WebUI\\CSRFProtection/d' "$QBIT_CONF" 2>/dev/null || true
    sed -i '/WebUI\\HostHeaderValidation/d' "$QBIT_CONF" 2>/dev/null || true
    cat << 'EOF' >> "$QBIT_CONF"
WebUI\CSRFProtection=false
WebUI\HostHeaderValidation=false
EOF
    docker restart qbittorrent >/dev/null 2>&1 || true
fi

# Configuração do BeTor (Buscador Nacional sob demanda) no Prowlarr
PROWLARR_CUSTOM_DIR="${SCRIPT_DIR}/compose/arr-stack/data/prowlarr/config/Definitions/Custom"
mkdir -p "${PROWLARR_CUSTOM_DIR}"
log_info "Configurando definição do BeTor (API local) para o Prowlarr..."
cat << 'EOF' > "${PROWLARR_CUSTOM_DIR}/betor.yml"
---
id: betor
name: Catálogo BeTor
description: "BeTor API local (Comando Torrents, Bludv, Starck)"
language: pt-BR
type: public
encoding: UTF-8
links:
  - http://betor-api:8000

caps:
  categories:
    5000: TV
    5030: TV/SD
    5040: TV/HD
    2000: Movies
    2030: Movies/SD
    2040: Movies/HD

  modes:
    search: [q]
    tv-search: [q, season, ep]
    movie-search: [q]

settings: []

search:
  keywordsfilters:
    - name: tolower
  paths:
    - path: "{{ if .Query.Q }}/v1/search/{{ else }}/v1/items/{{ end }}"
      response:
        type: json
      inputs:
        sort: -updated_at
        size: 100
        q: "{{ .Query.Q }}"

  rows:
    selector: $.items
    count:
      selector: $.total

  fields:
    _torrent_name:
      selector: torrent_name
    _magnet_dn:
      selector: magnet_dn
    _torrent_size:
      selector: torrent_size
    _torrent_num_seeds:
      selector: torrent_num_seeds
    _torrent_num_peers:
      selector: torrent_num_peers
    download:
      selector: magnet_uri
    title:
      text: "{{ if .Result._magnet_dn }}{{ .Result._magnet_dn }}{{ else if .Result._torrent_name }}{{ .Result._torrent_name }}{{ else }}Sem Titulo{{ end }}"
    details:
      selector: provider_url
    infohash:
      selector: magnet_xt
    date:
      selector: inserted_at
    size:
      text: "{{ if .Result._torrent_size }}{{ .Result._torrent_size }}{{ else }}0{{ end }}"
    seeders:
      text: "{{ if .Result._torrent_num_seeds }}{{ .Result._torrent_num_seeds }}{{ else }}1{{ end }}"
    leechers:
      text: "{{ if .Result._torrent_num_peers }}{{ .Result._torrent_num_peers }}{{ else }}0{{ end }}"
    category:
      selector: item_type
      case:
        tv: 5000
        movie: 2000
        "*": 5000
EOF

# Rotina diária de raspagem periódica do BeTor (Cronjob a cada 6h)
log_info "Configurando rotina periódica de raspagem do BeTor..."
CRON_BETOR="/etc/cron.d/betor-sync"
cat << 'EOF' > "${CRON_BETOR}"
# Varredura periódica de lançamentos nacionais no BeTor (a cada 6 horas)
0 */6 * * * root /usr/bin/docker exec prowlarr curl -s -X POST http://betor-scrapyd:6800/schedule.json -d project=betor -d spider=comando-torrents >/dev/null 2>&1
5 */6 * * * root /usr/bin/docker exec prowlarr curl -s -X POST http://betor-scrapyd:6800/schedule.json -d project=betor -d spider=bludv >/dev/null 2>&1
EOF
chmod 644 "${CRON_BETOR}"

# Garantir persistência e auto-start das stacks no boot do sistema via Systemd
log_info "Configurando serviço Systemd homelab-custom-stacks para inicialização automática no boot..."
SERVICE_FILE="/etc/systemd/system/homelab-custom-stacks.service"
cat << 'EOF' > "${SERVICE_FILE}"
[Unit]
Description=Stacks Docker Customizadas do Homelab (NPM, Dockge, Arr Stack, BeTor)
Requires=docker.service
After=docker.service mergerfs-storage.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/home/umbrel/umbrelos-scripts
ExecStartPre=/bin/sh -c "/usr/bin/docker network inspect homelab_network >/dev/null 2>&1 || /usr/bin/docker network create homelab_network"
ExecStart=/usr/bin/docker compose --env-file /home/umbrel/umbrelos-scripts/.env -f /home/umbrel/umbrelos-scripts/compose/management/docker-compose.yml up -d
ExecStart=/usr/bin/docker compose --env-file /home/umbrel/umbrelos-scripts/.env -f /home/umbrel/umbrelos-scripts/compose/arr-stack/docker-compose.yml up -d
ExecStart=/usr/bin/docker compose --env-file /home/umbrel/umbrelos-scripts/.env -f /home/umbrel/umbrelos-scripts/compose/betor/docker-compose.yml up -d
ExecStop=/usr/bin/docker compose -f /home/umbrel/umbrelos-scripts/compose/betor/docker-compose.yml stop
ExecStop=/usr/bin/docker compose -f /home/umbrel/umbrelos-scripts/compose/arr-stack/docker-compose.yml stop
ExecStop=/usr/bin/docker compose -f /home/umbrel/umbrelos-scripts/compose/management/docker-compose.yml stop

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable homelab-custom-stacks.service >/dev/null 2>&1 || true

log_success "Stacks Docker complementares iniciadas e registradas no boot com sucesso!"


