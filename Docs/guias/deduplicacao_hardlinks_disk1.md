# 🔗 Deduplicação e Hardlinks no `disk1` (`homelab_hardlinks.sh`)

Guia de operação para manter o seed ativo no **qBittorrent** e a biblioteca organizada no **Jellyfin / Radarr / Sonarr** ocupando **apenas 1x o espaço em disco** no `/home/umbrel/umbrel/external/disk1/media`.

---

## 1. Como funciona na arquitetura da `arr-stack`

- Todos os containers da stack (`qbittorrent`, `radarr`, `sonarr` e `bazarr`) montam o mesmo ponto raiz:
  - Host: `/home/umbrel/umbrel/external/disk1/media`
  - Container: `/media`
- Subpastas unificadas dentro de `/media`:
  - `/media/torrents` (downloads e seeds do qBittorrent)
  - `/media/movies` (Root Folder do Radarr)
  - `/media/series` (Root Folder do Sonarr)
- Como tudo está sob o mesmo bind mount `/media` no mesmo sistema de arquivos `ext4`, novas importações automáticas do **Radarr** e **Sonarr** criam **hardlinks** nativamente em vez de copiar arquivos fisicamente.
- Para compatibilidade com seeds antigos iniciados antes da unificação, o `qbittorrent` mantém também `/downloads` mapeado e o Radarr/Sonarr possuem *Remote Path Mapping* de `/downloads/` → `/media/torrents/`.

> [!NOTE]
> Um **hardlink** faz dois caminhos diferentes apontarem para o mesmo conjunto de dados (mesmo inode no `ext4`). Você pode renomear ou mover o arquivo dentro de `movies/` ou `series/` para o padrão do Jellyfin sem quebrar o seed em `torrents/`, e apagar um dos lados não apaga o outro.

---

## 2. Utilitário `scripts/utils/homelab_hardlinks.sh`

Pode ser executado tanto do **Pop!_OS** (ele se conecta automaticamente ao Mini PC via SSH) quanto diretamente no **Mini PC** (`/home/umbrel/umbrelos-scripts/scripts/utils/homelab_hardlinks.sh`).

### A. Verificar status atual (somente leitura, instantâneo)
```bash
./scripts/utils/homelab_hardlinks.sh status
```
Lista quantos arquivos `>= 10 MiB` em `torrents/`, `movies/` e `series/` já estão em hardlink e quantos são candidatos à deduplicação.

### B. Simular e aplicar deduplicação em cópias já existentes
1. **Simulação rápida (`--dry-run --fast`):** valida por tamanho exato + SHA-256 de 3 blocos de 1 MiB (início, meio e fim) — leva poucos segundos:
```bash
./scripts/utils/homelab_hardlinks.sh dedup --dry-run --fast
```
2. **Aplicação em modo rápido (`--apply --fast`):** substitui as cópias duplicadas em `movies/` e `series/` por hardlinks apontando para o inode em `torrents/`:
```bash
./scripts/utils/homelab_hardlinks.sh dedup --apply --fast
```
3. **Verificação completa byte a byte (opcional, mais lenta em HD USB):** remova a flag `--fast` para calcular o SHA-256 inteiro de cada arquivo candidato antes de substituir:
```bash
./scripts/utils/homelab_hardlinks.sh dedup --apply
```

> [!TIP]
> O script ignora automaticamente downloads incompletos (`.!qB` e pasta `incomplete/`), arquivos menores que `10 MiB` (configurável via `--min-mb`) e arquivos que já compartilham o mesmo inode (`nlink > 1`).

### C. Organizar downloads manuais futuros sem duplicar espaço
Quando baixar um torrent manualmente no qBittorrent (em `/home/umbrel/umbrel/external/disk1/media/torrents/`) e quiser colocá-lo no Jellyfin com nome organizado:

- **Para arquivo único (ex.: filme `.mkv`):**
```bash
./scripts/utils/homelab_hardlinks.sh link \
  "/home/umbrel/umbrel/external/disk1/media/torrents/Filme.2026.1080p.DUAL.mkv" \
  "/home/umbrel/umbrel/external/disk1/media/movies/Filme [2026] [1080p] [DUAL]/Filme [2026] [1080p] [DUAL].mkv"
```
- **Para pasta inteira (ex.: temporada de série):**
```bash
./scripts/utils/homelab_hardlinks.sh link \
  "/home/umbrel/umbrel/external/disk1/media/torrents/Minha.Serie.S01.1080p" \
  "/home/umbrel/umbrel/external/disk1/media/series/Minha Serie/Season 01"
```
  Após criar o hardlink, você pode renomear os arquivos dentro de `Season 01` livremente para o padrão do Jellyfin sem afetar o seed no qBittorrent.

