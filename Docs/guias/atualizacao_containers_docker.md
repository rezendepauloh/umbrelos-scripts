# Guia de Atualização de Containers Docker no Homelab

Este guia explica como atualizar de forma segura e automatizada todos os containers das stacks customizadas do homelab (incluindo **Dozzle**, **Dockge**, **Uptime Kuma**, **Arr-Stack**, **BeTor** e **Túneis**), além de diferenciar o que é atualizado via script e o que é atualizado pela loja do umbrelOS.

---

## 1. Script Unificado de Atualização

O repositório já possui o script canônico:
- [`scripts/utils/homelab_atualizar_stacks.sh`](scripts/utils/homelab_atualizar_stacks.sh)

Ele pode ser executado **diretamente do Pop!_OS (Desktop)** — conectando via SSH no Mini PC (`192.168.0.8`) — ou localmente no próprio servidor.

### O que ele faz:
1. Carrega o arquivo de ambiente canônico (`/data/config.env`) e garante o symlink `.env`.
2. Percorre todas as stacks customizadas em `/home/umbrel/umbrelos-scripts/compose/`:
   - `management` (Dockge, **Dozzle**, Uptime Kuma, IT-Tools, Syncthing)
   - `arr-stack` (Jellyseerr, Radarr, Sonarr, Prowlarr, Bazarr, qBittorrent, Flaresolverr)
   - `tunnels` (túneis zrok / acesso remoto)
   - `betor` (BeTor API, Scrapyd, Workers, MongoDB, Redis)
3. Executa `docker compose --env-file /data/config.env pull` para baixar novas imagens.
4. Executa `docker compose --env-file /data/config.env up -d` — **recriando apenas os containers que realmente tiveram atualização de imagem**, preservando volumes e configurações.
5. Remove imagens órfãs antigas (`docker image prune -f`) para não desperdiçar espaço no NVMe.

---

## 2. Como Usar (Pop!_OS)

No diretório raiz do repositório (`~/Documentos/DevProjects/Bash/umbrelos-scripts`):

### Atualização completa (padrão)
```bash
./scripts/utils/homelab_atualizar_stacks.sh
```

### Simulação (`--dry-run`)
Para apenas verificar quais stacks seriam verificadas sem alterar nada:
```bash
./scripts/utils/homelab_atualizar_stacks.sh --dry-run
```

### Atualizar sem remover imagens antigas (`--no-prune`)
```bash
./scripts/utils/homelab_atualizar_stacks.sh --no-prune
```

---

## 3. E os Apps Oficiais da Loja Umbrel?

Os apps instalados pela **App Store do umbrelOS** (como **Nextcloud**, **Jellyfin**, **Immich**, **AdGuard Home**, **Home Assistant**, **Tailscale**) são gerenciados diretamente pelo daemon do umbrelOS.

- **Não** os atualize manualmente via `docker compose pull` fora da loja, pois o umbrelOS gerencia versões, migrações de banco e volumes próprios.
- Para atualizá-los, acesse o painel web do umbrelOS (`http://192.168.0.8` ou `http://umbrel.local`) e clique em **Update** quando houver atualização disponível.

---

## 4. Limpeza Adicional e Saúde Pós-Atualização

Após atualizar as stacks, você pode verificar se todos os containers subiram saudáveis com:
```bash
./scripts/utils/homelab_dashboard_saude.sh
```

Caso precise fazer uma limpeza mais profunda de cache de build ou volumes não utilizados:
```bash
./scripts/utils/homelab_limpeza_docker.sh
```

