#!/usr/bin/env bash
# ==============================================================================
# scripts/01_system_prep.sh - Preparação e Diagnóstico do Sistema
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "${SCRIPT_DIR}/lib/common.sh" ]] && source "${SCRIPT_DIR}/lib/common.sh"
[[ -f "${SCRIPT_DIR}/config.env" ]] && source "${SCRIPT_DIR}/config.env"

log_step "Módulo 1: Atualização do Sistema e Instalação de Utilitários"

# Configuração de Fuso Horário
log_info "Configurando fuso horário para ${TIMEZONE}..."
timedatectl set-timezone "${TIMEZONE}" || true

# Atualização de Repositórios e Pacotes Base
log_info "Atualizando listas de pacotes APT..."
apt-get update -y

log_info "Instalando utilitários essenciais de sistema, diagnóstico de hardware e rede..."
PACKAGES=(
    curl
    wget
    git
    rsync
    htop
    iotop
    samba
    samba-common-bin
    smbclient
    cifs-utils
    mergerfs            # Pool virtual de discos (junta disk1 + disk2)
    snapraid            # Paridade e recuperação de falha de disco sem RAID clássico
    smartmontools       # Monitoramento S.M.A.R.T. de saúde dos HDs externos e NVMe
    hdparm              # Gerenciamento de energia/spindown de discos USB
    nvme-cli            # Diagnóstico do NVMe interno de 1TB
    lm-sensors          # Monitoramento de temperatura do i5-12450h
    ufw                 # Firewall simples
    fail2ban            # Proteção contra ataques de força bruta no SSH
    ca-certificates
    gnupg
    lsb-release
    jq
)

apt-get install -y --no-install-recommends "${PACKAGES[@]}"

# Otimização de Parâmetros de Kernel (sysctl) para Homelab / Servidor de Arquivos
log_info "Aplicando otimizações de I/O e limites de rede no kernel..."
SYSCTL_CONF="/etc/sysctl.d/99-umbrel-homelab.conf"

SYSCTL_PAYLOAD="
# Otimizações para transferências volumosas em rede e Docker
fs.file-max = 2097152
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 8192
vm.swappiness = 10
vm.dirty_background_ratio = 5
vm.dirty_ratio = 10
# Sincronização periódica rápida de buffers para o disco (reduz perda de dados em queda de luz)
vm.dirty_writeback_centisecs = 500
vm.dirty_expire_centisecs = 1500
net.core.somaxconn = 4096
net.ipv4.tcp_fastopen = 3
"

ensure_config_block "SYSCTL_TWEAKS" "$SYSCTL_CONF" "$SYSCTL_PAYLOAD"
sysctl --system >/dev/null 2>&1 || true

# Configuração do Systemd Journald para resistir a dirty shutdowns no NVMe
log_info "Configurando persistência e flush seguro do Systemd Journald..."
JOURNALD_CONF="/etc/systemd/journald.conf.d/99-homelab-crash-resilience.conf"
JOURNALD_PAYLOAD="
[Journal]
Storage=persistent
SyncIntervalSec=1m
SystemMaxUse=500M
"
ensure_dir "/etc/systemd/journald.conf.d" "root" "root" "755"
ensure_config_block "JOURNALD_CRASH_RESILIENCE" "$JOURNALD_CONF" "$JOURNALD_PAYLOAD"
systemctl restart systemd-journald >/dev/null 2>&1 || true

# Configuração de Gerenciamento de Energia: Modo Servidor 24/7 (Preserva Idle da CPU sem suspender/dormir)
log_info "Configurando políticas de energia 24/7 (desativando suspensão/hibernação e mantendo C-States Idle)..."
LOGIND_CONF="/etc/systemd/logind.conf.d/99-homelab-nosleep.conf"
LOGIND_PAYLOAD="
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleSuspendKey=ignore
HandleHibernateKey=ignore
IdleAction=ignore
"
ensure_dir "/etc/systemd/logind.conf.d" "root" "root" "755"
ensure_config_block "HOMELAB_NOSLEEP" "$LOGIND_CONF" "$LOGIND_PAYLOAD"
systemctl restart systemd-logind >/dev/null 2>&1 || true

# Mascarar alvos do Systemd que acionam Suspensão/Hibernação
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target >/dev/null 2>&1 || true

log_success "Sistema base, energia 24/7 e utilitários preparados com sucesso!"

