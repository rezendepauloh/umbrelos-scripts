# 🎬 Etapa 4: Gerenciadores de Conteúdo (Radarr, Sonarr e Bazarr)

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
