# 📥 Etapa 3: Cliente de Download e Indexadores (qBittorrent + Prowlarr)

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
