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

## 🎯 Issue 5: Desvio no Ponto de Montagem dos HDs Externos Pós-Queda de Energia (`disk1 (2)` e `disk2 (2)`) (CONCLUÍDO / HOMOLOGADO ✅)

### 📌 Status
- **Status:** **Resolvido e Homologado com Reboot Real!** 🎉
- **Causa Raiz Identificada:**
  - O daemon oficial do umbrelOS (`umbreld` - módulo `external-storage.ts`) monta os discos USB em `/home/umbrel/umbrel/external/<label>`.
  - Em desligamentos abruptos (dirty shutdown por queda de luz), as pastas canônicas permaneciam no sistema de arquivos como diretórios órfãos, fazendo a função `getUniqueName()` montar os HDs em caminhos com sufixo `disk1 (2)` e `disk2 (2)`.
- **Solução Implementada e Homologada no `homelab-daemon.sh`:**
  1. **Limpeza de Duplicatas:** Desmonta preventivamente e remove diretórios com sufixo `*(2)`.
  2. **Montagem Canônica por UUID de Hardware:** Amarra os pontos de montagem diretamente aos UUIDs (`UUID=fc0b5d7b-...` para `disk1`, `UUID=490440f1-...` para `disk2` e `UUID=e106affb-...` para `disk3`).
  3. **Blindagem do Samba:** Protege o `/etc/samba/smb.conf` com atributo imutável (`chattr +i`) e aguarda a estabilização dos containers oficiais antes de reativar `smbd`, `nmbd` e `wsdd2`.
- **Validação de Teste:** Executado reboot a frio no mini PC; os 3 discos montaram em menos de 1 segundo nos pontos canônicos, 100% dos 43 containers subiram sem falhas e todos os compartilhamentos Samba (`//192.168.0.8/Compartilhado` e `/Midia`) responderam imediatamente.

---

## 🚨 Issue 6 (Pendente): Áudio Bidirecional (Talkback) e Unmute Automático na Câmera ICSee (WebRTC / ONVIF)

### 📌 Problema Identificado:
- **Streaming de Vídeo e PTZ Homologados:** O painel em tela cheia via `custom:webrtc-camera` exibe o vídeo em tempo real com latência zero e os botões direcionais (Cima, Baixo, Esquerda, Direita) rotacionam a câmera com sucesso. Gravação de 30s e snapshots também operam normalmente.
- **Pendências Identificadas:**
  1. **Áudio Bidirecional (Microfone / Talkback):** Ao acionar o atalho de microfone no WebRTC, a voz do usuário não é reproduzida pelo alto-falante da câmera ICSee (chip Xiongmai XM530). O stream proprietário do ICSee na porta `34567` (protocolo Sofia/NetSurveillance) ou o codec de retorno (G.711 A-law / AAC) exige negociação específica de canal de áudio bidirecional ou proxy com go2rtc dedicado.
  2. **Inicialização do Áudio Desmutado (Unmute por Padrão):** Os navegadores modernos bloqueiam autoplay de mídia com som ativo por política de segurança (*Autoplay Policy*), ignorando a diretiva `muted: false` sem interação prévia do usuário na página.
- **Objetivo:**
  - Investigar e homologar o envio de áudio bidirecional direto para o alto-falante da câmera sem depender do aplicativo oficial cheio de anúncios.
---

## 🚨 Issue 7 (Pendente): Wake-On-LAN e Abertura Direta de Apps/Canais em Smart TVs Samsung (Tizen OS)

### 📌 Problema Identificado:
- **Navegação Remota e Teclado Homologados:** O painel de controle remoto com D-Pad (`remote.send_command`), botões direcionais, OK, Home, Return, volume e teclado numérico responde imediatamente com a TV ligada.
- **Pendências Identificadas:**
  1. **Wake-On-LAN com TV em Standby:** Ao tentar ligar a TV Samsung da Sala (`UN70CU7700GXZD` / MAC `1c:af:4a:d4:c6:e2`) ou o Projetor Paumila pelo botão Ligar quando em standby profundo, a interface Wi-Fi da TV desliga o chip de rede e o pacote mágico WOL via broadcast (`192.168.0.255:9`) não acorda o aparelho (comum em redes Wi-Fi mesh/Claro que barram pacotes de broadcast sem cabo de rede ou proxy SmartThings).
  2. **Abertura Direta de Apps (`select_source`):** A integração padrão `samsungtv` do Home Assistant expõe apenas fontes de entrada física de hardware (ex: `HDMI1`, `HDMI2`, `TV`), retornando o erro `does not support source <App>` ao tentar acionar apps de streaming (Prime Video, YouTube, Disney+, Jellyfin, Samsung TV Plus) diretamente pelo nome de entrada.
- **Objetivo:**
  - Avaliar a integração da TV via **SamsungTV Smart** (HACS / SmartThings API) para mapear os IDs de aplicativos instalados (App IDs Tizen) e permitir atalhos diretos.
---

## 🚨 Issue 8 (Pendente): Controle Dedicado e Integração da Bedroom TV (2º Monitor Pop!_OS)

### 📌 Problema Identificado:
- **Dispositivo Diferente:** A **Bedroom TV** (`media_player.bedroom_tv`) não é uma Smart TV Tizen convencional da sala, mas sim o segundo monitor conectado à workstation Pop!_OS do Paulo.
- **Pendências Identificadas:**
  1. **Controle Remoto Dedicado no Dashboard:** Criar um painel e controle remoto dedicado para a `Bedroom TV` no Home Assistant (assim como foi feito para a TV da Sala e o Projetor Paumila).
  2. **Mapeamento de Comandos e Controles do Display:** Verificar o tipo de integração atual (se UPnP/DLNA, Cast ou via comandos de sistema do Pop!_OS via SSH/HA Agent/MQTT) para definir quais comandos de mídia, volume, mute, energia (DPMS/ligar/desligar tela) e entradas são suportados de forma confiável.
- **Objetivo:**
  - Criar cartão de controle com layout adaptado para a `Bedroom TV` e homologar o controle de mídia e energia diretamente pelo Home Assistant.

---

## 🧪 Issue 2: Bateria de Testes e Validação dos Demais Serviços

Precisamos rodar testes práticos de ponta a ponta e validar as configurações dos seguintes serviços instalados:

### 1. Dockge (`http://dockge.pk.local` ou porta `:5001`) & Dozzle (`:8888`) (CONCLUÍDO / HOMOLOGADO ✅)
- [x] Validar se as stacks `management`, `arr-stack` e `betor` aparecem corretamente na interface.
- [x] Testar a edição de compose, visualização de logs em tempo real e comandos de Start / Stop / Restart pelo navegador.
- [x] Dozzle instalado e homologado na porta `:8888` (`http://umbrel.local:8888`), fornecendo visualização em tempo real de logs, consumo de CPU/memória e filtros para absolutamente todos os containers do Docker daemon (tanto nativos do Umbrel quanto stacks customizadas).

### 2. Uptime Kuma (`http://status.pk.local` ou porta `:3001`)
- [ ] Criar conta de administrador inicial.
- [ ] Cadastrar os monitores HTTP para todos os serviços internos (`jellyfin.pk.local`, `sonarr.pk.local`, `radarr.pk.local`, `umbrel.local`, etc.).
- [ ] Validar se os pings e status de disponibilidade ficam verdes no dashboard.

### 3. Nextcloud (`http://nuvem.pk.local` ou porta `:8081`) (CONCLUÍDO / HOMOLOGADO ✅)
- [x] Acesso web e onboarding do administrador `umbrel` concluídos.
- [x] Contas pessoais criadas para `paulo` e `kamila` com senhas seguras.
- [x] App `files_external` ativado e integrado com armazenamento nos HDs externos (`disk2`).
- [x] Pastas `Meus Arquivos` (privadas) e `Compartilhado` integradas de ponta a ponta com os compartilhamentos Samba (`smb://192.168.0.8/Paulo`, `Kamila`, `Compartilhado`).
- [x] Volumes persistentes mapeados no Compose oficial (`/home/umbrel/umbrel/app-data/nextcloud/docker-compose.yml`).
- [x] Permissões e rotinas de automação atualizadas no `homelab-daemon.sh` (com auto-reinjeção de volumes pós-updates).
- [x] Acesso remoto via Tailscale (VPN) 100% homologado em smartphones/dispositivos remotos com `trusted_domains` e `trusted_proxies` persistidos no `config.php` via `occ`.
- [x] Rotina de recuperação e reset de senhas homologada via CLI (`occ user:resetpassword`).
- [x] **Sincronização Contínua nos Desktops/Laptops:** Homologado com **Nextcloud Desktop Client** oficial (`com.nextcloud.desktopclient.nextcloud` no Pop!_OS em autostart com `--background` e aplicativo oficial no Windows 11). Evita duplicidade e concorrência de escrita com outros motores de sincronização.
- [x] **Syncthing (Standby Estratégico):** Container Syncthing (`:8384`, `:22000`, `:21027`) operacional no Homelab e pacote/regras de firewall UFW incluídas na automação do Pop!_OS (`popos-workstation-setup`), mantido em standby para casos de uso pontuais que fujam ao escopo do Nextcloud.

### 4. Immich (`http://fotos.pk.local` ou porta `:2283`)
- [ ] Validar e apontar o armazenamento de fotos para o HD dedicado (`disk2/immich`), garantindo persistência no `homelab-daemon.sh` caso haja updates do app pelo Umbrel.
- [ ] Acessar `http://192.168.0.8:2283` (ou `http://fotos.pk.local`) e criar conta de administrador inicial.
- [ ] Criar contas de usuário para `Paulo` e `Kamila` e habilitar bibliotecas compartilhadas/álbuns de parceiro (Partner Sharing).
- [ ] Configurar os aplicativos mobile (Android / iOS) com backup automático da câmera conectado via rede local (`fotos.pk.local`) e via Tailscale.

### 5. Home Assistant (`http://home.pk.local` ou porta `:8123`) (CONCLUÍDO / HOMOLOGADO ✅)
- [x] Acesso web e criação de conta admin `paulo` concluídos com fuso horário `America/Campo_Grande` (UTC-4).
- [x] Loja comunitária **HACS** instalada e autorizada via GitHub.
- [x] **Robô Aspirador Xiaomi (Clemildo):** Homologado via integração `Xiaomi Miot Auto` (HACS) conectado em modo Nuvem (Cloud).
- [x] **Câmeras ICSee (Xiongmai):** Homologado via protocolo nativo `ONVIF` (`192.168.0.4:8899`) e `custom:webrtc-camera`, com vídeo de baixa latência, rotação PTZ contínua com eixos corrigidos, botões de foto/screenshot e gravação de 30s (`.mp4`) com download direto.
- [x] **Alimentador Rojeco (Hector food):** Homologado via integração nativa `Tuya` com controle de porções e refeições.
- [x] **Alexa (Amazon Echo):** Homologado via integração `Alexa Media Player` (HACS) no domínio `amazon.com.br`, permitindo notificações por voz e reprodução de mídia.
- [ ] **Smart Displays & TVs (Controle Remoto Completo & Wake-On-LAN):**
  - **TV da Sala (TV Paumila):** Modelo Samsung `UN70CU7700GXZD` (`192.168.0.5`, MAC `1c:af:4a:d4:c6:e2`) - Controle remoto D-Pad, Cores e Numérico homologado ✅; Wake-On-LAN e atalhos de apps abertos na Issue 7.
  - **Projetor da Sala/Quarto (Projetor Paumila):** Modelo Samsung The Freestyle `SP-LSP3BLAXZA` (`192.168.0.13`, MAC `80:8a:bd:2e:1a:d8`) - Controle remoto completo homologado ✅; Wake-On-LAN e atalhos de apps abertos na Issue 7.
  - **Bedroom TV:** Segundo monitor do computador Pop!_OS (`media_player.bedroom_tv`) - Aberto na Issue 8 para criação de controle dedicado e mapeamento dos comandos.
  - **Correção de Wake-On-LAN:** Automação explícita de `wake_on_lan` configurada no `automations.yaml` e `configuration.yaml` (ajustes finos de standby em investigação na Issue 7).

### 6. IT-Tools (`http://it.pk.local` ou porta `:8080`)
- [ ] Validar carregamento das ferramentas de desenvolvedor (gerador de hash, JSON formatter, Docker Run to Compose converter, etc.).

### 7. Rede, Fixação de IP Estático e Resolução Local NPM / AdGuard (`*.pk.local`) (CONCLUÍDO / HOMOLOGADO ✅)
- [x] **Persistência do IP Estático `192.168.0.8`:** Corrigido e homologado via NetworkManager (`nmcli connection modify 'Wired connection 1' ipv4.addresses 192.168.0.8/24 ipv4.gateway 192.168.0.1 ipv4.dns '127.0.0.1 1.1.1.1' ipv4.method manual`) e persistido no `homelab-daemon.sh` e `/data/config.env`. O mini PC agora assume `192.168.0.8` autonomamente sem depender de atribuição DHCP após quedas de energia.
- [x] **Limitação Crítica do Roteador Claro (Sagemcom):** O roteador padrão da Claro (`192.168.0.1`) bloqueia completamente o acesso à sua interface administrativa web via HTTP/HTTPS na porta 80/443. Como não é possível configurar reservas DHCP nem alterar DNS diretamente no firmware da Claro, **todas as amarrações de IP fixo, DNS e roteamento são gerenciadas externamente** pelo NetworkManager do mini PC, AdGuard Home (`192.168.0.8:53 / :8095`) e Nginx Proxy Manager.
- [x] **Auto-Start de Aplicações Customizadas (Dockge / Homelab):** As stacks `karteman`, `verifica-nomes-diarios-oficiais` e `paulo-investimentos-pessoais` foram integradas no `homelab-daemon.sh`, garantindo que todas as aplicações pessoais subam sozinhas a frio pós-boot.
- [ ] **Homologação Jellyfin em Smart TVs Samsung (Tizen):** Validar acesso no aplicativo oficial da Samsung TV e no Projetor The Freestyle via `http://192.168.0.8:8096` ou proxy reverso.

### 8. Inspeção de Logs e Consoles dos Apps Nativos do Umbrel no Dockge / Dozzle (CONCLUÍDO / HOMOLOGADO ✅)
- [x] **Solução Adotada (Opção B - Dozzle):** Implementado e homologado o **Dozzle** (`http://umbrel.local:8888` / `http://dozzle.pk.local`) na stack `management`. Ele monitora com eficiência o socket do Docker (`/var/run/docker.sock`), garantindo streaming contínuo de logs, busca instantânea e métricas de consumo de 100% dos containers (nativos do Umbrel e customizados).

---

## 🛡️ Diretrizes Contínuas para o Projeto
- **Código e Scripts sempre atualizados:** Qualquer ajuste feito em tempo de execução deve ser refletido nos scripts em `scripts/*.sh` e nos arquivos `compose/**/*.yml`.
- **Documentação sempre sincronizada:** Manter o guia [Docs/pos_instalacao_portas_e_testes.md](pos_instalacao_portas_e_testes.md) sempre atualizado.
- **Clareza de comandos:** Sempre detalhar onde cada comando deve ser executado:
  - 💻 **No seu computador (Pop!_OS):** Comandos locais de rede, DNS e testes.
  - 🖥️ **No SSH do mini PC (`umbrel@umbrel`):** Comandos de Docker, systemd e administração de sistema.
