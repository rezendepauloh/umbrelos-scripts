# Pendências e Tarefas em Aberto (Homelab umbrelOS)

Este documento centraliza todas as pendências identificadas, pontos de atenção e próximos passos de testes para o ecossistema do **umbrelOS** no **Blackview MP100 Pro**.

---

## 🎯 Issue 1: Integração BeTor ↔ Prowlarr ↔ Sonarr / Radarr (CONCLUÍDO / HOMOLOGADO ✅)

### 📌 Status
- **Status:** **Resolvido e Homologado!** 🎉
- A definição do **Catálogo BeTor** local (`betor.yml`) foi corrigida e blindada contra campos nulos (`torrent_size`) e chaves ausentes.
- Comunicação interna rápida via `http://betor-api:8000` operando sem Cloudflare.
- Mapeamento de categorias ajustado (`5000: TV`, `2000: Movies`), permitindo ao Sonarr encontrar e pontuar os episódios nacionais em Dual Áudio 5.1.
- Rotina periódica de raspagem configurada via cronjob no host (`/etc/cron.d/betor-sync`) a cada 6 horas, com persistência automática pós-boot no `homelab-daemon.sh`.

---

## 🎯 Issue 2: Caminhos e Destinos de Download da Arr-Stack (CONCLUÍDO / HOMOLOGADO ✅)

### 📌 Status
- **Status:** **Resolvido e Homologado!** 🎉
- Compose da `arr-stack` totalmente alinhado com a nova arquitetura sem MergerFS:
  - `qbittorrent`: `/downloads` apontando diretamente para `/home/umbrel/umbrel/external/disk1/media/torrents`.
  - `radarr`: `/movies` apontando para `/home/umbrel/umbrel/external/disk1/media/movies` e `/downloads` para `/torrents`.
  - `sonarr`: `/tv` apontando para `/home/umbrel/umbrel/external/disk1/media/series` e `/downloads` para `/torrents`.
  - `jellyseerr`: migrado para a imagem oficial moderna **`ghcr.io/seerr-team/seerr:latest` (v3.4.1)**.
  - Fuso horário padronizado para `TZ=America/Campo_Grande` (UTC-4).
- Fluxo de download até o disco validado:
  `Jellyseerr (Seerr) -> Prowlarr/BeTor -> Radarr/Sonarr -> qBittorrent -> disk1/media/movies` (Filme *The Housemaid* de 7.5 GB importado com sucesso para a pasta física de filmes).

---

## 🚨 Issue 3 (Pendente): Auto-Refresh do Jellyfin via Notificação da Arr-Stack (Radarr/Sonarr Connect)

### 📌 Problema Identificado:
- O Radarr e o Sonarr realizam o download e importam o arquivo perfeitamente para `/home/umbrel/umbrel/external/disk1/media/movies` (que no Jellyfin é `/downloads/media/movies`).
- No entanto, a atualização da biblioteca (*Library Refresh*) não está acontecendo de forma instantânea/automática após o término do download:
  1. A notificação via API do Jellyfin configurada em **Settings > Connect** (Radarr/Sonarr) precisa ser validada no momento exato do trigger de importação (`On File Import` / `On Upgrade`).
  2. O monitoramento em tempo real do sistema de arquivos (*inotify*) do Jellyfin dentro do container oficial da App Store do Umbrel não detecta eventos de bind mount automaticamente sem um trigger externo da API (`/Library/Refresh`).
- **Objetivo:**
  - Garantir que a notificação enviada pelo Radarr/Sonarr faça o Jellyfin atualizar a biblioteca imediatamente após o download, sem necessidade de clicar manualmente em *"Rastrear Todas as Bibliotecas"*.

---

## 🚨 Issue 4 (Pendente): Configuração e Validação de Legendas PT-BR no Bazarr

### 📌 Problema Identificado:
- O Bazarr está rodando na porta `:6767`, mas ainda precisa ser homologado no fluxo prático:
  1. Conectar as API Keys do Radarr e Sonarr dentro do Bazarr.
  2. Configurar provedores gratuitos de legendas (OpenSubtitles.com, Subdl, Legendas.tv).
  3. Garantir o download automático de arquivos `.srt` em Português do Brasil (`pt-BR`) salvos lado a lado com os arquivos de vídeo no `disk1/media`.
- **Objetivo:**
  - Homologar o fluxo para que todo filme ou episódio recém-importado receba legenda em português automaticamente sem intervenção manual.

### 🧪 Próximo Passo Rápido:
- [ ] Testar busca interativa (👤🔍) ou download com outra série qualquer no Sonarr (ex: *House of the Dragon*, *Lanternas* ou *The Last of Us*) para atestar a continuidade dos downloads automáticos.

---

## 🧪 Issue 2: Bateria de Testes e Validação dos Demais Serviços

Precisamos rodar testes práticos de ponta a ponta e validar as configurações dos seguintes serviços instalados:

### 1. Dockge (`http://dockge.pk.local` ou porta `:5001`)
- [ ] Validar se as stacks `management`, `arr-stack` e `betor` aparecem corretamente na interface.
- [ ] Testar a edição de compose, visualização de logs em tempo real e comandos de Start / Stop / Restart pelo navegador.

### 2. Uptime Kuma (`http://status.pk.local` ou porta `:3001`)
- [ ] Criar conta de administrador inicial.
- [ ] Cadastrar os monitores HTTP para todos os serviços internos (`jellyfin.pk.local`, `sonarr.pk.local`, `radarr.pk.local`, `umbrel.local`, etc.).
- [ ] Validar se os pings e status de disponibilidade ficam verdes no dashboard.

### 3. Nextcloud (`http://nuvem.pk.local` ou porta `:8081`) (CONCLUÍDO / HOMOLOGADO ✅)
- [x] Acesso web e onboarding do administrador `umbrel` concluídos.
- [x] Contas pessoais criadas para `paulo` e `kamila` com senhas seguras.
- [x] App `files_external` ativado e integrado com armazenamento nos HDs externos (`disk1`).
- [x] Pastas `Meus Arquivos` (privadas) e `Compartilhado` integradas de ponta a ponta com os compartilhamentos Samba (`smb://192.168.0.8/Paulo`, `Kamila`, `Compartilhado`).
- [x] Volumes persistentes mapeados no Compose oficial (`/home/umbrel/umbrel/app-data/nextcloud/docker-compose.yml`).
- [x] Permissões e rotinas de automação atualizadas no `homelab-daemon.sh`.

### 4. Immich (`http://fotos.pk.local` ou porta `:2283`)
- [ ] Testar primeiro login no Immich.
- [ ] Validar se o upload de fotos está apontando para o armazenamento no MergerFS (`/mnt/storage/immich/upload`).
- [ ] Testar o app mobile (Android / iOS) conectado no domínio local e via Tailscale.

### 5. Home Assistant (`http://home.pk.local` ou porta `:8123`)
- [ ] Acessar e criar conta de administrador inicial.
- [ ] Validar descoberta automática de dispositivos da rede local (Smart TVs Samsung, lâmpadas, roteadores).

### 6. IT-Tools (`http://it.pk.local` ou porta `:8080`)
- [ ] Validar carregamento das ferramentas de desenvolvedor (gerador de hash, JSON formatter, Docker Run to Compose converter, etc.).

### 7. Rede, Fixação de IP Estático e Resolução Local NPM / AdGuard (`*.pk.local`)
- [ ] **Persistência do IP Estático `192.168.0.8`:** Investigar e garantir que a interface física `enp1s0` assuma e mantenha exclusivamente o IP `192.168.0.8` em todo reboot sem interferência do DHCP dinâmico da Claro (que atribuiu temporariamente `192.168.0.2`).
- [ ] **Resolução DNS de Domínios Amigáveis (`*.pk.local`):** Verificar a propagação e escuta do AdGuard Home (`192.168.0.8:53`) e o roteamento do Nginx Proxy Manager (porta 80 -> 8088), diagnosticando por que clientes como o Pop!_OS e Smart TVs falham na resolução de nomes como `http://jellyfin.pk.local` mesmo respondendo por IP direto.
- [ ] **Homologação Jellyfin em Smart TVs Samsung (Tizen):** Validar acesso no aplicativo oficial da Samsung TV e no Projetor The Freestyle via `http://192.168.0.8:8096` ou proxy reverso.

### 8. Inspeção de Logs e Consoles dos Apps Nativos do Umbrel no Dockge (ou Dozzle)
- [ ] **Visualização de Stacks Nativas no Dockge:** No Dockge, os apps instalados pela App Store do Umbrel (`jellyfin`, `nextcloud`, `immich`, `adguard-home`, `home-assistant`, `tailscale`) aparecem na lista lateral esquerda marcados como `"Esta stack não é gerenciada pelo Dockge"`, o que impede ver o terminal interativo e o stream contínuo de logs diretamente pela interface.
- [ ] **Soluções a Avaliar:**
  - *Opção A (Mapeamento no Dockge):* Criar links simbólicos ou mapear os diretórios `/home/umbrel/umbrel/app-data/*/docker-compose.yml` para dentro da pasta `stacks` do Dockge, permitindo que ele passe a reconhecer e abrir o terminal/logs sem necessariamente alterar o ciclo de vida do Umbrel.
  - *Opção B (Dozzle - Visualizador Leve de Logs):* Adicionar na stack `management` o **Dozzle** (`http://umbrel.local:8888`), um container extremamente leve focado em exibir logs em tempo real, com busca, filtros e visualização de consumo de memória/CPU de absolutamente todos os containers do Docker daemon (nativos e customizados).

---

## 🛡️ Diretrizes Contínuas para o Projeto
- **Código e Scripts sempre atualizados:** Qualquer ajuste feito em tempo de execução deve ser refletido nos scripts em `scripts/*.sh` e nos arquivos `compose/**/*.yml`.
- **Documentação sempre sincronizada:** Manter o guia [Docs/pos_instalacao_portas_e_testes.md](pos_instalacao_portas_e_testes.md) sempre atualizado.
- **Clareza de comandos:** Sempre detalhar onde cada comando deve ser executado:
  - 💻 **No seu computador (Pop!_OS):** Comandos locais de rede, DNS e testes.
  - 🖥️ **No SSH do mini PC (`umbrel@umbrel`):** Comandos de Docker, systemd e administração de sistema.
