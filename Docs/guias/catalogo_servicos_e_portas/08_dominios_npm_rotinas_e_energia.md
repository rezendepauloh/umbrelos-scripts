# 🛡️ Domínios Locais NPM (*.pk.local), Rotinas e Energia 24/7

## 3. Tabela de Domínios Amigáveis no NPM (`*.pk.local`) com HTTPS Nativo

Todos os serviços contam com certificado SSL wildcard emitido localmente pela nossa Autoridade Certificadora privada (`Homelab Root CA`), permitindo acesso 100% seguro via `https://` sem avisos no navegador.

| Domínio Desejado | Forward Host / Container | Porta Interna | SSL / HTTPS | Websockets | Descrição / Serviço |
| :--- | :--- | :---: | :---: | :---: | :--- |
| `https://umbrel.pk.local` | `172.18.0.1` *(host)* | `80` | Ativo 🔒 | Sim ✅ | Dashboard Principal umbrelOS |
| `https://dockge.pk.local` | `dockge` | `5001` | Ativo 🔒 | Sim ✅ | Gerenciador Docker Stacks |
| `https://npm.pk.local` | `127.0.0.1` *(NPM)* | `81` | Ativo 🔒 | Sim ✅ | Nginx Proxy Manager Web UI |
| `https://status.pk.local` | `uptime-kuma` | `3001` | Ativo 🔒 | Sim ✅ | Monitoramento Uptime Kuma |
| `https://dozzle.pk.local` | `dozzle` | `8080` | Ativo 🔒 | Sim ✅ | Visualizador de Logs em Tempo Real |
| `https://it.pk.local` *(ou tools)* | `it-tools` | `80` | Ativo 🔒 | Não | Utilitários de TI (IT-Tools) |
| `https://syncthing.pk.local` | `syncthing` | `8384` | Ativo 🔒 | Não | Sincronização de Arquivos |
| `https://torrent.pk.local` | `qbittorrent` | `8085` | Ativo 🔒 | Não | Cliente BitTorrent Web |
| `https://pedidos.pk.local` | `jellyseerr` | `5055` | Ativo 🔒 | Sim ✅ | JellySeerr (Pedidos de Mídia) |
| `https://prowlarr.pk.local` | `prowlarr` | `9696` | Ativo 🔒 | Não | Gerenciador de Indexadores |
| `https://jackett.pk.local` | `jackett` | `9117` | Ativo 🔒 | Não | Indexadores Legados |
| `https://radarr.pk.local` | `radarr` | `7878` | Ativo 🔒 | Não | Automação de Filmes |
| `https://sonarr.pk.local` | `sonarr` | `8989` | Ativo 🔒 | Não | Automação de Séries |
| `https://bazarr.pk.local` | `bazarr` | `6767` | Ativo 🔒 | Não | Automação de Legendas |
| `https://jellyfin.pk.local` | `192.168.0.8` *(host)* | `8096` | Ativo 🔒 | Sim ✅ | Servidor de Streaming Jellyfin |
| `https://fotos.pk.local` | `192.168.0.8` *(host)* | `2283` | Ativo 🔒 | Sim ✅ | Galeria de Fotos Immich |
| `https://home.pk.local` | `192.168.0.8` *(host)* | `8123` | Ativo 🔒 | Sim ✅ | Automação Home Assistant |
| `https://nuvem.pk.local` | `192.168.0.8` *(host)* | `8081` | Ativo 🔒 | Sim ✅ | Nuvem de Arquivos Nextcloud |
| `https://adguard.pk.local` | `192.168.0.8` *(host)* | `8095` | Ativo 🔒 | Não | DNS Sinkhole AdGuard Home |
| `https://karteman.pk.local` | `karteman-app` | `8081` | Ativo 🔒 | Sim ✅ | Plataforma Karteman |
| `https://investimentos.pk.local` | `paulo-investimentos-app` | `8094` | Ativo 🔒 | Sim ✅ | App de Investimentos Pessoais |
| `https://diarios.pk.local` | `verifica-diarios-app` | `8093` | Ativo 🔒 | Sim ✅ | Robô Verifica Diários Oficiais |

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
