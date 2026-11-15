# 🛡️ Domínios Locais NPM (*.pk.local), Rotinas e Energia 24/7

## 3. Tabela de Domínios Amigáveis no NPM (`*.pk.local`) com HTTPS Nativo

Todos os serviços contam com certificado SSL wildcard emitido localmente pela nossa Autoridade Certificadora privada (`Homelab Root CA`), permitindo acesso 100% seguro via `https://` sem avisos no navegador.

| Domínio Desejado | Acesso Tailscale | Forward Host / Container | Porta Interna | SSL / HTTPS | Websockets | Descrição / Serviço |
| :--- | :--- | :--- | :---: | :---: | :---: | :--- |
| `https://umbrel.pk.local` | `https://umbrel.tail9accc5.ts.net` | `172.18.0.1` *(host)* | `80` | Ativo 🔒 | Sim ✅ | Dashboard Principal umbrelOS |
| `https://dockge.pk.local` | `http://umbrel.tail9accc5.ts.net:5001` | `dockge` | `5001` | Ativo 🔒 | Sim ✅ | Gerenciador Docker Stacks |
| `https://npm.pk.local` | `http://umbrel.tail9accc5.ts.net:81` | `127.0.0.1` *(NPM)* | `81` | Ativo 🔒 | Sim ✅ | Nginx Proxy Manager Web UI |
| `https://dozzle.pk.local` | `http://umbrel.tail9accc5.ts.net:8888` | `dozzle` | `8080` | Ativo 🔒 | Sim ✅ | Visualizador de Logs em Tempo Real |
| `https://it.pk.local` *(ou tools)* | `http://umbrel.tail9accc5.ts.net:8080` | `it-tools` | `80` | Ativo 🔒 | Não | Utilitários de TI (IT-Tools) |
| `https://terminal.pk.local` | `http://umbrel.tail9accc5.ts.net:7681` | `ttyd` | `7681` | Ativo 🔒 | Sim ✅ | Terminal Web (ttyd) |
| `https://syncthing.pk.local` | `http://umbrel.tail9accc5.ts.net:8384` | `syncthing` | `8384` | Ativo 🔒 | Não | Sincronização de Arquivos |
| `https://torrent.pk.local` | `http://umbrel.tail9accc5.ts.net:8085` | `qbittorrent` | `8085` | Ativo 🔒 | Não | Cliente BitTorrent Web |
| `https://pedidos.pk.local` | `http://umbrel.tail9accc5.ts.net:5055` | `jellyseerr` | `5055` | Ativo 🔒 | Sim ✅ | JellySeerr (Pedidos de Mídia) |
| `https://prowlarr.pk.local` | `http://umbrel.tail9accc5.ts.net:9696` | `prowlarr` | `9696` | Ativo 🔒 | Não | Gerenciador de Indexadores |
| `https://jackett.pk.local` | `http://umbrel.tail9accc5.ts.net:9117` | `jackett` | `9117` | Ativo 🔒 | Não | Indexadores Legados |
| `https://radarr.pk.local` | `http://umbrel.tail9accc5.ts.net:7878` | `radarr` | `7878` | Ativo 🔒 | Não | Automação de Filmes |
| `https://sonarr.pk.local` | `http://umbrel.tail9accc5.ts.net:8989` | `sonarr` | `8989` | Ativo 🔒 | Não | Automação de Séries |
| `https://bazarr.pk.local` | `http://umbrel.tail9accc5.ts.net:6767` | `bazarr` | `6767` | Ativo 🔒 | Não | Automação de Legendas |
| `https://jellyfin.pk.local` | `http://umbrel.tail9accc5.ts.net:8096` | `192.168.0.8` *(host)* | `8096` | Ativo 🔒 | Sim ✅ | Servidor de Streaming Jellyfin |
| `https://fotos.pk.local` | `http://umbrel.tail9accc5.ts.net:2283` | `192.168.0.8` *(host)* | `2283` | Ativo 🔒 | Sim ✅ | Galeria de Fotos Immich |
| `https://home.pk.local` | `http://umbrel.tail9accc5.ts.net:8123` | `192.168.0.8` *(host)* | `8123` | Ativo 🔒 | Sim ✅ | Automação Home Assistant |
| `https://nuvem.pk.local` | `http://umbrel.tail9accc5.ts.net:8081` | `192.168.0.8` *(host)* | `8081` | Ativo 🔒 | Sim ✅ | Nuvem de Arquivos Nextcloud |
| `https://adguard.pk.local` | `http://umbrel.tail9accc5.ts.net:8095` | `192.168.0.8` *(host)* | `8095` | Ativo 🔒 | Não | DNS Sinkhole AdGuard Home |
| `https://karteman.pk.local` | `http://umbrel.tail9accc5.ts.net:8091` | `karteman-app` | `8081` | Ativo 🔒 | Sim ✅ | Plataforma Karteman |
| `https://investimentos.pk.local` | `http://umbrel.tail9accc5.ts.net:8094` | `192.168.0.8` *(host)* | `8094` | Ativo 🔒 | Sim ✅ | App de Investimentos Pessoais |
| `https://diarios.pk.local` | `http://umbrel.tail9accc5.ts.net:8093` | `verifica-diarios-app` | `8093` | Ativo 🔒 | Sim ✅ | Robô Verifica Diários Oficiais |

---

## 4. Rotinas Automáticas em Segundo Plano

Você não precisa se preocupar com a integridade dos dados, pois duas rotinas essenciais já estão ativas:

1. **SnapRAID Sync Diário (03:00):**
   - Sincroniza a paridade do 3º HD externo com as novidades adicionadas nos discos 1 e 2.
   - Log disponível em: `/var/log/snapraid-sync.log`.

2. **Backup dos Bancos de Dados (04:00):**
   - Gera dumps compactados `.sql.gz` dos bancos PostgreSQL e SQLite (Immich, Nextcloud, etc.).
   - Arquivos salvos em: `/mnt/storage/backups/databases/` (com retenção de 7 dias).

---

## 5. Gerenciamento de Energia: Modo Servidor 24/7 e Economia (Idle)

Para um homelab doméstico funcionar perfeitamente sem interrupções, o sistema foi configurado para **nunca suspender ou hibernar**, mas continuar economizando energia com máxima eficiência:

1. **Como funciona o Idle (Ociosidade inteligente):**
   - **Processador (Intel Core i5-12450H):** Quando não há ninguém assistindo ou baixando, o kernel entra nos estados de baixo consumo (*C-States*). A voltagem e o clock diminuem drasticamente, consumindo apenas ~5W a 10W na tomada. O sistema continua 100% acordado e pronto para responder em milissegundos.
   - **Discos Externos (HDDs USB):** O `hdparm` gerencia o spindown dos discos para economizar energia quando não houver leitura/escrita.

2. **O que foi desativado (Prevenção de Quedas):**
   - **Suspensão (Suspend/Sleep):** Desligaria a placa de rede e travaria os containers.
   - **Hibernação (Hibernate):** Desligaria a máquina por completo.
   - **Ação por Ociosidade (`IdleAction=ignore`):** O `systemd-logind` não força suspensão por falta de atividade no terminal/teclado.

3. **Comandos aplicados (registrados no `01_system_prep.sh`):**
   ```bash
   # Mascarar alvos de suspensão e hibernação
   sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

   # Configurar systemd-logind para ignorar eventos de suspensão
   sudo bash -c 'cat << "EOF" > /etc/systemd/logind.conf.d/99-homelab-nosleep.conf
   [Login]
   HandleLidSwitch=ignore
   HandleLidSwitchExternalPower=ignore
   HandleSuspendKey=ignore
   HandleHibernateKey=ignore
   IdleAction=ignore
   EOF'
   sudo systemctl restart systemd-logind
   ```
