# Persistência de Volumes e Bind Mounts após Updates da Loja do umbrelOS

Quando aplicativos oficiais da loja do umbrelOS (como **Nextcloud** e **Jellyfin**) são atualizados pelo painel, o `umbreld` regenera o `docker-compose.yml` do aplicativo. Nesse processo, mapeamentos customizados (como os volumes `/storage/users` e `/storage/shared` do `disk2` no Nextcloud) podem ser removidos.

Para resolver isso de forma **automática** (Opção 1) e **manual sob demanda** (Opção 3), o homelab conta com dois mecanismos integrados ao `homelab-daemon.sh`.

---

## 1. Modo Automático (`systemd.path` Watcher)

O servidor (`192.168.0.8`) possui um watcher do `systemd` monitorando o arquivo `/home/umbrel/umbrel/app-data/nextcloud/docker-compose.yml`:

- **Unit `.path`:** `/etc/systemd/system/homelab-fix-mounts.path`
- **Unit `.service`:** `/etc/systemd/system/homelab-fix-mounts.service`

Sempre que a loja do Umbrel atualizar o Nextcloud e sobrescrever o `docker-compose.yml`, o `systemd` detecta a alteração e executa automaticamente:

```bash
/data/bin/homelab-daemon.sh --fix-mounts
```

Esse modo rápido (`--fix-mounts`) **não** reinicia rede, Samba ou outras stacks customizadas — ele apenas verifica e reaplica:
1. O bind mount de mídia do **Jellyfin** (`/home/umbrel/umbrel/external/disk1/media` → `/home/umbrel/umbrel/home/Downloads/media`).
2. O bind mount de fotos/uploads do **Immich** (`/home/umbrel/umbrel/external/disk2/immich/upload` → `/home/umbrel/umbrel/app-data/immich/data/upload`).
3. Os volumes do `disk2` (`/storage/users` e `/storage/shared`) no `docker-compose.yml` do **Nextcloud**, recriando os containers do Nextcloud caso tenham sido removidos.

---

## 2. Modo Manual (Caso dê alguma zebra)

Se após atualizar qualquer app da loja do Umbrel você notar que o Nextcloud, o Immich ou o Jellyfin perderam acesso aos discos externos, basta rodar **diretamente do Pop!_OS (Desktop)**:

```bash
./scripts/utils/homelab_fix_mounts.sh
```

Esse script já conecta via SSH no servidor (`umbrel@192.168.0.8`), executa `sudo /data/bin/homelab-daemon.sh --fix-mounts` usando o `config.env` local e exibe as últimas linhas do `/data/homelab-daemon.log`.

---

## 3. Verificação e Manutenção do Watcher no Servidor

Comandos úteis no **Mini PC via SSH (`umbrel@192.168.0.8`)**:

```bash
# Verificar se o watcher automático está ativo
systemctl status homelab-fix-mounts.path

# Ver logs do serviço que aplica a correção
journalctl -u homelab-fix-mounts.service -n 20 --no-pager
```

> [!NOTE]
> Como a partição raiz (`/`) do umbrelOS é imutável (Rugix OS), após um upgrade de versão maior do sistema operacional (ex: `1.x` → `2.0`), verifique com `systemctl status homelab-fix-mounts.path` se as units em `/etc/systemd/system/` continuam ativas.
