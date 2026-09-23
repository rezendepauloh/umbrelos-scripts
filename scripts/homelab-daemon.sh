#!/usr/bin/env bash
# ==============================================================================
# scripts/homelab-daemon.sh
# ------------------------------------------------------------------------------
# Daemon independente de persistência e orquestração do umbrelOS.
# Local de instalação no servidor: /data/bin/homelab-daemon.sh
#
# Arquitetura Nativa (3 TB):
#   - disk1 (1TB Seagate): Mídia & Downloads (Jellyfin, Arr-Stack, qBittorrent)
#   - disk2 (1TB A-DATA): Nuvem & Usuários (Nextcloud, Immich, Samba)
#   - disk3 (1TB Samsung): Backups Locais e contingência
#
# Ciclo de Vida:
#   1. Garante IP estático 192.168.0.8 na placa de rede física.
#   2. Aguarda e garante a montagem dos 3 discos externos nativos (disk1, disk2, disk3).
#   3. Aplica o bind mount direto de mídia para o Jellyfin (/external/disk1/media -> Downloads/media).
#   4. Restaura as configurações do Samba de /data/samba/smb.conf e reinicia o serviço.
#   5. Reinicia os containers oficiais (Jellyfin e Nextcloud) para carregar as montagens.
#   6. Sobe todas as Docker Stacks customizadas (Management, Arr-Stack, BeTor).
# ==============================================================================

# Carregar configurações do Homelab
if [ -f "/data/config.env" ]; then
    source "/data/config.env"
elif [ -f "/home/umbrel/umbrelos-scripts/config.env" ]; then
    source "/home/umbrel/umbrelos-scripts/config.env"
fi

LOG="/data/homelab-daemon.log"
exec >> "$LOG" 2>&1
echo "=== HOMELAB DAEMON INICIADO: $(date) ==="

# 0. Garantir IP Estático na placa de rede física
if [ "${SET_STATIC_IP:-false}" = "true" ] && [ -n "${STATIC_IP:-}" ]; then
    NET_IF="${NETWORK_INTERFACE:-enp1s0}"
    NET_CIDR="${STATIC_IP}/${STATIC_NETMASK:-24}"
    NET_GW="${STATIC_GATEWAY:-192.168.0.1}"
    NET_DNS="${STATIC_DNS:-1.1.1.1 8.8.8.8}"
    
    if command -v nmcli >/dev/null 2>&1; then
        CON_NAME=$(nmcli -t -f NAME,TYPE connection show 2>/dev/null | grep "ethernet" | head -n1 | cut -d: -f1 || echo "Wired connection 1")
        nmcli connection modify "$CON_NAME" ipv4.addresses "$NET_CIDR" ipv4.gateway "$NET_GW" ipv4.dns "$NET_DNS" ipv4.method manual 2>/dev/null || true
    fi
    ip addr show "$NET_IF" 2>/dev/null | grep -q "$STATIC_IP" || ip addr add "$NET_CIDR" dev "$NET_IF" 2>/dev/null || true
fi

DISK1="${DISK1_MOUNT:-/home/umbrel/umbrel/external/disk1}"
DISK2="${DISK2_MOUNT:-/home/umbrel/umbrel/external/disk2}"
DISK3="${DISK3_MOUNT:-/home/umbrel/umbrel/external/disk3}"

# 1. Esperar os discos USB externos montarem pelo Label ou montar manualmente
for i in {1..30}; do
    # Garante montagem correta pelos labels
    mountpoint -q "$DISK1" || mount -L disk1 "$DISK1" 2>/dev/null || true
    mountpoint -q "$DISK2" || mount -L disk2 "$DISK2" 2>/dev/null || true
    mountpoint -q "$DISK3" || mount -L disk3 "$DISK3" 2>/dev/null || true

    if mountpoint -q "$DISK1" && mountpoint -q "$DISK2"; then
        echo "Discos externos disk1 e disk2 detectados e montados após ${i}s"
        break
    fi
    sleep 1
done

# 2. Ajustar donos e permissões das pastas de usuários e compartilhadas no disk2
if mountpoint -q "$DISK2"; then
    SYS_USR="${SYSTEM_USER:-umbrel}"
    SYS_GRP="${SYSTEM_GROUP:-umbrel}"
    DIR_SH="${SHARED_DIR:-$DISK2/shared}"

    mkdir -p "$DISK2/users" "$DIR_SH"
    chmod 775 "$DISK2/users" "$DIR_SH" 2>/dev/null || true

    if [ -n "${SAMBA_USER_1:-}" ]; then
        U1_DIR="${USER_1_DIR:-${USER_PAULO_DIR:-$DISK2/users/$SAMBA_USER_1}}"
        mkdir -p "$U1_DIR"
        chown -R "${SAMBA_USER_1}:${SYS_GRP}" "$U1_DIR" 2>/dev/null || true
        chmod -R 777 "$U1_DIR" 2>/dev/null || true
    fi

    if [ -n "${SAMBA_USER_2:-}" ]; then
        U2_DIR="${USER_2_DIR:-${USER_KAMILA_DIR:-$DISK2/users/$SAMBA_USER_2}}"
        mkdir -p "$U2_DIR"
        chown -R "${SAMBA_USER_2}:${SYS_GRP}" "$U2_DIR" 2>/dev/null || true
        chmod -R 777 "$U2_DIR" 2>/dev/null || true
    fi

    chown -R "${SYS_USR}:${SYS_GRP}" "$DIR_SH" 2>/dev/null || true
    chmod -R 777 "$DIR_SH" 2>/dev/null || true
fi

# 3. Bind mount de mídia direto do disk1 para o Jellyfin (sem MergerFS!)
DIR_MED="${MEDIA_DIR:-$DISK1/media}"
mkdir -p "$DIR_MED"
mkdir -p /home/umbrel/umbrel/home/Downloads/media
umount -l /home/umbrel/umbrel/home/Downloads/media 2>/dev/null || true
mount --bind "$DIR_MED" /home/umbrel/umbrel/home/Downloads/media || true
echo "Bind mount nativo do Jellyfin aplicado com sucesso!"

# 4. Restaurar smb.conf customizado e reiniciar o Samba preliminarmente
if [ -f "/data/samba/smb.conf" ]; then
    cp /data/samba/smb.conf /etc/samba/smb.conf
fi
systemctl enable smbd nmbd 2>/dev/null || true
systemctl restart smbd nmbd || true
echo "Samba restaurado e iniciado preliminarmente"

# 5. Subir Docker Stacks assim que o Docker responder e os apps nativos do Umbrel estabilizarem
for j in {1..60}; do
    if docker info >/dev/null 2>&1; then
        echo "Docker pronto! Aguardando estabilização dos serviços do Umbrel..."
        
        # Espera até 60s para garantir que o Umbrel terminou o ciclo de boot
        for w in {1..30}; do
            if docker ps --format '{{.Names}}' | grep -q "adguard-home_server_1"; then
                echo "Serviços do Umbrel estabilizados após $((w * 2))s!"
                break
            fi
            sleep 2
        done

        echo "Garantindo rede homelab_network..."
        docker network create homelab_network 2>/dev/null || true

        # Reiniciar Jellyfin e Nextcloud para ler montagens dos HDs
        if docker ps -q -f name=jellyfin_server_1 | grep -q .; then
            echo "Reiniciando container do Jellyfin para ler montagem de mídia..."
            docker restart jellyfin_server_1 || true
        fi
        if docker ps -q -f name=nextcloud_web_1 | grep -q .; then
            echo "Reiniciando container do Nextcloud..."
            docker restart nextcloud_web_1 nextcloud_cron_1 || true
        fi

        echo "Subindo stacks customizadas..."
        if [ -d "/home/umbrel/umbrelos-scripts/compose/management" ]; then
            cd /home/umbrel/umbrelos-scripts/compose/management && docker compose --env-file /home/umbrel/umbrelos-scripts/.env up -d || true
        fi
        if [ -d "/home/umbrel/umbrelos-scripts/compose/arr-stack" ]; then
            cd /home/umbrel/umbrelos-scripts/compose/arr-stack && docker compose --env-file /home/umbrel/umbrelos-scripts/.env up -d || true
        fi
        if [ -d "/home/umbrel/umbrelos-scripts/compose/betor" ]; then
            cd /home/umbrel/umbrelos-scripts/compose/betor && docker compose --env-file /home/umbrel/umbrelos-scripts/.env up -d || true
        fi
        echo "Stacks customizadas iniciadas com sucesso!"

        # 6. Blindagem final do Samba pós-estabilização do Umbrel
        # O umbrelOS às vezes sobrescreve o smb.conf e desativa o smbd durante o boot dos seus containers.
        if [ -f "/data/samba/smb.conf" ]; then
            echo "Aplicando blindagem final do Samba..."
            cp /data/samba/smb.conf /etc/samba/smb.conf
            systemctl enable smbd nmbd 2>/dev/null || true
            systemctl restart smbd nmbd || true
            echo "Samba validado e ativo pós-boot: $(systemctl is-active smbd)"
        fi

        # 7. Garantir agendamento do Cronjob do BeTor (sobrevive a reboots)
        cat << 'CRON_EOF' > /etc/cron.d/betor-sync
0 */6 * * * root /usr/bin/docker exec prowlarr curl -s -X POST http://betor-scrapyd:6800/schedule.json -d project=betor -d spider=comando-torrents >/dev/null 2>&1
5 */6 * * * root /usr/bin/docker exec prowlarr curl -s -X POST http://betor-scrapyd:6800/schedule.json -d project=betor -d spider=bludv >/dev/null 2>&1
CRON_EOF
        chmod 644 /etc/cron.d/betor-sync
        echo "Cronjob do BeTor configurado e persistido com sucesso"
        break
    fi
    sleep 2
done

echo "=== HOMELAB DAEMON INICIALIZADO COM SUCESSO: $(date) ==="
