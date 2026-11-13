# 🍿 Etapa 5: Streaming e Nuvem Familiar (Jellyfin, Nextcloud, Immich, Jellyseerr)

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
   - Usuário Administrador Geral: `umbrel` (senha no painel inicial do Umbrel / `SYSTEM_PASSWORD`).
   - Usuário Pessoal Paulo: `paulo` | Senha: `<definida em config.env / perfil>`.
   - Usuário Pessoal Kamila: `kamila` | Senha: `<definida em config.env / perfil>`.

   > 💡 **Como Recuperar ou Redefinir Senhas de Usuários via Linha de Comando (`occ`):**
   > Se esquecer a senha ou tiver problemas de autenticação, você pode redefini-la diretamente no SSH (`umbrel@192.168.0.8`):
   > ```bash
   > NC_CONTAINER=$(sudo docker ps --format '{{.Names}}' | grep -E 'nextcloud.*(app|web|server)' | head -n 1)
   >
   > # 1. Listar usuários cadastrados no sistema
   > sudo docker exec -u www-data "$NC_CONTAINER" php occ user:list
   >
   > # 2. Redefinir a senha interativamente (mínimo de 10 caracteres)
   > sudo docker exec -it -u www-data "$NC_CONTAINER" php occ user:resetpassword <nome_usuario>
   > ```

2. **Arquitetura de Armazenamento Unificada (Nextcloud ↔ Samba ↔ HDs Externos):**
   - O core do Nextcloud roda rápido no SSD NVMe, mas **todos os arquivos pessoais e compartilhados gravam diretamente nos HDs externos físicos (`disk2`)** via aplicativo oficial *External Storage Support* (`files_external`):
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

#### 5.4. Sincronização de Arquivos: Nextcloud Desktop Client (Ativo) & Syncthing (Standby Estratégico)

1. **Motor de Sincronização Ativo (Nextcloud Desktop Client):**
   - O aplicativo **Nextcloud Desktop Client** (instalado via Flatpak no Pop!_OS e cliente oficial no Windows 11) é o motor oficial e exclusivo para sincronizar as pastas de documentos pessoais e compartilhados:
     - `Meus Arquivos` ➡️ Sincronizado com `/home/umbrel/umbrel/external/disk2/users/<usuario>` e acessível via Samba (`\\192.168.0.8\<Usuario>`).
     - `Compartilhado` ➡️ Sincronizado com `/home/umbrel/umbrel/external/disk2/shared` e acessível via Samba (`\\192.168.0.8\Compartilhado`).
   - No Pop!_OS, o cliente já está configurado no autostart (`21_autostart_config.sh`) rodando com `--background`.
   - **Regra de Ouro:** Não utilize outros programas de sincronização automática (como Syncthing) operando sobre a mesma pasta local do Nextcloud para evitar concorrência de *file locks* e duplicações.

2. **Syncthing (Operacional no Homelab / Standby nos Clientes):**
   - O container **Syncthing** roda na stack `management` (`http://192.168.0.8:8384` ou `http://syncthing.pk.local:8384`) e está 100% funcional.
   - O pacote e as regras de firewall (`22000/tcp`, `22000/udp`, `21027/udp`) já estão integrados nos scripts de automação do Pop!_OS (`04_pacotes_base_dev.sh` e `26_limpeza_otimizacao.sh`).
   - Mantenha-o como uma ferramenta de reserva/standby para fluxos onde o Nextcloud não seja ideal (ex: sincronização P2P contínua de diretórios pesados de código-fonte, repositórios git locais ou pastas temporárias de alta taxa de escrita).

#### 5.5. Immich (Google Fotos Auto-Hospedado com IA, Reconhecimento Facial e Backup Mobile)

O **Immich** é a alternativa definitiva e moderna ao Google Fotos / Apple Photos. Ele roda na porta `:2283` (`http://192.168.0.8:2283` ou `http://fotos.pk.local`):

1. **Armazenamento Seguro das Fotos no HD Externo (`disk2/immich`):**
   - Os arquivos de fotos originais, vídeos, miniaturas e backups são armazenados diretamente no disco dedicado:
     `/home/umbrel/umbrel/external/disk2/immich`
   - O volume é mantido persistente no `homelab-daemon.sh`, garantindo que atualizações da App Store do Umbrel não resetem o ponto de montagem.

2. **Primeiro Acesso e Configuração de Administrador:**
   - Acesse no navegador: `http://192.168.0.8:2283` (ou `http://fotos.pk.local`).
   - Clique em **Getting Started** e crie a conta do Administrador principal (`Paulo`).
   - No painel de administração (**Administration** ➡️ **User Management**):
     - Crie o usuário para `Kamila` com e-mail e senha segura.
     - *(Opcional)* Ative o **Partner Sharing** (Compartilhamento de Parceiro) para que você e a Kamila possam visualizar as fotos um do outro diretamente na linha do tempo principal ou em abas separadas.

3. **Configuração nos Celulares (Android e iOS):**
   - Baixe o aplicativo oficial **Immich** na [Google Play Store](https://play.google.com/store/apps/details?id=app.alextran.immich) ou na [App Store da Apple](https://apps.apple.com/app/immich/id1613945652).
   - Ao abrir o app, insira a **Server Endpoint URL**:
     - *No Wi-Fi de casa:* `http://fotos.pk.local:2283` (ou `http://192.168.0.8:2283`).
     - *Fora de casa / 4G / 5G:* Conecte a VPN **Tailscale** no celular e use o IP Tailscale do mini PC (ex: `http://<IP_TAILSCALE>:2283`).
   - Faça login com sua conta.
   - Na aba **Backup**:
     - Selecione os álbuns da câmera que deseja sincronizar (`DCIM/Camera`, `WhatsApp Images`, etc.).
     - Ative o backup em segundo plano (*Background backup*).
