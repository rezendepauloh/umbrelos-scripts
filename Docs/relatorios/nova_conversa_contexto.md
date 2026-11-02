# Contexto Consolidado e Diretrizes de Trabalho: umbrelOS no Blackview MP100 Pro

> **Instrução para a IA em Novo Contexto:**
> Este documento representa o estado da arte e a verdade canônica do Homelab.
> Leia atentamente antes de propor qualquer intervenção.
>
> **Diretrizes obrigatórias de trabalho:**
> 1. **Mantenha os scripts e composes sincronizados:** Qualquer alteração validada no servidor deve ser imediatamente refletida no repositório (`scripts/`, `compose/`, `config/`).
> 2. **Instruções explícitas de terminal:** Sempre diferencie com clareza os comandos para o **Pop!_OS (Desktop)** dos comandos para o **SSH do mini PC (`umbrel@umbrel.local` / `192.168.0.8`)**.
> 3. **Arquitetura 100% Nativa (Sem MergerFS / Sem SnapRAID):** O sistema agora opera diretamente nas montagens do umbrelOS, garantindo estabilidade e 3 TB de armazenamento útil.

---

## 1. Hardware, Sistema e Topologia de Rede

- **Equipamento:** Mini PC Blackview MP100 Pro (Intel Core i5-12450H 12ª Ger, 16GB RAM DDR4, 1TB NVMe interno).
- **Sistema Operacional:** **umbrelOS 1.x** (Debian GNU/Linux 13 trixie / Debian snapshot, sistema com raiz imutável via Rugix OS).
- **Rede Local:**
  - **IP Fixo do mini PC:** `192.168.0.8` (Interface `enp1s0` fixada via NetworkManager no próprio mini PC).
  - **Limitação de Roteador (Claro Sagemcom `192.168.0.1`):** A operadora Claro bloqueia acesso administrativo HTTP/HTTPS ao roteador (`192.168.0.1`), impedindo reservas DHCP e configurações diretas de DNS no aparelho. Toda a gestão de IP fixo e DNS é garantida diretamente no mini PC e no AdGuard Home.
  - **IP do Desktop Pop!_OS:** `192.168.0.16` (Usuário: `rezendepauloh`).
  - **DNS Local Centralizado:** AdGuard Home (`http://192.168.0.8:8095`), wildcard `*.pk.local -> 192.168.0.8`.
  - **Nginx Proxy Manager:** `http://192.168.0.8:81` (Porta HTTP 8088 / HTTPS 8443).
  - **Rede Docker Compartilhada:** `homelab_network` (bridge compartilhada entre composes e apps da loja).

---

## 2. Topologia de Armazenamento Nativo (3 TB Úteis Reais)

Os discos são conectados via USB 3.0 e montados de forma nativa e direta pelo umbrelOS em `/home/umbrel/umbrel/external/`:

| Rótulo / Ponto de Montagem | Disco Físico | UUID | Função Principal | Serviços Conectados |
| :--- | :--- | :--- | :--- | :--- |
| **`disk1`** (`.../external/disk1`) | 1TB Seagate ext4 | `fc0b5d7b-1706-4461-9e1e-9d3f61e7bab0` | **Mídia & Torrents** | Jellyfin (`/media`), Radarr, Sonarr, qBittorrent |
| **`disk2`** (`.../external/disk2`) | 1TB A-DATA ext4 | `490440f1-8f2e-41fd-bc27-00632adec790` | **Nuvem & Usuários** | Nextcloud ("Meus Arquivos", "Compartilhado"), Samba, Immich |
| **`disk3`** (`.../external/disk3`) | 1TB Samsung ext4 | `e106affb-35da-4e93-a92d-e1ef5df32bb5` | **Backups Locais** | Backups locais, dumps de contingência |

- **Mapeamento Jellyfin:** Bind mount direto `/home/umbrel/umbrel/external/disk1/media -> /home/umbrel/umbrel/home/Downloads/media`.
- **Mapeamento Nextcloud:** Volumes montados diretamente em `/storage/users` e `/storage/shared` no `app-data/nextcloud/docker-compose.yml`.

---

## 3. Estado Atual dos Serviços e O que Já Foi Validado ✅

1. **Jellyfin:** 
   - 100% operacional lendo do `disk1`. Todos os episódios de séries tocam perfeitamente sem falhas.
2. **Nextcloud:** 
   - Volumes apontando diretamente para o `disk2`. Pastas "Meus Arquivos" e "Compartilhado" operacionais.
3. **Servidor Samba:** 
   - **100% Homologado e Estável!** 🚀
   - Arquivo canônico em `/data/samba/smb.conf` e credenciais em `/data/samba/passdb.tdb`.
   - Compartilhamentos ativos: `[Paulo]`, `[Kamila]`, `[Compartilhado]` (no `disk2`) e `[Midia]` (no `disk1`).
   - Blindagem dupla pós-boot implementada no daemon, evitando que o umbrelOS derrube o serviço ou sobrescreva o `smb.conf`.
4. **Boot Autônomo e Orquestração (100% Resolvido):**
   - Hook de pre-start ativa o daemon independente `/data/bin/homelab-daemon.sh`.
   - Redes Docker customizadas corrigidas com `external: true` na `homelab_network`.
   - 100% das 36 aplicações (nativas e customizadas) sobem automaticamente após reinicialização a frio.
5. **Estratégia de Backup Externo (Desktop Pop!_OS - Regra 3-2-1):**
   - Chave SSH configurada sem senha entre Umbrel e Pop!_OS (`rezendepauloh@192.168.0.16`).
   - Destino: `/mnt/storage_930/Backups_Homelab/` (mantém últimos 7 backups).
   - Script instalado em `/data/bin/backup-para-popos.sh`.
6. **Arr-Stack e Armazenamento Físico de Mídias (100% Homologado):** 🚀
   - Compose da `arr-stack` apontando nativamente para o `disk1` (sem MergerFS).
   - Jellyseerr atualizado para a versão moderna oficial **`v3.4.1` (Seerr)**.
   - Fuso horário configurado para `America/Campo_Grande` (UTC-4).
   - Fluxo completo de download e importação validado: `The Housemaid (2025)` baixado pelo qBittorrent e importado pelo Radarr para `/home/umbrel/umbrel/external/disk1/media/movies/`.
7. **Repositório Git Blindado e Código Desacoplado (100% Concluído):** 🔒
   - Auditoria de segurança completa antes do primeiro commit.
   - `.gitignore` robusto protegendo `config.env`, `.env`, `config/samba/smb.conf`, chaves SSH/certificados, logs e pastas `data/` de containers.
   - Modelos limpos e sanitizados criados: `config.env.example` e `config/samba/smb.conf.example`.
   - Removido todo e qualquer dado *hardcoded* dos scripts (`03_samba_setup.sh`, `homelab-daemon.sh`, `02_storage_setup.sh`, `06_backup_popos.sh`). O sistema consome dinamicamente as variáveis de `/data/config.env` ou `config.env`.
   - Links da documentação corrigidos para caminhos relativos em Markdown.

8. **Nextcloud 100% Homologado & Multiplataforma:** ☁️
   - Volumes mapeados com persistência no `disk2` (`/storage/users`, `/storage/shared`).
   - Acesso móvel e desktop via Tailscale (`trusted_domains` e `trusted_proxies`) 100% operacional.
   - Rotina de auto-injeção de volumes implementada no daemon para resistir a updates da loja do Umbrel.
   - Procedimento de reset/recuperação de senhas homologado via CLI (`occ user:resetpassword`).
9. **Dockge & Dozzle 100% Operacionais:** 📊
   - Dockge (`:5001`) gerenciando perfeitamente as stacks `management`, `arr-stack` e `betor`.
   - Dozzle (`:8888`) homologado para streaming em tempo real de logs e métricas de consumo de memória/CPU de todos os containers.
10. **Blindagem Contra Quedas de Energia & Suíte de Testes Automatizada:** 🛡️
   - O homelab foi blindado e testado com reinicialização real a frio: os 3 HDs externos sobem por UUID em 1s sem pastas duplicadas `*(2)`.
   - Samba protegido com atributo imutável (`chattr +i`) contra sobrescrita do `umbreld`.
   - Suíte de testes automatizada em Bash desenvolvida em `tests/run_all.sh` com 56 asserções cobrindo discos, rede, Samba, Docker e portas HTTP.

---

## 4. Foco Prioritário da Nova Conversa: Immich (Google Fotos Auto-Hospedado & Backup Mobile) 🎯

### 🚨 Prioridade 1: Configuração, Armazenamento no `disk2` e Backup Celular
- **Objetivo:** Estabelecer a central de backup de fotos e vídeos da família (substituindo Google Fotos e iCloud) através do **Immich**, garantindo:
  1. **Armazenamento no HD Externo (`disk2/immich`):** Garantir que os uploads, miniaturas e vídeos codificados sejam salvos no `disk2` com persistência blindada no `homelab-daemon.sh` contra atualizações da App Store do Umbrel.
  2. **Contas e Compartilhamento:** Criar o usuário Admin (`Paulo`), a conta de usuária (`Kamila`) e configurar o recurso de **Partner Sharing** (Compartilhamento de Parceiro com linha do tempo integrada).
  3. **Conexão Mobile (Android / iOS):** Configurar o aplicativo oficial do Immich nos smartphones com backup em segundo plano ativo tanto via Wi-Fi doméstico (`fotos.pk.local` / `192.168.0.8:2283`) quanto via **Tailscale** fora de casa.
  4. **Aceleração de Machine Learning:** Validar o container `immich_machine-learning_1` para reconhecimento facial e busca semântica em português (CLIP/Smart Search).

- **Status Atual dos Containers do Immich no Homelab:**
  - `immich_server_1`: Saudável (Porta `2283`)
  - `immich_machine-learning_1`: Saudável (Porta `3003`)
  - `immich_postgres_1`: Saudável (Vectorchord + pgvectors)
  - `immich_redis_1` & `immich_app_proxy_1`: Saudáveis e operacionais

---

## 5. Roteiro de Comandos para Diagnóstico Imediato

Ao iniciar a nova conversa sobre o Immich, execute no terminal do seu Pop!_OS:

```bash
# 1. Rodar a suíte de testes de integridade para confirmar 100% de saúde do Homelab
cd ~/Documentos/DevProjects/Bash/umbrelos-scripts
./tests/run_all.sh

# 2. Conferir status dos containers do Immich no mini PC
ssh -i ~/.ssh/id_ed25519 umbrel@192.168.0.8 "sudo docker ps --filter 'name=immich' --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"

# 3. Verificar permissões e armazenamento da pasta do Immich no disk2
ssh -i ~/.ssh/id_ed25519 umbrel@192.168.0.8 "ls -la /home/umbrel/umbrel/external/disk2/immich"
```
