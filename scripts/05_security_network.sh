#!/usr/bin/env bash
# ==============================================================================
# scripts/05_security_network.sh - Segurança, Firewall e Conectividade
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "${SCRIPT_DIR}/lib/common.sh" ]] && source "${SCRIPT_DIR}/lib/common.sh"
[[ -f "${SCRIPT_DIR}/config.env" ]] && source "${SCRIPT_DIR}/config.env"

log_step "Módulo 5: Configuração de Segurança, Firewall e Tailscale"

# 1. Configuração do SSH
log_info "Verificando serviço SSH..."
systemctl enable ssh >/dev/null 2>&1 || systemctl enable sshd >/dev/null 2>&1 || true

# Configurações recomendadas de SSH KeepAlive (evita desconexões em sessões remotas)
SSHD_CONFIG="/etc/ssh/sshd_config.d/99-umbrel-homelab.conf"
SSHD_BLOCK="
ClientAliveInterval 60
ClientAliveCountMax 3
TCPKeepAlive yes
"
ensure_config_block "SSH_KEEPALIVE" "$SSHD_CONFIG" "$SSHD_BLOCK"
systemctl reload ssh >/dev/null 2>&1 || systemctl reload sshd >/dev/null 2>&1 || true

# 2. Configuração do Firewall (UFW)
log_info "Configurando regras padrão de firewall (UFW)..."
ufw default allow outgoing >/dev/null 2>&1 || true

# Permitir portas críticas locais
ufw allow 22/tcp comment 'SSH' || true
ufw allow 80/tcp comment 'HTTP / Umbrel Web UI' || true
ufw allow 443/tcp comment 'HTTPS' || true
ufw allow 445/tcp comment 'Samba SMB' || true
ufw allow 139/tcp comment 'Samba NetBIOS' || true
ufw allow 137,138/udp comment 'Samba NetBIOS Name Service' || true
ufw allow 22000/tcp comment 'Syncthing File Transfer' || true
ufw allow 22000/udp comment 'Syncthing File Transfer' || true
ufw allow 21027/udp comment 'Syncthing Local Discovery' || true
ufw allow 81/tcp comment 'Nginx Proxy Manager Admin' || true
ufw allow 8088/tcp comment 'Nginx Proxy Manager HTTP' || true
ufw allow 8443/tcp comment 'Nginx Proxy Manager HTTPS' || true

# Habilitar UFW caso o usuário queira
log_info "Status atual do UFW:"
ufw status verbose || true

# 3. Configuração de IP Estático (Garantia de IP Fixo no Boot)
if [[ "${SET_STATIC_IP:-false}" == "true" && -n "${STATIC_IP:-}" ]]; then
    log_info "Configurando IP estático persistente (${STATIC_IP}/${STATIC_NETMASK:-24}) no NetworkManager..."
    CON_NAME=$(nmcli -t -f NAME,TYPE connection show | grep "ethernet" | head -n1 | cut -d: -f1 || true)
    if [[ -n "$CON_NAME" ]]; then
        nmcli connection modify "$CON_NAME" \
            ipv4.addresses "${STATIC_IP}/${STATIC_NETMASK:-24}" \
            ipv4.gateway "${STATIC_GATEWAY:-192.168.0.1}" \
            ipv4.dns "${STATIC_DNS:-127.0.0.1 1.1.1.1}" \
            ipv4.method manual || true
        nmcli connection up "$CON_NAME" >/dev/null 2>&1 || true
        log_success "IP Estático [${STATIC_IP}] fixado na conexão [${CON_NAME}] com sucesso!"
    else
        log_warn "Conexão ethernet cabeada não identificada no NetworkManager. Pulando fixação estática automática."
    fi
fi

# 4. Redirecionamento da Porta 80 para o Nginx Proxy Manager (Porta 8088)
# Permite acessar domínios locais sem digitar portas no navegador
log_info "Configurando redirecionamento da porta 80 para a porta 8088 do NPM via Systemd..."
DETECTED_IF=$(ip route show default 2>/dev/null | awk '{print $5}' | head -n1 || true)
TARGET_IF="${NETWORK_INTERFACE:-${DETECTED_IF:-enp1s0}}"
log_info "Interface de rede detectada para redirecionamento: ${TARGET_IF}"

SERVICE_FILE="/etc/systemd/system/homelab-port80-redirect.service"
cat << EOF > "$SERVICE_FILE"
[Unit]
Description=Redirecionamento de Porta 80 para NPM (8088)
After=network.target docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/sbin/iptables -t nat -A PREROUTING -i ${TARGET_IF} -p tcp --dport 80 -j REDIRECT --to-port ${NPM_HTTP_PORT:-8088}
ExecStop=/sbin/iptables -t nat -D PREROUTING -i ${TARGET_IF} -p tcp --dport 80 -j REDIRECT --to-port ${NPM_HTTP_PORT:-8088}

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now homelab-port80-redirect.service >/dev/null 2>&1 || true
log_success "Serviço de redirecionamento de porta 80 -> 8088 ativado via Systemd com sucesso!"

# 3. Permissões de Docker para o usuário do sistema
if id "${SYSTEM_USER:-umbrel}" >/dev/null 2>&1; then
    usermod -aG docker "${SYSTEM_USER:-umbrel}" 2>/dev/null || true
fi

# 4. Verificação do Tailscale
log_info "Verificando presença do Tailscale..."
if docker ps --format '{{.Names}}' 2>/dev/null | grep -qi "tailscale"; then
    log_success "Tailscale oficial do umbrelOS detectado e ativo (App Store)! Porta web: 8240"
elif command_exists tailscale; then
    log_success "Tailscale CLI detectado no sistema."
else
    log_info "Tailscale pode ser instalado via App Store do umbrelOS (recomendado) ou via CLI."
fi

log_success "Segurança e rede configuradas com sucesso!"
