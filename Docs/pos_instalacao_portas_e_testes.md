# Guia de Pós-Instalação, Portas, Credenciais e Roteiro de Configuração

Parabéns! Se você chegou até aqui, todo o ecossistema do seu **umbrelOS** no **Blackview MP100 Pro** foi implantado com sucesso: os 3 HDs montados de forma nativa e direta (**3 TB úteis: disk1, disk2, disk3**), backup inteligente diário para o desktop Pop!_OS, o servidor **Samba**, a stack de mídia e download (**Stack Arr + qBittorrent**), e a infraestrutura de gerenciamento e reverse proxy (**Dockge, NPM, Uptime Kuma, IT-Tools, Syncthing**).

Este guia reúne todas as portas, credenciais e **a ordem lógica recomendada** para configurar cada aplicação sem retrabalho.

---

## 1. Tabela Geral de Serviços e Portas

| Serviço | URL / Porta | Usuário Inicial | Senha Inicial | O que fazer no primeiro acesso |
| :--- | :--- | :--- | :--- | :--- |
| **umbrelOS Dashboard** | `http://umbrel.local` | Definido no setup | Definida no setup | Instalar Jellyfin, Immich, Nextcloud, AdGuard |
| **Tailscale Web** | `http://umbrel.local:8240` | Sua conta Tailscale | Sua conta Tailscale | Autenticar o mini PC na sua rede Mesh pessoal |
| **Nginx Proxy Manager (NPM)** | `http://umbrel.local:81` | `admin@example.com` | `changeme` | O sistema força a troca de e-mail e senha no 1º login |
| **Dockge** | `http://umbrel.local:5001` | *(Criado na tela)* | *(Criado na tela)* | Criar usuário admin para gerenciar as stacks |
| **Dozzle (Logs em Tempo Real)** | `http://umbrel.local:8888` | *Sem autenticação* | *Sem autenticação* | Monitorar logs/consoles de TODOS os 36+ containers |
| **qBittorrent Web UI** | `http://umbrel.local:8085` | `admin` | Impressa no log | Ver comando no Passo 3 para resgatar/trocar senha |
| **Uptime Kuma** | `http://umbrel.local:3001` | *(Criado na tela)* | *(Criado na tela)* | Criar conta admin para monitorar os containers |
| **IT-Tools** | `http://umbrel.local:8080` | *Sem autenticação* | *Sem autenticação* | Utilitários para desenvolvedor (JSON, hash, etc.) |
| **Syncthing Web UI** | `http://umbrel.local:8384` | *Sem senha inicial* | *Sem senha inicial* | Configurar usuário/senha em Ações ➡️ Configurações |
| **Jellyseerr** | `http://umbrel.local:5055` | *(Criado na tela)* | *(Criado na tela)* | Conectar ao Jellyfin nativo do Umbrel |
| **Radarr (Filmes)** | `http://umbrel.local:7878` | *Sem senha inicial* | *Sem senha inicial* | Definir senha em Settings ➡️ General |
| **Sonarr (Séries)** | `http://umbrel.local:8989` | *Sem senha inicial* | *Sem senha inicial* | Definir senha em Settings ➡️ General |
| **Prowlarr (Indexadores)** | `http://umbrel.local:9696` | *Sem senha inicial* | *Sem senha inicial* | Conectar indexadores e sincronizar com Radarr/Sonarr |
| **Jackett** | `http://umbrel.local:9117` | *Sem senha* | *Sem senha* | Copiar API Key se usar indexadores específicos |
| **Bazarr (Legendas)** | `http://umbrel.local:6767` | *Sem senha inicial* | *Sem senha inicial* | Conectar com Radarr/Sonarr e OpenSubtitles |
| **FlareSolverr** | `http://umbrel.local:8191` | *Sem interface* | *Serviço de Proxy* | Usado internamente pelo Prowlarr para bypass Cloudflare |
| **BeTor (API Nacional)** | `http://umbrel.local:8005` | *Sem interface* | *Buscador Nacional* | Stack sob demanda no Dockge para Comando Torrents e Bludv |

---

## 2. 🗺️ Roteiro de Configuração Passo a Passo (Ordem Recomendada)

Configurar os serviços na ordem abaixo evita refazer trabalho, pois as aplicações da Stack Arr e multimídia dependem umas das outras:

```
[1. Fundação & Rede] ──> [2. Dockge & Senhas] ──> [3. Download & Indexadores] ──> [4. Automação de Mídia] ──> [5. Streaming & Nuvem]
 (Tailscale, AdGuard,        (Trocar senhas e        (qBittorrent + Prowlarr)          (Radarr, Sonarr,           (Jellyfin, Jellyseerr,
      NPM e Samba)             criar admins)                                                Bazarr)                  Immich, Nextcloud)
```

---

### 🔹 ETAPA 1: Fundação, Acesso Remoto e Rede Local

#### 1.1. Ativar o Tailscale (Acesso Seguro Fora de Casa)
Como você instalou o app **Tailscale** pela **App Store do umbrelOS**, ele roda em um container próprio com interface Web dedicada na porta **8240**:
1. Abra no navegador: `http://umbrel.local:8240` (ou clique diretamente no ícone do Tailscale no dashboard do Umbrel).
2. Clique em **Log In** e faça a autenticação com sua conta (Google, GitHub, Microsoft ou Apple).
3. Pronto! O mini PC aparecerá imediatamente no seu painel Tailscale (no celular ou computador remoto).

> **Dica (caso prefira via terminal no futuro):**
> Para rodar comandos CLI do Tailscale que está dentro do container do Umbrel:
> ```bash
> sudo docker exec -it tailscale_web_1 tailscale status
> ```

#### 1.2. Ativar Domínios Amigáveis no AdGuard Home (`*.pk.local`)
No painel do AdGuard Home (`http://umbrel.local:8095`):
1. Vá em **Filtros (Filters)** ➡️ **Reescritas de DNS (DNS rewrites)**.
2. Clique em **Adicionar reescrita de DNS**:
   - **Nome de Domínio:** `*.pk.local`
   - **Endereço IP:** `192.168.0.8` (IP estático fixo do mini PC).
3. Salve. Agora qualquer subdomínio `.pk.local` vai responder pelo mini PC.

##### 📱 Como configurar o DNS (`192.168.0.8`) nos aparelhos da casa:

- **Smart TV Samsung & Projetor Samsung (Tizen OS):**
  1. No controle remoto, abra **Configurações (Settings)** ➡️ **Geral (General)** ➡️ **Rede (Network)**.
  2. Vá em **Status da Rede (Network Status)** ➡️ **Configurações de IP (IP Settings)**.
  3. Mude a linha **Configuração de DNS (DNS setting)** de *Obter automaticamente* para **Digitar manualmente (Enter manually)**.
  4. No campo **Servidor DNS (DNS Server)**, digite: **`192.168.0.8`**.
  5. Pressione OK. *(Pronto! A TV/Projetor bloqueia anúncios e encontra o Jellyfin pelo domínio `jellyfin.pk.local`)*.

- **Smartphone Android (Samsung / Xiaomi / Motorola):**
  1. Vá em **Configurações** ➡️ **Conexões** ➡️ **Wi-Fi**.
  2. Toque na **engrenagem ⚙️** da sua rede Wi-Fi ➡️ **Avançado** (ou ícone de lápis para editar).
  3. Em **Definições de IP**, mude de *DHCP* para **Estático**.
  4. Preencha **DNS 1**: **`192.168.0.8`** (e DNS 2: `1.1.1.1` como reserva) e salve.

- **iPhone / iPad (iOS):**
  1. Abra **Ajustes** ➡️ **Wi-Fi** ➡️ toque no botão azul **(i)** ao lado da rede conectada.
  2. Role até **Configurar DNS** ➡️ mude para **Manual**.
  3. Remova os servidores antigos, clique em **Adicionar Servidor** e digite: **`192.168.0.8`**. Salve.

- **Computadores Windows (Notebook / Desktop):**
  1. Vá em **Configurações** ➡️ **Rede e Internet** ➡️ **Wi-Fi** (ou *Ethernet*).
  2. Clique em **Propriedades da rede** ➡️ em *Atribuição de servidor DNS*, clique em **Editar**.
  3. Mude para **Manual**, ative o **IPv4** e digite no DNS Preferencial: **`192.168.0.8`**. Salve.

- **Linux (Pop!_OS / Ubuntu):**
  *(Já integrado no script `25_limpeza_otimizacao.sh`)*:
  Nas configurações da conexão de rede: IPv4 DNS = `192.168.0.8`, IPv6 = Desativado, e comando `sudo resolvectl domain eno1 "~."`.

#### 1.3. Primeiro Login no Nginx Proxy Manager (NPM) e Liberação da Porta 80
1. Acesse `http://umbrel.local:81` (ou `http://192.168.0.8:81`).
2. Login inicial:
   - Email: `admin@example.com`
   - Senha: `changeme`
3. Troque imediatamente o e-mail de administrador e defina sua senha definitiva.
4. Cadastre os domínios locais amigáveis clicando em **Hosts** ➡️ **Proxy Hosts** ➡️ **Add Proxy Host** (consulte a tabela completa de domínios no **item 3** deste guia).
   - ⚠️ **Importante:** Para o host `umbrel.pk.local`, use o **Forward Hostname**: `127.0.0.1`, Porta: `80` e marque obrigatoriamente **Websockets Support** ✅ para carregar o dashboard em tempo real!

##### 🚀 Redirecionamento da Porta 80 no iptables (Para acessar sem digitar :8088):
O Nginx Proxy Manager escuta internamente o tráfego HTTP na porta `8088` (para não colidir com o Umbrel). Para que qualquer pessoa na sua casa digite apenas `http://dockge.pk.local` ou `http://umbrel.pk.local` **sem precisar digitar nenhuma porta**, execute este comando de redirecionamento no SSH do Umbrel:

```bash
# Redirecionar requisições da porta 80 da placa de rede física para a porta 8088 do NPM
sudo iptables -t nat -A PREROUTING -i enp1s0 -p tcp --dport 80 -j REDIRECT --to-port 8088
```

> 💡 **Para tornar a regra permanente após reinicializações via Systemd:**
> ```bash
> sudo bash -c 'cat << "EOF" > /etc/systemd/system/homelab-port80-redirect.service
> [Unit]
> Description=Redirecionamento de Porta 80 para NPM (8088)
> After=network.target docker.service
> 
> [Service]
> Type=oneshot
> RemainAfterExit=yes
> ExecStart=/sbin/iptables -t nat -A PREROUTING -i enp1s0 -p tcp --dport 80 -j REDIRECT --to-port 8088
> ExecStop=/sbin/iptables -t nat -D PREROUTING -i enp1s0 -p tcp --dport 80 -j REDIRECT --to-port 8088
> 
> [Install]
> WantedBy=multi-user.target
> EOF'
> 
> sudo systemctl daemon-reload
> sudo systemctl enable --now homelab-port80-redirect.service
> ```
> *(Caso queira desativar no futuro, basta rodar: `sudo systemctl disable --now homelab-port80-redirect.service`)*.

#### 1.4. Testar os Compartilhamentos Samba e Persistência do MergerFS
No seu Pop!_OS, utilize preferencialmente o **Nautilus** (`sudo apt install nautilus gvfs-backends`), que oferece estabilidade total na escrita SMB e gerenciamento de permissões (o Cosmic Files ainda possui instabilidades de cache/gravação em conexões de rede SMB):
Pressione `Ctrl + L` no Nautilus (ou vá em *Outros Locais* ➡️ *Conectar ao Servidor*):
- `smb://192.168.0.8/Media` (ou `smb://umbrel.local/Media` - Leitura e gravação livre)
- `smb://192.168.0.8/Compartilhado` (Pasta colaborativa Paulo e Kamila)
- `smb://192.168.0.8/Paulo` (Pasta privada de Paulo - autenticação exclusiva)
- `smb://192.168.0.8/Kamila` (Pasta privada de Kamila - autenticação exclusiva)
- `smb://192.168.0.8/Backups` (Compartilhamento restrito para backups)
- `smb://192.168.0.8/Dev` (Compartilhamento para projetos e códigos)
- Entre com o usuário `paulo` (ou `kamila`) e a senha definida. Ambos têm permissão completa de criação, edição e exclusão de arquivos.

> [!NOTE]
> **Persistência do MergerFS, Jellyfin e Stacks no Reboot (Hook Oficial do umbrelOS):**
> - Como o umbrelOS utiliza sistema de arquivos base imutável (Rugix OS), o binário do **MergerFS foi gravado na partição persistente `/data/bin/mergerfs`**.
> - Toda a orquestração de boot é gerenciada pelo **Hook Oficial de Boot do umbrelOS (`/home/umbrel/umbrel/custom-hooks/pre-start`)**, que é chamado como root pelo serviço nativo do sistema `umbrel-custom-pre-start.service`.
> - Esse hook:
>   1. Restaura o symlink do MergerFS em `/usr/bin/mergerfs`.
>   2. Aguarda até 30s os HDs USB externos do Umbrel montarem e ativa o pool `/mnt/storage`.
>   3. Espelha `/mnt/storage/media` para `/home/umbrel/umbrel/home/Downloads/media` para o Jellyfin.
>   4. Restaura os usuários `paulo` e `kamila` e reativa o Samba lendo as senhas salvas em `/data/samba/passdb.tdb`.
>   5. Sobe todas as Stacks Customizadas (Dockge, NPM, IT-Tools, Uptime Kuma, qBittorrent, Sonarr, Radarr, BeTor) logo que o Docker estiver pronto.

---

### 🔹 ETAPA 2: Dockge e Credenciais de Gerenciamento

#### 2.1. Dockge (`http://umbrel.local:5001`)
1. No primeiro acesso, crie seu usuário e senha master de administrador.
2. Você verá as stacks `management` e `arr-stack` listadas em verde como ativas.

#### 2.2. Uptime Kuma (`http://umbrel.local:3001`)
1. Crie a conta de administrador.
2. Adicione os primeiros monitores HTTP para acompanhar a saúde dos serviços:
   - Tipo: HTTP(s)
   - Nome: `umbrelOS` ➡️ `http://umbrel.local`
   - Nome: `Dockge` ➡️ `http://umbrel.local:5001`
   - Nome: `NPM` ➡️ `http://umbrel.local:81`

---

### 🔹 ETAPA 3: Cliente de Download e Indexadores (qBittorrent + Prowlarr)

A automação de filmes e séries depende de um cliente de download e de buscadores de torrent.

#### 3.1. Obter a Senha do qBittorrent, Liberar Proxy Reverso e Trocar Senha
Por padrão, versões recentes do qBittorrent bloqueiam acessos via Proxy Reverso (`torrent.pk.local`) acusando `Unauthorized` por validação de CSRF.

Para liberar o acesso pelo proxy reverso e resgatar a senha temporária, execute no SSH do Umbrel:
```bash
# 1. Parar o qBittorrent
sudo docker stop qbittorrent

# 2. Desativar proteção CSRF e validação de Host para liberar o domínio local
CONF_FILE="/home/umbrel/umbrelos-scripts/compose/arr-stack/data/qbittorrent/config/qBittorrent/qBittorrent.conf"
sudo sed -i '/WebUI\\CSRFProtection/d' "$CONF_FILE" 2>/dev/null || true
sudo sed -i '/WebUI\\HostHeaderValidation/d' "$CONF_FILE" 2>/dev/null || true
sudo bash -c "cat << 'EOF' >> '$CONF_FILE'
WebUI\CSRFProtection=false
WebUI\HostHeaderValidation=false
EOF"

# 3. Iniciar o qBittorrent e ver a senha temporária
sudo docker start qbittorrent
sudo docker logs qbittorrent 2>&1 | grep "temporary password"
```

1. Copie a senha exibida (ex: `Qg5TjNefp`).
2. Acesse no navegador: **`http://torrent.pk.local`** (ou `http://umbrel.local:8085`).
3. Entre com:
   - **Usuário:** `admin`
   - **Senha:** A senha temporária copiada.
4. Dentro do qBittorrent:
   - Vá no menu: **Ferramentas (Tools)** ⚙️ ➡️ **Opções (Options)** ➡️ aba **Web UI**.
   - Altere o nome de usuário e defina sua nova senha definitiva.
   - Na aba **Downloads**, confirme que o diretório padrão de download é `/downloads` (que mapeia internamente para `/mnt/storage/media/torrents`).
   - Salve no rodapé.

#### 3.2. Configurar o Prowlarr (`http://prowlarr.pk.local` ou `:9696`)

1. **Acesso inicial e credenciais:**
   - Acesse **`http://prowlarr.pk.local`** e defina seu usuário e senha em **Settings ➡️ General** (Authentication Method: *Forms*).

2. **Configurar o Proxy FlareSolverr (Bypass de Cloudflare Protection):**
   > [!IMPORTANT]
   > Sites públicos como 1337x e TorrentGalaxy ativam proteções Cloudflare contra bots. O FlareSolverr resolve os desafios automaticamente em segundo plano.
   - Vá em **Settings ➡️ Indexers**.
   - Na seção **Indexer Proxies**, clique no **`+`** e selecione **FlareSolverr**.
   - Preencha:
     - **Name:** `FlareSolverr`
     - **Tags:** `flaresolverr` *(Pressione Enter para fixar a tag! Se deixar vazio, o Prowlarr marca o proxy como `Disabled`)*.
     - **Host:** `http://flaresolverr:8191`
     - **Request Timeout:** `60` segundos.
   - Clique em **Test** (deve retornar `✓` verde) e depois em **Save**.

3. **Adicionar Indexadores no Prowlarr:**
   - Vá em **Indexers ➡️ Add Indexer**:
     - **Catálogo BeTor (Buscador Nacional PT-BR / Dual Áudio):**
       - O arquivo de definição personalizada (`betor.yml`) está instalado em `/config/Definitions/Custom/betor.yml` no Prowlarr.
       - Na busca de indexadores, procure por **Catálogo BeTor** (ou **BeTor**).
       - **Base URL:** `http://betor-api:8000/` (conecta diretamente na API local da stack BeTor gerenciada no Dockge).
       - **Tags:** Deixe em branco (não use a tag `flaresolverr`, pois a comunicação é interna e direta entre containers).
       - Clique em **Test** (deve retornar `✓` verde) e clique em **Save**.
       - Defina a **Prioridade como `1`** para que o Sonarr e Radarr prefiram sempre o acervo brasileiro!
     - **The Pirate Bay** (TPB): Adicione com Prioridade `2`.
     - **YTS:** Adicione diretamente para filmes originais compactos em HD/4K.
     - **1337x:**
       - Role o modal até o final (ou clique na engrenagem superior esquerda *Show Advanced*).
       - No campo **Tags**, adicione `flaresolverr` (Enter).
       - Clique em **Test** e salve.
     - **TorrentGalaxy:** Adicione com a tag `flaresolverr`.
     - **EZTV:** Focado em episódios e temporadas de séries.

4. **Sincronizar com Radarr e Sonarr:**
   - No menu **Indexers**, clique no botão circular **Sync App Indexers** (🔄).
   - O Prowlarr injetará o Catálogo BeTor instantaneamente no Sonarr e no Radarr.

5. **Conectar o Cliente de Download (qBittorrent):**
   - Vá em **Settings ➡️ Download Clients**:
   - Clique no **`+`** e selecione **qBittorrent**:
     - **Name:** `qBittorrent`
     - **Host:** `qbittorrent` (comunicação interna na rede Docker `homelab_network`).
     - **Port:** `8085`
     - **Username:** `admin` (ou o usuário que você redefiniu no qBittorrent).
     - **Password:** Sua senha configurada no qBittorrent.
   - Clique em **Test** (deve exibir `✓` verde) e depois em **Save**.

> [!TIP]
> **Como o BeTor Funciona no Homelab (API Local de Alta Velocidade + Raspagem Contínua):**
>
> 1. **Arquitetura Local (Zero Cloudflare e Resposta Instantânea):**
>    - O BeTor roda localmente na stack gerenciada pelo **Dockge** (`compose/betor/docker-compose.yml`), escutando na porta interna `8005` (`http://betor-api:8000`).
>    - No Prowlarr, o indexador **Catálogo BeTor** conecta-se diretamente à API local (`http://betor-api:8000/`) sem precisar da tag `flaresolverr`, eliminando atrasos e bloqueios do Cloudflare da internet.
>    - Categorias mapeadas: `5000` (TV), `5030` (TV/SD), `5040` (TV/HD), `2000` (Movies), `2030` (Movies/SD), `2040` (Movies/HD).
>
> 2. **Varredura e Atualização Contínua do Catálogo:**
>    - **Rotina Automática no Cron:** O sistema dispara a cada 6 horas (`/etc/cron.d/betor-sync`) os spiders do ScrapyD (`comando-torrents` e `bludv`) para alimentar o MongoDB com os lançamentos mais recentes de filmes e séries dubladas/dual áudio.
>    - **Para forçar a busca de um filme ou série específica manualmente a qualquer momento:**
>      Execute no SSH do mini PC:
>      ```bash
>      sudo docker exec -it prowlarr curl -s -X POST http://betor-scrapyd:6800/schedule.json -d project=betor -d spider=comando-torrents -d search="nome-da-serie"
>      sudo docker exec -it prowlarr curl -s -X POST http://betor-scrapyd:6800/schedule.json -d project=betor -d spider=bludv -d search="nome-da-serie"
>      ```
>    - Os novos torrents caem no MongoDB local em segundos e ficam disponíveis imediatamente nas buscas do Sonarr e Radarr!

---

### 🔹 ETAPA 4: Gerenciadores de Conteúdo (Radarr, Sonarr e Bazarr)

Agora sincronizamos o Prowlarr diretamente com o Radarr e Sonarr para que eles recebam os buscadores automaticamente.

#### 4.1. Conectar Prowlarr ao Radarr e Sonarr
1. No **Radarr** (`http://umbrel.local:7878`):
   - Vá em **Settings ➡️ General** e copie a **API Key**.
2. No **Sonarr** (`http://umbrel.local:8989`):
   - Vá em **Settings ➡️ General** e copie a **API Key**.
3. Volte ao **Prowlarr** (`http://umbrel.local:9696`):
   - Vá em **Settings ➡️ Apps** ➡️ clique no **+**:
     - Adicione o **Radarr**:
       - Prowlarr Server: `http://prowlarr:9696`
       - Radarr Server: `http://radarr:7878`
       - API Key: Cole a chave do Radarr.
       - Clique em **Test** e salve.
     - Adicione o **Sonarr**:
       - Prowlarr Server: `http://prowlarr:9696`
       - Sonarr Server: `http://sonarr:8989`
       - API Key: Cole a chave do Sonarr.
       - Clique em **Test** e salve.
   - Clique no botão **Sync App Indexers** no topo da página. Pronto! Todos os indexadores do Prowlarr agora estão disponíveis dentro do Radarr e Sonarr automaticamente!

#### 4.2. Configurar Pastas de Destino, Regras de Dual Áudio e Download Client

- **No Sonarr (`http://sonarr.pk.local`):**
  - **Settings ➡️ Media Management:**
    - **Root Folders:** Adicione `/tv` (que mapeia nativamente para `/home/umbrel/umbrel/external/disk1/media/series`).
    - **Season Folder:** Ative a opção de pastas por temporada (`Season {season:00}`). 
      > [!IMPORTANT]
      > O Jellyfin exige que as séries estejam em subpastas de temporada (ex: `Silo/Season 03/ep.mkv`). Se os episódios ficarem soltos na raiz da série, o Jellyfin classifica como *Season Unknown* e bloqueia a reprodução com o erro *"Não foi possível encontrar uma fonte de mídia válida para reproduzir"*.
  - **Settings ➡️ Download Clients:** Adicione o `qBittorrent` (Host: `qbittorrent`, Port: `8085`).
  - **Settings ➡️ Custom Formats (Regra para Dual Áudio / Dublado):**
    - Clique no **`+`** e crie um formato chamado `Português / Dual Áudio`.
    - Adicione a condição **Language**: `Portuguese`.
    - Adicione a condição **Release Title**: `\b(DUAL|DUBLADO|PT-?BR|BRAZILIAN|PORTUGUESE)\b` *(evitar a palavra `MULTI`, pois trackers europeus utilizam `MULTI` para inglês/francês/alemão)*.
    - Vá em **Settings ➡️ Profiles ➡️ `HD-1080p`**, role até Custom Formats e dê pontuação **`1500`** para esse formato.
  - **Settings ➡️ Connect (Notificar o Jellyfin automaticamente):**
    - Adicione uma conexão do tipo **Jellyfin**: Host `http://192.168.0.8:8096`, insira a API Key do Jellyfin.

- **No Radarr (`http://radarr.pk.local`):**
  - **Settings ➡️ Media Management:**
    - **Root Folders:** Adicione `/movies` (que mapeia nativamente para `/home/umbrel/umbrel/external/disk1/media/movies`).
  - **Settings ➡️ Download Clients:** Adicione o `qBittorrent` (Host: `qbittorrent`, Port: `8085`).
  - **Settings ➡️ Custom Formats:**
    - Crie o formato `Dual Áudio PT-BR` com a condição **Release Title**: `\b(DUAL|DUBLADO|PT-?BR|BRAZILIAN|PORTUGUESE)\b`.
    - Em **Profiles ➡️ `HD-1080p`**, atribua a pontuação **`1500`** para ele.
  - **Settings ➡️ Connect:** Adicione o Jellyfin (`http://192.168.0.8:8096`).

#### 4.3. Bazarr (Legendas em Português) - [Pendente de Validação]
1. Acesse `http://umbrel.local:6767` (ou `http://bazarr.pk.local`).
2. Vá em **Settings ➡️ Sonarr** e conecte inserindo o host `sonarr:8989` e a API Key do Sonarr.
3. Vá em **Settings ➡️ Radarr** e conecte inserindo o host `radarr:7878` e a API Key do Radarr.
4. Em **Settings ➡️ Providers**, adicione provedores de legendas (OpenSubtitles.com, Subdl, Legendas.tv):
   - Insira credenciais se exigido pelo provedor.
   - Em **Settings ➡️ Languages**, defina os idiomas padrão para pesquisa como **Portuguese (Brazil) / pt-BR**.
   > [!NOTE]
   > A sincronização prática de legendas e download automático ao lado dos arquivos de vídeo no `disk1` foi documentada e está registrada na Issue 4 de [Docs/issues_e_pendencias.md](issues_e_pendencias.md) para teste e homologação posterior.

#### 4.4. Como Remover um Filme/Série Completamente (Limpeza Total)
Se você não quiser mais um conteúdo ou desejar refazer o download do zero:
1. **No Radarr (Filmes) ou Sonarr (Séries):**
   - Acesse o card do filme ou série.
   - Clique no ícone da lixeira vermelha (**Delete**).
   - **MUITO IMPORTANTE:** Marque a caixinha **`Delete files from disk`** (para remover os vídeos da pasta física de filmes/séries no `disk1`) e confirme.
2. **No qBittorrent (`http://torrent.pk.local`):**
   - Se o torrent ainda estiver na lista como concluído/semeando, clique com o botão direito nele ➡️ **Excluir** (ou aperte `Shift + Delete`).
   - Marque a opção: **`Também excluir os arquivos do disco rígido`** (limpa a pasta temporária de torrents no `disk1`).
3. **No Jellyseerr (`http://pedidos.pk.local`):**
   - Vá no menu **Requests** (Pedidos).
   - Localize o pedido e clique em **Delete Request** (para desvincular do portal da família).

#### 4.5. Escolher o Torrent a Dedo (Interactive Search 👤🔍)
Se você não quiser que o Sonarr ou Radarr façam o download automático cego:
1. Abra a página da Série ou do Filme.
2. Clique no ícone da **pessoa com lupa (👤🔍)**:
   - Uma tabela com todos os torrents encontrados nos indexadores será exibida em tempo real.
   - Você pode conferir os nomes exatos dos arquivos, tamanhos, número de seeds e tags de áudio.
   - Para baixar um release específico, basta clicar no ícone do **carrinho/download (📥)** na extrema direita daquela linha!





---

### 🔹 ETAPA 5: Streaming, Descoberta e Nuvem Familiar

#### 5.1. Jellyfin (Servidor de Streaming)

> [!NOTE]
> **Como o UmbrelOS mapeia o Jellyfin nativo:**
> O container oficial do Jellyfin na App Store do Umbrel possui acesso à pasta `/downloads` (que no host aponta para `/home/umbrel/umbrel/home/Downloads`).
> Para que o Jellyfin enxergue suas mídias do storage MergerFS (`/mnt/storage/media`), criamos montagens de vínculo (*bind mounts*) persistentes:
> ```bash
> sudo mkdir -p /home/umbrel/umbrel/home/Downloads/{Movies,Series,Music}
> sudo mount --bind /mnt/storage/media/movies /home/umbrel/umbrel/home/Downloads/Movies
> sudo mount --bind /mnt/storage/media/series /home/umbrel/umbrel/home/Downloads/Series
> sudo mount --bind /mnt/storage/media/music /home/umbrel/umbrel/home/Downloads/Music
> ```
> *(Já persistido no `/etc/fstab` com a flag `nofail`).*

1. **Acesse:** **`http://jellyfin.pk.local`** (ou `http://192.168.0.8:8096`).
2. **Assistente de Boas-Vindas:**
   - Crie o usuário e senha do administrador.
   - Selecione o idioma preferido: **Português (Brasil)**.
3. **Adicionar Bibliotecas de Mídia:**
   - Clique em **Adicionar Biblioteca de Mídia**:
     - **Tipo: Filmes** ➡️ Nome: `Filmes` ➡️ Pastas (+): selecione **`/downloads/media/movies`** (que mapeia nativamente para o `disk1`).
     - **Tipo: Programas de TV** ➡️ Nome: `Séries` ➡️ Pastas (+): selecione **`/downloads/media/series`** (que mapeia nativamente para o `disk1`).
     - **Tipo: Músicas** (opcional) ➡️ Pastas (+): selecione **`/downloads/media/music`**.
   - Idioma de metadados: **Portuguese**, País: **Brazil**.
   > [!NOTE]
   > **Status de Integração com a Arr-Stack (Pendente de Homologação Total):**
   > Os arquivos baixados e importados pelo Radarr/Sonarr já caem automaticamente nas pastas corretas do `disk1`. No entanto, a notificação automática via **Settings > Connect** (API Key do Jellyfin) para acionar o scan instantâneo após o término do download precisa de ajuste fino para que a biblioteca atualize sem intervenção manual no botão *"Rastrear Todas as Bibliotecas"*.

4. **Ativar Transcodificação por Hardware (Intel Quick Sync Video - QSV):**
   - Vá no menu lateral (ícone de 3 barras) ➡️ **Painel de Controle (Dashboard)** ➡️ **Reprodução (Playback)**.
   - Em **Aceleração por hardware**, selecione: **Intel QuickSync (QSV)**.
   - Habilite os decodificadores de hardware suportados pelo i5-12450H: `H264`, `HEVC`, `VC1`, `VP9`, `AV1`.
   - Clique em **Salvar** no rodapé.

5. **Plugin Oficial "Intro Skipper" (Botão Pular Abertura estilo Netflix):**
   - Vá em **Painel de Controle ➡️ Plugins ➡️ Catálogo ➡️ Repositórios (+)**:
     - Adicione: `https://intro-skipper.org/manifest.json`
   - No catálogo de plugins, instale o **Intro Skipper** e reinicie o container:
     ```bash
     sudo docker restart jellyfin_server_1 jellyfin_app_proxy_1
     ```
   - Em **Painel de Controle ➡️ Plugins ➡️ Intro Skipper**, ative a opção *"Automatically analyze new media"*. Ao dar play em qualquer episódio com abertura reconhecida, o botão **Pular Abertura** surge na tela!

6. **TV ao Vivo (IPTV e Guia EPG):**
   - Em **Painel de Controle ➡️ TV ao Vivo**:
     - **Sintonizador M3U:** `https://iptv-org.github.io/iptv/countries/br.m3u`
     - **Guia XMLTV (EPG):** `https://iptv-org.github.io/epg/guides/br/guide.epg.in.xml`
   > [!NOTE]
   > **Realidade das emissoras abertas comerciais (Record, Band, SBT):**
   > Canais públicos educativos e estatais (como **Canal Futura**, **TV Cultura**, **TV Brasil**) transmitem com links diretos permanentes sem restrições e funcionam instantaneamente no Jellyfin.
   > Já a **Record Nacional** e a **Band** utilizam infraestrutura de streaming protegida da Akamai/PlayPlus com tokens JWT de curta duração e restrições de IP regional. Em listas públicas abertas do GitHub, o link da Record (`http://170.84.165.204/Record_HD/index.m3u8`) frequentemente retorna `403 Forbidden` quando o servidor de origem renova as chaves. Para a Record fixa na TV da sala, canais de streaming da **Record News (Pluto TV)** funcionam de forma contínua, ou você pode utilizar uma lista M3U privada/dedicada com proxy de retransmissão integrado.




#### 5.2. Jellyseerr (`http://pedidos.pk.local` ou `:5055`)
1. Crie a conta de administrador ou faça login integrado.
2. Selecione **Jellyfin** como servidor de mídia:
   - **Jellyfin URL:** `http://192.168.0.8` *(use o IP fixo da máquina, pois `umbrel.local` via mDNS não resolve dentro dos containers Docker)*.
   - **Port:** `8096`
   - Faça login com o usuário e senha criados no Jellyfin.
3. Conecte o **Radarr** (`http://radarr:7878`) e o **Sonarr** (`http://sonarr:8989`) inserindo suas respectivas API Keys.
4. *Resultado comprovado:* Ao solicitar qualquer conteúdo pelo Jellyseerr (`http://pedidos.pk.local`):
   - Se já estiver disponível, o Sonarr/Radarr localiza via Prowlarr e envia para o qBittorrent imediatamente.
   - Se o filme for futuro/cinema, ele fica cadastrado e monitorado no Radarr; assim que sair na internet em WEB-DL/BluRay, o download ocorre automaticamente sem nenhuma intervenção humana!


#### 5.3. Nextcloud (Nuvem Pessoal & Compartilhamento Familiar)

O Nextcloud oficial do Umbrel foi totalmente homologado e integrado aos **HDs externos físicos e ao Samba**:

1. **Acesso Web e Credenciais:**
   - URL Local: `http://umbrel.local:8081` (ou `http://192.168.0.8:8081` / `http://nuvem.pk.local`).
   - Usuário Administrador Geral: `umbrel` (senha no painel inicial do Umbrel).
   - Usuário Pessoal Paulo: `paulo` | Senha: `Paulo#Homelab2026` *(trocável no perfil)*.
   - Usuário Pessoal Kamila: `kamila` | Senha: `Kamila#Homelab2026` *(trocável no perfil)*.

2. **Arquitetura de Armazenamento Unificada (Nextcloud ↔ Samba ↔ HDs Externos):**
   - O core do Nextcloud roda rápido no SSD NVMe, mas **todos os arquivos pessoais e compartilhados gravam diretamente nos HDs externos físicos (`disk1`)** via aplicativo oficial *External Storage Support* (`files_external`):
     - **`Meus Arquivos` (Paulo):** Aponta para `/storage/users/paulo` (exatamente o compartilhamento Samba `smb://192.168.0.8/Paulo`). Visível exclusivamente para o Paulo.
     - **`Meus Arquivos` (Kamila):** Aponta para `/storage/users/kamila` (compartilhamento Samba `smb://192.168.0.8/Kamila`). Visível exclusivamente para a Kamila.
     - **`Compartilhado`:** Aponta para `/storage/shared` (compartilhamento Samba `smb://192.168.0.8/Compartilhado`). Visível e editável por ambos!
   - *Resultado prático:* Qualquer arquivo adicionado pelo Samba no Pop!_OS aparece no Nextcloud. Qualquer arquivo enviado pelo app do Nextcloud no celular cai na mesma pasta do Samba!

3. **Mapeamento de Volumes Persistente no Compose:**
   - No `/home/umbrel/umbrel/app-data/nextcloud/docker-compose.yml`:
     ```yaml
     volumes:
       - ${APP_DATA_DIR}/data/nextcloud:/var/www/html
       - /home/umbrel/umbrel/external/disk2/users:/storage/users
       - /home/umbrel/umbrel/external/disk2/shared:/storage/shared
     ```

4. **Acesso Remoto via Tailscale (Configuração de `trusted_domains` e `trusted_proxies`):**
   - Ao acessar o Nextcloud pelo smartphone via Tailscale (`http://<IP_TAILSCALE>:8081` ou `http://<MAGIC_DNS>:8081`), o Nextcloud bloqueia por padrão exibindo *"Acessar através de um domínio não confiável"*.
   - **Solução Canônica e Persistente via `occ` (executada no SSH do mini PC):**
     ```bash
     NC_CONTAINER=$(sudo docker ps --format '{{.Names}}' | grep -E 'nextcloud.*(app|web|server)' | head -n 1)

     # 1. Adicionar o IP do Tailscale e MagicDNS aos domínios confiáveis
     sudo docker exec -u www-data "$NC_CONTAINER" php occ config:system:set trusted_domains 3 --value="<SEU_IP_TAILSCALE>"
     sudo docker exec -u www-data "$NC_CONTAINER" php occ config:system:set trusted_domains 4 --value="<SEU_MAGICDNS_TAILSCALE>"
     sudo docker exec -u www-data "$NC_CONTAINER" php occ config:system:set trusted_domains 5 --value="192.168.0.8"
     sudo docker exec -u www-data "$NC_CONTAINER" php occ config:system:set trusted_domains 6 --value="nuvem.pk.local"
     sudo docker exec -u www-data "$NC_CONTAINER" php occ config:system:set trusted_domains 7 --value="umbrel.local"

     # 2. Configurar a sub-rede do Tailscale e LAN como proxies confiáveis
     sudo docker exec -u www-data "$NC_CONTAINER" php occ config:system:set trusted_proxies 0 --value="100.64.0.0/10"
     sudo docker exec -u www-data "$NC_CONTAINER" php occ config:system:set trusted_proxies 1 --value="192.168.0.0/16"

     # 3. Conferir a lista atualizada
     sudo docker exec -u www-data "$NC_CONTAINER" php occ config:system:get trusted_domains
     ```
   - Essa alteração grava diretamente no arquivo persistente `config/config.php` do Nextcloud no volume do Umbrel, mantendo-se ativa mesmo após reboots.

5. **Como Conectar e Sincronizar em Todos os Dispositivos (Apps Oficiais):**

   > 💡 **Dica de Ouro de Conectividade:**
   > - **Dentro de Casa (Wi-Fi Local):** Use `http://192.168.0.8:8081` ou `http://nuvem.pk.local` (ou `http://umbrel.local:8081`).
   > - **Fora de Casa / 4G / 5G / Qualquer Lugar:** Ative a VPN **Tailscale** no aparelho e use o endereço do Tailscale (ex: `http://<IP_TAILSCALE>:8081` ou `http://<SEU_MAGICDNS_TAILSCALE>:8081`).
   > - **Recomendação Máxima:** Se você mantiver o Tailscale ativo no smartphone, tablet ou notebook, pode cadastrar diretamente o endereço do Tailscale no aplicativo; assim ele sincronizará de forma 100% transparente tanto dentro quanto fora de casa!

   - 📱 **Android (Smartphones & Tablets Samsung - Galaxy / Tab):**
     1. Instale o app oficial **Nextcloud** pela Google Play Store.
     2. Ao abrir, clique em **Entrar (Log in)**.
     3. No campo de endereço do servidor, digite:
        `http://<IP_TAILSCALE>:8081` (ou `http://192.168.0.8:8081` se estiver no Wi-Fi).
     4. Uma janela do navegador interno abrirá solicitando login: entre com `paulo` (ou `kamila`) e a respectiva senha.
     5. Clique em **Conceder Acesso**.
     6. **Dica para Backup de Fotos (Auto Upload):**
        - No menu lateral do app, vá em **Envio automático (Auto upload)**.
        - Ative a pasta `Camera` (DCIM).
        - Marque a opção *"Enviar apenas ao carregar"* e *"Apenas no Wi-Fi"* conforme sua preferência.

   - 🍏 **iOS / iPadOS (iPhone e iPad):**
     1. Instale o app **Nextcloud** pela App Store da Apple.
     2. Abra o app e clique em **Entrar**.
     3. Insira o endereço: `http://<IP_TAILSCALE>:8081` (ou `http://192.168.0.8:8081`).
     4. Autentique-se com sua conta pessoal (`paulo` ou `kamila`).
     5. O Nextcloud no iOS se integra nativamente ao app **Arquivos (Files)** da Apple!
        - Abra o app **Arquivos**, toque nos três pontinhos (`...`) ➡️ **Editar Barra Lateral** e ative a chavinha do **Nextcloud**.
        - Você poderá salvar documentos do Word, PDF, notas e planilhas diretamente no Nextcloud como se fosse o iCloud Drive.

   - 🐧 **Linux (Pop!_OS Desktop):**
     - **Opção 1 (Cliente de Sincronização Oficial - Estilo Google Drive/Dropbox):**
       - Instale o cliente desktop oficial via Flatpak ou APT:
         ```bash
         flatpak install flathub com.nextcloud.desktopclient.nextcloud
         # ou: sudo apt install nextcloud-desktop
         ```
       - Abra o Nextcloud, informe o endereço do servidor (`http://192.168.0.8:8081` ou IP Tailscale), autentique no navegador e escolha qual pasta local deseja manter sincronizada.
     - **Opção 2 (Acesso Direto via Rede Local - Sem ocupar espaço em disco):**
       - No Pop!_OS, o acesso mais rápido aos mesmos arquivos é via **Samba (Nautilus)**:
         Pressione `Ctrl + L` no Nautilus e conecte em `smb://192.168.0.8/Paulo` ou `smb://192.168.0.8/Compartilhado`. Tudo o que você colocar ali já aparece instantaneamente no Nextcloud.

   - 🪟 **Windows (PC / Notebook):**
     1. Baixe o instalador oficial do **Nextcloud Desktop Client** em [nextcloud.com/install](https://nextcloud.com/install/#install-clients).
     2. Instale e abra o programa.
     3. Clique em **Entrar** e insira o endereço `http://192.168.0.8:8081` (ou IP Tailscale).
     4. Autorize no navegador web com seu usuário e senha.
     5. O Nextcloud criará uma pasta no seu Windows Explorer (com suporte a arquivos sob demanda / Virtual Files), permitindo visualizar tudo sem baixar gigabytes desnecessários.

#### 5.4. Syncthing (Sincronização P2P Contínua: Pop!_OS ↔ Mini PC / Nextcloud)

O **Syncthing** roda na stack `management` e permite sincronizar pastas do seu notebook/desktop com o mini PC de forma automática, bidirecional e instantânea:

1. **Acesso Web e Segurança:**
   - URL no Mini PC: `http://192.168.0.8:8384` (ou `http://syncthing.pk.local:8384`).
   - No primeiro acesso, clique em **Ajustes (Settings)** ➡️ aba **GUI** e configure um usuário e senha de administrador para proteger a interface.

2. **Como Parear o Mini PC com seu Pop!_OS:**
   - No seu **Pop!_OS**, abra o Syncthing (se já tiver instalado) ou instale com:
     ```bash
     sudo apt install syncthing
     systemctl --user enable --now syncthing
     ```
     *(Acesse a interface local do seu notebook em `http://localhost:8384`)*.
   - **Obter o ID de Cada Dispositivo:**
     - No Syncthing do mini PC (`http://192.168.0.8:8384`): clique em **Ações** ➡️ **Mostrar ID** e copie o código alfanumérico.
     - No Syncthing do seu Pop!_OS (`http://localhost:8384`): clique em **Adicionar Dispositivo Remoto**, cole o ID do mini PC e salve.
     - Uma notificação amarela de aprovação surgirá no mini PC: basta clicar em **Adicionar Dispositivo**!

3. **Mapeamento de Pastas (Para cair direto no Samba e Nextcloud):**
   - No Syncthing do mini PC, o container tem acesso aos seguintes volumes:
     - `/data/users/paulo` ➡️ Sua pasta pessoal nos HDs externos (`Meus Arquivos` no Nextcloud e `smb://192.168.0.8/Paulo`).
     - `/data/users/kamila` ➡️ Pasta pessoal da Kamila.
   - **Compartilhar uma pasta (ex: Documentos ou Projetos Dev do seu Pop!_OS):**
     1. No Pop!_OS, adicione a pasta local (ex: `/home/rezendepauloh/Documentos`).
     2. Na aba **Compartilhamento**, marque o dispositivo **`umbrel-syncthing`**.
     3. No Syncthing do mini PC, aceite o compartilhamento e defina o **Caminho da Pasta** como:
        `/data/users/paulo/Documentos`
     4. *Resultado imediato:* Tudo que você salvar em `~/Documentos` no seu Pop!_OS sincroniza em background, cai no HD externo de 1TB, aparece no seu Samba e no seu Nextcloud!

#### 5.5. Immich (Fotos e Backup Mobile)
- Instale o app oficial no celular (Android / iOS). Aponte para `http://umbrel.local:2283` (ou `fotos.pk.local`) e ative o backup automático de fotos da câmera.

---

## 3. Tabela de Domínios Amigáveis no NPM (`*.pk.local`)

Para não precisar digitar números de portas, cadastre estes hosts no **Nginx Proxy Manager** (`http://umbrel.local:81`):

| Domínio Desejado | Forward Hostname (Nome Interno) | Porta Interna | Ativar Websockets? |
| :--- | :--- | :---: | :---: |
| `dockge.pk.local` | `dockge` | `5001` | Sim ✅ |
| `npm.pk.local` | `nginx-proxy-manager` | `81` | Não |
| `adguard.pk.local` | `192.168.0.8` *(host)* | `8095` | Não |
| `status.pk.local` | `uptime-kuma` | `3001` | Sim ✅ |
| `it.pk.local` | `it-tools` | `80` | Não |
| `syncthing.pk.local` | `syncthing` | `8384` | Não |
| `jellyfin.pk.local` | `192.168.0.8` *(host)* | `8096` | Sim ✅ |
| `seerr.pk.local` | `jellyseerr` | `5055` | Sim ✅ |
| `home.pk.local` | `192.168.0.8` *(host / Home Assistant)*| `8123` | Sim ✅ |
| `nuvem.pk.local` | `192.168.0.8` *(host / Nextcloud)* | *(porta do app)* | Sim ✅ |
| `fotos.pk.local` | `192.168.0.8` *(host / Immich)* | `2283` | Sim ✅ |
| `torrent.pk.local` | `qbittorrent` | `8085` | Não |
| `prowlarr.pk.local` | `prowlarr` | `9696` | Não |
| `jackett.pk.local` | `jackett` | `9117` | Não |
| `radarr.pk.local` | `radarr` | `7878` | Não |
| `sonarr.pk.local` | `sonarr` | `8989` | Não |
| `bazarr.pk.local` | `bazarr` | `6767` | Não |
| `coolify.pk.local` | `192.168.0.8` *(host)* | `8000` | Sim ✅ |
| `umbrel.pk.local` | `192.168.0.8` *(host)* | `80` | Sim ✅ |

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

