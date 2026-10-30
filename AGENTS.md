# Diretrizes do Agente de IA (AGENTS.md) — Homelab umbrelOS

> **Atenção para qualquer Agente de IA trabalhando neste repositório:**
> Este documento é a referência canônica sobre a arquitetura do homelab, credenciais, topologia de rede, peculiaridades de hardware/sistema e protocolos de execução para operações e manutenções.

---

## 1. Topologia de Hardware e Rede

- **Servidor Mini PC:** Blackview MP100 Pro (Intel Core i5-12450H 12ª Ger, 16GB RAM DDR4, 1TB NVMe interno).
- **Desktop de Trabalho:** Pop!_OS (`192.168.0.16` / usuário: `rezendepauloh`).
- **Sistema Operacional do Servidor:** umbrelOS (baseado em Debian GNU/Linux com raiz imutável via Rugix OS).
- **Rede Local e Roteador (Claro Sagemcom `192.168.0.1`):**
  - **Limitação Crítica:** A operadora Claro bloqueia acesso administrativo HTTP/HTTPS ao aparelho da operadora (`192.168.0.1`), impossibilitando criar reservas DHCP ou alterar servidores de DNS diretamente no roteador.
  - **Estratégia Adotada:** O IP do mini PC é fixado estaticamente em **`192.168.0.8`** diretamente na interface física `enp1s0` via NetworkManager e scripts de boot (`homelab-daemon.sh`).
  - **DNS e Resolução Local:** O AdGuard Home (`192.168.0.8:8095`) atua como DNS local, resolvendo o wildcard `*.pk.local -> 192.168.0.8`.
  - **Proxy Reverso:** Nginx Proxy Manager (`192.168.0.8:81` / HTTP `8088` / HTTPS `8443`).
  - **Acesso Remoto:** Tailscale VPN (`100.88.159.41` / `umbrel.tail9accc5.ts.net`).

---

## 2. Acesso SSH, Sudo e Credenciais

- **Host do mini PC:** `192.168.0.8` (ou `umbrel.local`).
- **Usuário SSH:** `umbrel`.
- **Autenticação:**
  - Chave SSH configurada sem senha entre Pop!_OS e mini PC (`ssh umbrel@192.168.0.8`).
  - Chave SSH configurada sem senha do mini PC de volta para o Pop!_OS (`/home/umbrel/.ssh/id_ed25519 -> rezendepauloh@192.168.0.16`).
- **Elevação de Privilégios (Sudo/Root):**
  - A senha do usuário `umbrel` (e root via `sudo`) está centralizada na variável `SYSTEM_PASSWORD` em `config.env` (e em `/data/config.env` no servidor).
  - Em comandos remotos não interativos, execute via `echo "$SYSTEM_PASSWORD" | sudo -S <comando>`.

---

## 3. Arquitetura de Armazenamento Nativo (3 TB Úteis Reais)

Operamos em **arquitetura 100% nativa e direta**, sem camadas virtuais como MergerFS ou SnapRAID:

| Ponto de Montagem | Disco Físico | UUID | Papel / Serviços |
| :--- | :--- | :--- | :--- |
| **`disk1`** (`.../external/disk1`) | 1TB Seagate ext4 | `fc0b5d7b-1706-4461-9e1e-9d3f61e7bab0` | **Mídia & Downloads** (Jellyfin, Radarr, Sonarr, qBittorrent, BeTor) |
| **`disk2`** (`.../external/disk2`) | 1TB A-DATA ext4 | `490440f1-8f2e-41fd-bc27-00632adec790` | **Nuvem & Usuários** (Nextcloud, Immich, Samba shares) |
| **`disk3`** (`.../external/disk3`) | 1TB Samsung ext4 | `e106affb-35da-4e93-a92d-e1ef5df32bb5` | **Backups Locais** (Dumps locais, snapshots de contingência) |

### Particularidades de Armazenamento que o Agente DEVE Respeitar:
1. **Bind Mount do Jellyfin:** O Jellyfin oficial roda via container isolado e lê `/home/umbrel/umbrel/home/Downloads/media`, que recebe um bind mount direto de `/home/umbrel/umbrel/external/disk1/media` aplicado no boot pelo daemon.
2. **Injeção de Volumes no Nextcloud:** O daemon reinjeta os volumes `/storage/users` e `/storage/shared` no `docker-compose.yml` do Nextcloud caso updates da loja do Umbrel tentem removê-los.
3. **Anomalia de Queda de Energia (`disk1 (2)`):** Em reinicializações abruptas, o `umbreld` pode montar diretórios fantasmas com sufixo `(2)`. O `homelab-daemon.sh` já contém rotina de limpeza e remontagem forçada por UUID.

---

## 4. Stack de Aplicações e Serviços

### A. Apps Oficiais da Loja Umbrel (Gerenciados pelo umbrelOS)
- **Nextcloud** (Porta `:8081`): Nuvem de arquivos integrada com disk2.
- **Jellyfin** (Porta `:8096`): Servidor de mídia com transcodificação QuickSync (Intel Core 12ª Ger).
- **Immich** (Porta `:2283`): Galeria de fotos e IA de reconhecimento facial.
- **AdGuard Home** (Porta `:8095`): DNS sinkhole e apontamentos locais `*.pk.local`.
- **Home Assistant** (Porta `:8123`): Automação residencial.
- **Tailscale** (Porta interna): Acesso remoto seguro.

### B. Stacks Customizadas (Docker Compose)
Gerenciadas no diretório `/home/umbrel/umbrelos-scripts/compose/`:
- **Management:** `Dockge` (:5001), `Dozzle` (:8888), `Uptime Kuma` (:3001), `IT-Tools` (:8080), `Syncthing` (:8384).
- **Arr-Stack:** `Jellyseerr (Seerr)` (:5055), `Radarr` (:7878), `Sonarr` (:8989), `Prowlarr` (:9696), `Bazarr` (:6767), `qBittorrent` (:8085).
- **BeTor:** Scraper autônomo de trackers nacionais com spiders para comando-torrents e bludv, integrando ao Prowlarr via API local (:8000).
- **Projetos Pessoais:** `karteman`, `verifica-nomes-diarios-oficiais`, `paulo-investimentos-pessoais`.
- **Rede Compartilhada:** Todos os containers customizados comunicam-se pela bridge externa `homelab_network`.

### C. Servidor Samba Nativo
- Configuração canônica salva em `/data/samba/smb.conf`.
- Base de usuários em `/data/samba/passdb.tdb`.
- Compartilhamentos: `[Paulo]`, `[Kamila]`, `[Compartilhado]` (no `disk2`) e `[Midia]` (no `disk1`).
- **Atenção:** O `smb.conf` ativo em `/etc/samba/smb.conf` possui atributo imutável (`chattr +i`) para impedir que o daemon do Umbrel sobrescreva ou pare o serviço.

---

## 5. Regras Obrigatórias para os Agentes de IA

1. **Diferenciação Clara de Ambientes:**
   - Sempre declare explicitamente se um comando deve ser executado no **Pop!_OS (Desktop)** ou no **Mini PC via SSH (`umbrel@192.168.0.8`)**.
2. **Sincronia Repositório ↔ Servidor:**
   - O repositório canônico de desenvolvimento fica no Pop!_OS em `/home/rezendepauloh/Documentos/DevProjects/Bash/umbrelos-scripts/`.
   - O servidor espelha em `/home/umbrel/umbrelos-scripts/` e configurações persistentes em `/data/`.
   - Toda alteração validada no servidor deve ser comitada ou sincronizada no repositório local.
3. **Persistência Contra Atualizações do umbrelOS:**
   - Lembre-se de que a partição raiz (`/`) do umbrelOS é imutável via Rugix.
   - Qualquer arquivo ou configuração que precise persistir a reinicializações e updates de SO DEVE residir em `/data/` (ex: `/data/bin/`, `/data/samba/`, `/data/config.env`).
4. **Cuidado Extremo com Atualizações de Sistema:**
   - **Antes de qualquer upgrade de versão maior do umbrelOS (ex: 1.x para 2.0):**
     - O atributo imutável de `/etc/samba/smb.conf` DEVE ser temporariamente removido (`chattr -i`).
     - Backups completos de bancos (Immich, Nextcloud) e pastas críticas de apps (Jellyfin data) DEVEM ser efetuados e enviados para o Pop!_OS (`/mnt/storage_930/Backups_Homelab`).
5. **Segurança e .gitignore:**
   - NUNCA versione arquivos contendo senhas reais ou chaves privadas (`config.env`, `.env`, `smb.conf` com dados sensíveis). Use sempre os templates `.example`.

