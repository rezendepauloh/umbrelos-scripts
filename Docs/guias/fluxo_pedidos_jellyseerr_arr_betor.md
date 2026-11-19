# 🎬 Fluxo Diário de Pedidos e Downloads (Jellyseerr → Arr-Stack → BeTor → Hardlinks)

Guia prático do fluxo recomendado para pedir filmes e séries em **Dual Áudio (PT-BR / EN)** sem duplicar espaço no `disk1`.

---

## 1. Fluxo Padrão (Automático)

```
Jellyseerr (pedidos.pk.local / :5055)
   │
   ▼ envia o pedido
Radarr (Filmes :7878) / Sonarr (Séries :8989)
   │
   ▼ busca nos indexadores (BeTor Priority=1 + Custom Format Dual Audio +1500)
Prowlarr (:9696) ──▶ Catálogo BeTor (betor-api:8000) / YTS / TPB
   │
   ▼ envia o magnet (categoria radarr / tv-sonarr)
qBittorrent (:8085) ──▶ salva em /media/torrents/
   │
   ▼ ao concluir 100%, Radarr/Sonarr criam hardlink automático
/media/movies/ ou /media/series/ ──▶ Jellyfin (:8096)
```

> [!IMPORTANT]
> **Não use o botão *"Add release to download client"* direto no Prowlarr** para filmes/séries que você quer no Jellyfin. O Prowlarr apenas joga o torrent na categoria `prowlarr` sem avisar o Radarr/Sonarr, então o arquivo não é renomeado nem recebe hardlink automático.

---

## 2. Como Conferir ou Trocar um Release Escolhido

1. **Peça o título no Jellyseerr** (`pedidos.pk.local` ou `:5055`).
2. **Confira no Radarr (`:7878`), Sonarr (`:8989`) ou qBittorrent (`:8085`)** qual release foi iniciado.
3. **Se não for a versão desejada** (ex.: veio apenas em inglês ou tamanho inadequado):
   - No **qBittorrent**, cancele e exclua o torrent (marcando para apagar os arquivos temporários) — ou remova pela aba **Activity** do Radarr/Sonarr.
   - No **Radarr/Sonarr**, entre na página do filme/série e clique em **Interactive Search (👤🔍)**.
   - Escolha manualmente o release desejado (ex.: `Catálogo BeTor`, `WEBDL-1080p`, `+1500`, `DUAL`) clicando no ícone de download à direita.
4. Quando o download terminar no qBittorrent, o Radarr/Sonarr criam o **hardlink** automático em `/media/movies/` ou `/media/series/`, mantendo o seed ativo em `/media/torrents/` com **1x** o espaço em disco.

---

## 3. Regras Ativas de Priorização

- **Indexador Principal:** `Catálogo BeTor` configurado com **Prioridade `1`** no Prowlarr, Radarr e Sonarr (TPB `25`, YTS/1337x/EZTV `50`).
- **Custom Format (`Dual Audio PT-BR`):** pontuação **`+1500`** em todos os perfis de qualidade do Radarr e Sonarr para releases contendo `DUAL`, `DUBLADO`, `PT-BR`, `BRAZILIAN`, `PORTUGUESE` ou `NACIONAL`.
- **Proteção contra arquivos gigantes:** `Remux-1080p` desabilitado no perfil `HD-1080p` do Radarr.

---

## 4. Se Baixar Algo Manualmente

Se baixar algum torrent fora do Radarr/Sonarr (ou direto pelo Prowlarr):
- Para organizar no Jellyfin sem duplicar espaço, use o utilitário [deduplicacao_hardlinks_disk1.md](deduplicacao_hardlinks_disk1.md):
  ```bash
  ./scripts/utils/homelab_hardlinks.sh link "<origem_em_torrents>" "<destino_em_movies_ou_series>"
  ```
