# 🏠 Etapa 5 (Especial): Home Assistant & Automação Residencial Completa

#### 5.6. Home Assistant (Automação Residencial & Casa Inteligente)

O **Home Assistant** roda na porta `:8123` em modo de rede `host` (`http://192.168.0.8:8123` ou `http://home.pk.local` via Nginx Proxy Manager). O modo `host` permite a auto-descoberta transparente de dispositivos locais mDNS, SSDP, UPnP e ONVIF:

1. **Primeiro Acesso e Conta de Administrador:**
   - Acesse no navegador: `http://home.pk.local` (ou `http://192.168.0.8:8123`).
   - Crie seu usuário e senha master de administrador.
   - Confirme o fuso horário como **`America/Campo_Grande`** (UTC-4) e sistema métrico.

2. **HACS (Home Assistant Community Store):**
   - O HACS é a loja da comunidade que viabiliza integrações customizadas avançadas (como Xiaomi Miot e Alexa Media Player).
   - **Instalação no container (executada no SSH do mini PC):**
     ```bash
     sudo docker exec home-assistant_server_1 sh -c 'wget -O - https://get.hacs.xyz | bash -'
     sudo docker restart home-assistant_server_1
     ```
   - **Ativação na interface web:**
     - Vá em **Configurações** ⚙️ ➡️ **Dispositivos e Serviços** ➡️ **+ Adicionar Integração**.
     - Pesquise por **HACS**, marque os termos de aceite e insira o código de autenticação gerado no link `github.com/login/device`.

3. **Integração Robô Aspirador Xiaomi (Xiaomi Home):**
   - No menu lateral **HACS** ➡️ **+ Explorar e baixar repositórios** ➡️ busque por **`Xiaomi Miot Auto`** e faça o download.
   - Reinicie o Home Assistant.
   - Em **Configurações ⚙️ ➡️ Dispositivos e Serviços ➡️ + Adicionar Integração**, selecione **Xiaomi Miot Auto**:
     - Método de autenticação: **Log in with Xiaomi account**.
     - Informe as credenciais da sua conta Xiaomi (e-mail/ID e senha) e o servidor (Brasil / `br` ou Outro).
     - O robô aspirador é importado com mapa, sensores de desgaste de acessórios (escova, filtro), nível de bateria e controles completos de sucção e limpeza.

4. **Integração Câmeras ICSee (ONVIF / RTSP Local):**
   - As câmeras compatíveis com o app **ICSee** (Xiongmai) operam nativamente por **ONVIF** e **RTSP** na rede local:
     - **Porta ONVIF:** `8899`
     - **Porta RTSP de Mídia:** `554`
     - **Porta do App ICSee / NetSurveillance:** `34567`
   - Em **Configurações ⚙️ ➡️ Dispositivos e Serviços ➡️ + Adicionar Integração**, busque por **ONVIF**:
     - **Nome:** `Câmera ICSee` *(ou o cômodo correspondente)*.
     - **Host:** IP local da câmera (ex: `192.168.0.4`).
     - **Porta:** `8899` (ou `554`).
     - **Usuário:** `admin`
     - **Senha:** A senha cadastrada para a câmera no app ICSee.
   - *Resultado:* Transmissão de vídeo ao vivo com baixa latência, snapshots e sensores de movimento disponíveis diretamente no dashboard do Home Assistant.
   - **Dashboard Personalizado WebRTC + Controles PTZ + Gravação:**
     Para criar um painel dedicado em tela cheia com vídeo de baixa latência, rotação da câmera (Pan/Tilt corrigido), botões de foto e gravação de vídeo de 30s com download direto:
     1. Crie um painel do zero em **Configurações ➡️ Painéis** chamado `Câmeras`.
     2. Adicione uma visualização com layout **Painel (cartão único)** e insira um cartão **Manual** com o código YAML:
     ```yaml
     type: vertical-stack
     cards:
       - type: custom:webrtc-camera
         entity: camera.camera_icsee_mainstream
         muted: false
         media: video,audio,microphone
         shortcuts:
           - name: Microfone
             icon: mdi:microphone
       - type: horizontal-stack
         cards:
           - type: button
             name: Esquerda
             icon: mdi:arrow-left-bold
             tap_action:
               action: perform-action
               perform_action: onvif.ptz
               target:
                 entity_id: camera.camera_icsee_mainstream
               data:
                 pan: RIGHT
                 move_mode: ContinuousMove
           - type: button
             name: Cima
             icon: mdi:arrow-up-bold
             tap_action:
               action: perform-action
               perform_action: onvif.ptz
               target:
                 entity_id: camera.camera_icsee_mainstream
               data:
                 tilt: DOWN
                 move_mode: ContinuousMove
           - type: button
             name: Baixo
             icon: mdi:arrow-down-bold
             tap_action:
               action: perform-action
               perform_action: onvif.ptz
               target:
                 entity_id: camera.camera_icsee_mainstream
               data:
                 tilt: UP
                 move_mode: ContinuousMove
           - type: button
             name: Direita
             icon: mdi:arrow-right-bold
             tap_action:
               action: perform-action
               perform_action: onvif.ptz
               target:
                 entity_id: camera.camera_icsee_mainstream
               data:
                 pan: LEFT
                 move_mode: ContinuousMove
       - type: horizontal-stack
         cards:
           - type: button
             name: Tirar Foto
             icon: mdi:camera
             tap_action:
               action: perform-action
               perform_action: camera.snapshot
               target:
                 entity_id: camera.camera_icsee_mainstream
               data:
                 filename: /config/www/recordings/foto.jpg
           - type: button
             name: Baixar Foto
             icon: mdi:tray-arrow-down
             tap_action:
               action: url
               url_path: /local/recordings/foto.jpg
           - type: button
             name: Gravar 30s
             icon: mdi:record-rec
             tap_action:
               action: perform-action
               perform_action: camera.record
               target:
                 entity_id: camera.camera_icsee_mainstream
               data:
                 filename: /config/www/recordings/ultimo_video.mp4
                 duration: 30
           - type: button
             name: Baixar Vídeo
             icon: mdi:download
             tap_action:
               action: url
               url_path: /local/recordings/ultimo_video.mp4
     ```
     *(Os arquivos de mídia ficam disponíveis em `/local/recordings/` com rota permitida no `configuration.yaml` via `allowlist_external_dirs`).*

5. **Integração Alimentador Rojeco (Tuya / Smart Life):**
   - O hardware dos alimentadores Rojeco é baseado na plataforma Tuya:
     - O alimentador pode ser pareado pelo app **Tuya Smart** ou **Smart Life** (colocando-o em modo de pareamento com o botão de Wi-Fi pressionado por 5s).
   - Em **Configurações ⚙️ ➡️ Dispositivos e Serviços ➡️ + Adicionar Integração**, selecione **Tuya**.
   - Abra o app Tuya/Smart Life no smartphone, use a função de leitura de QR Code para ler o código na tela do Home Assistant e confirme a vinculação.
   - *Resultado:* Entidades de acionamento manual de porções, acompanhamento de registros de alimentação e alertas de reservatório vazio.

6. **Integração Alexa (Amazon Echo - Anúncios por Voz e Mídia):**
   - No **HACS** ➡️ **+ Explorar e baixar repositórios** ➡️ instale a integração **`Alexa Media Player`**.
   - Reinicie o Home Assistant.
   - Em **Configurações ⚙️ ➡️ Dispositivos e Serviços ➡️ + Adicionar Integração**, selecione **Alexa Media Player**:
     - Insira seu e-mail e senha da Amazon.
     - Domínio: **`amazon.com.br`**.
     - Complete a verificação em duas etapas (2FA/OTP).
   - *Resultado:* Suas caixas Echo funcionam como reprodutores de som e você pode criar automações com TTS (Text-to-Speech) para que a Alexa avise em voz alta quando o robô terminar de aspirar ou quando a comida dos gatos for servida.

7. **Smart TVs Samsung & Projetor The Freestyle (Controle Remoto Tizen):**
   - As TVs e projetores Samsung são integrados via protocolo websocket nativo (`samsungtv` / porta `8002`):
     - **TV da Sala:** `media_player.tv_paumila_un70cu7700gxzd` / `remote.tv_paumila_un70cu7700gxzd` (IP `192.168.0.5`, MAC `1c:af:4a:d4:c6:e2`).
     - **Projetor Paumila:** `media_player.projetor_paumila_sp_lsp3blaxza` / `remote.projetor_paumila_sp_lsp3blaxza` (IP `192.168.0.13`, MAC `80:8a:bd:2e:1a:d8`).
   - O controle remoto D-Pad utiliza o serviço unificado `remote.send_command` enviando comandos diretos (`KEY_UP`, `KEY_DOWN`, `KEY_LEFT`, `KEY_RIGHT`, `KEY_ENTER`, `KEY_HOME`, `KEY_RETURN`, teclas numéricas e cores de teletexto `KEY_RED`, `KEY_GREEN`, `KEY_YELLOW`, `KEY_CYAN`).
   - **Modelo YAML do Controle Remoto (TV da Sala):**
     ```yaml
     type: vertical-stack
     cards:
       - type: media-control
         entity: media_player.tv_paumila_un70cu7700gxzd
       - type: grid
         columns: 3
         square: false
         cards:
           - type: button
             name: Ligar/Desligar
             icon: mdi:power
             tap_action:
               action: perform-action
               perform_action: remote.toggle
               target:
                 entity_id: remote.tv_paumila_un70cu7700gxzd
           - type: button
             name: Início (Home)
             icon: mdi:home
             tap_action:
               action: perform-action
               perform_action: remote.send_command
               target:
                 entity_id: remote.tv_paumila_un70cu7700gxzd
               data:
                 command: KEY_HOME
           - type: button
             name: Voltar
             icon: mdi:undo
             tap_action:
               action: perform-action
               perform_action: remote.send_command
               target:
                 entity_id: remote.tv_paumila_un70cu7700gxzd
               data:
                 command: KEY_RETURN
       - type: grid
         columns: 3
         square: true
         cards:
           - type: button
             icon: mdi:blank
           - type: button
             name: Cima
             icon: mdi:chevron-up
             tap_action:
               action: perform-action
               perform_action: remote.send_command
               target:
                 entity_id: remote.tv_paumila_un70cu7700gxzd
               data:
                 command: KEY_UP
           - type: button
             icon: mdi:blank
           - type: button
             name: Esquerda
             icon: mdi:chevron-left
             tap_action:
               action: perform-action
               perform_action: remote.send_command
               target:
                 entity_id: remote.tv_paumila_un70cu7700gxzd
               data:
                 command: KEY_LEFT
           - type: button
             name: OK
             icon: mdi:checkbox-blank-circle
             tap_action:
               action: perform-action
               perform_action: remote.send_command
               target:
                 entity_id: remote.tv_paumila_un70cu7700gxzd
               data:
                 command: KEY_ENTER
           - type: button
             name: Direita
             icon: mdi:chevron-right
             tap_action:
               action: perform-action
               perform_action: remote.send_command
               target:
                 entity_id: remote.tv_paumila_un70cu7700gxzd
               data:
                 command: KEY_RIGHT
           - type: button
             icon: mdi:blank
           - type: button
             name: Baixo
             icon: mdi:chevron-down
             tap_action:
               action: perform-action
               perform_action: remote.send_command
               target:
                 entity_id: remote.tv_paumila_un70cu7700gxzd
               data:
                 command: KEY_DOWN
           - type: button
             icon: mdi:blank
       - type: horizontal-stack
         cards:
           - type: button
             name: Vol -
             icon: mdi:volume-minus
             tap_action:
               action: perform-action
               perform_action: media_player.volume_down
               target:
                 entity_id: media_player.tv_paumila_un70cu7700gxzd
           - type: button
             name: Mudo
             icon: mdi:volume-mute
             tap_action:
               action: perform-action
               perform_action: media_player.volume_mute
               target:
                 entity_id: media_player.tv_paumila_un70cu7700gxzd
           - type: button
             name: Vol +
             icon: mdi:volume-plus
             tap_action:
               action: perform-action
               perform_action: media_player.volume_up
               target:
                 entity_id: media_player.tv_paumila_un70cu7700gxzd
       - type: grid
         columns: 4
         square: false
         cards:
           - type: button
             name: Vermelho
             icon: mdi:circle
             tap_action:
               action: perform-action
               perform_action: remote.send_command
               target:
                 entity_id: remote.tv_paumila_un70cu7700gxzd
               data:
                 command: KEY_RED
           - type: button
             name: Verde
             icon: mdi:circle
             tap_action:
               action: perform-action
               perform_action: remote.send_command
               target:
                 entity_id: remote.tv_paumila_un70cu7700gxzd
               data:
                 command: KEY_GREEN
           - type: button
             name: Amarelo
             icon: mdi:circle
             tap_action:
               action: perform-action
               perform_action: remote.send_command
               target:
                 entity_id: remote.tv_paumila_un70cu7700gxzd
               data:
                 command: KEY_YELLOW
           - type: button
             name: Azul
             icon: mdi:circle
             tap_action:
               action: perform-action
               perform_action: remote.send_command
               target:
                 entity_id: remote.tv_paumila_un70cu7700gxzd
               data:
                 command: KEY_CYAN
       - type: grid
         columns: 3
         square: false
         cards:
           - type: button
             name: "1"
             tap_action:
               action: perform-action
               perform_action: remote.send_command
               target:
                 entity_id: remote.tv_paumila_un70cu7700gxzd
               data:
                 command: KEY_1
           - type: button
             name: "2"
             tap_action:
               action: perform-action
               perform_action: remote.send_command
               target:
                 entity_id: remote.tv_paumila_un70cu7700gxzd
               data:
                 command: KEY_2
           - type: button
             name: "3"
             tap_action:
               action: perform-action
               perform_action: remote.send_command
               target:
                 entity_id: remote.tv_paumila_un70cu7700gxzd
               data:
                 command: KEY_3
           - type: button
             name: "4"
             tap_action:
               action: perform-action
               perform_action: remote.send_command
               target:
                 entity_id: remote.tv_paumila_un70cu7700gxzd
               data:
                 command: KEY_4
           - type: button
             name: "5"
             tap_action:
               action: perform-action
               perform_action: remote.send_command
               target:
                 entity_id: remote.tv_paumila_un70cu7700gxzd
               data:
                 command: KEY_5
           - type: button
             name: "6"
             tap_action:
               action: perform-action
               perform_action: remote.send_command
               target:
                 entity_id: remote.tv_paumila_un70cu7700gxzd
               data:
                 command: KEY_6
           - type: button
             name: "7"
             tap_action:
               action: perform-action
               perform_action: remote.send_command
               target:
                 entity_id: remote.tv_paumila_un70cu7700gxzd
               data:
                 command: KEY_7
           - type: button
             name: "8"
             tap_action:
               action: perform-action
               perform_action: remote.send_command
               target:
                 entity_id: remote.tv_paumila_un70cu7700gxzd
               data:
                 command: KEY_8
           - type: button
             name: "9"
             tap_action:
               action: perform-action
               perform_action: remote.send_command
               target:
                 entity_id: remote.tv_paumila_un70cu7700gxzd
               data:
                 command: KEY_9
           - type: button
             icon: mdi:blank
           - type: button
             name: "0"
             tap_action:
               action: perform-action
               perform_action: remote.send_command
               target:
                 entity_id: remote.tv_paumila_un70cu7700gxzd
               data:
                 command: KEY_0
           - type: button
             icon: mdi:blank
     ```
   - **Modelo YAML do Controle Remoto (Projetor Paumila):**
     ```yaml
     type: vertical-stack
     cards:
       - type: media-control
         entity: media_player.projetor_paumila_sp_lsp3blaxza
       - type: grid
         columns: 3
         square: false
         cards:
           - type: button
             name: Ligar/Desligar
             icon: mdi:power
             tap_action:
               action: perform-action
               perform_action: remote.toggle
               target:
                 entity_id: remote.projetor_paumila_sp_lsp3blaxza
           - type: button
             name: Início (Home)
             icon: mdi:home
             tap_action:
               action: perform-action
               perform_action: remote.send_command
               target:
                 entity_id: remote.projetor_paumila_sp_lsp3blaxza
               data:
                 command: KEY_HOME
           - type: button
             name: Voltar
             icon: mdi:undo
             tap_action:
               action: perform-action
               perform_action: remote.send_command
               target:
                 entity_id: remote.projetor_paumila_sp_lsp3blaxza
               data:
                 command: KEY_RETURN
       - type: grid
         columns: 3
         square: true
         cards:
           - type: button
             icon: mdi:blank
           - type: button
             name: Cima
             icon: mdi:chevron-up
             tap_action:
               action: perform-action
               perform_action: remote.send_command
               target:
                 entity_id: remote.projetor_paumila_sp_lsp3blaxza
               data:
                 command: KEY_UP
           - type: button
             icon: mdi:blank
           - type: button
             name: Esquerda
             icon: mdi:chevron-left
             tap_action:
               action: perform-action
               perform_action: remote.send_command
               target:
                 entity_id: remote.projetor_paumila_sp_lsp3blaxza
               data:
                 command: KEY_LEFT
           - type: button
             name: OK
             icon: mdi:checkbox-blank-circle
             tap_action:
               action: perform-action
               perform_action: remote.send_command
               target:
                 entity_id: remote.projetor_paumila_sp_lsp3blaxza
               data:
                 command: KEY_ENTER
           - type: button
             name: Direita
             icon: mdi:chevron-right
             tap_action:
               action: perform-action
               perform_action: remote.send_command
               target:
                 entity_id: remote.projetor_paumila_sp_lsp3blaxza
               data:
                 command: KEY_RIGHT
           - type: button
             icon: mdi:blank
           - type: button
             name: Baixo
             icon: mdi:chevron-down
             tap_action:
               action: perform-action
               perform_action: remote.send_command
               target:
                 entity_id: remote.projetor_paumila_sp_lsp3blaxza
               data:
                 command: KEY_DOWN
           - type: button
             icon: mdi:blank
       - type: horizontal-stack
         cards:
           - type: button
             name: Vol -
             icon: mdi:volume-minus
             tap_action:
               action: perform-action
               perform_action: media_player.volume_down
               target:
                 entity_id: media_player.projetor_paumila_sp_lsp3blaxza
           - type: button
             name: Mudo
             icon: mdi:volume-mute
             tap_action:
               action: perform-action
               perform_action: media_player.volume_mute
               target:
                 entity_id: media_player.projetor_paumila_sp_lsp3blaxza
           - type: button
             name: Vol +
             icon: mdi:volume-plus
             tap_action:
               action: perform-action
               perform_action: media_player.volume_up
               target:
                 entity_id: media_player.projetor_paumila_sp_lsp3blaxza
       - type: grid
         columns: 4
         square: false
         cards:
           - type: button
             name: Vermelho
             icon: mdi:circle
             tap_action:
               action: perform-action
               perform_action: remote.send_command
               target:
                 entity_id: remote.projetor_paumila_sp_lsp3blaxza
               data:
                 command: KEY_RED
           - type: button
             name: Verde
             icon: mdi:circle
             tap_action:
               action: perform-action
               perform_action: remote.send_command
               target:
                 entity_id: remote.projetor_paumila_sp_lsp3blaxza
               data:
                 command: KEY_GREEN
           - type: button
             name: Amarelo
             icon: mdi:circle
             tap_action:
               action: perform-action
               perform_action: remote.send_command
               target:
                 entity_id: remote.projetor_paumila_sp_lsp3blaxza
               data:
                 command: KEY_YELLOW
           - type: button
             name: Azul
             icon: mdi:circle
             tap_action:
               action: perform-action
               perform_action: remote.send_command
               target:
                 entity_id: remote.projetor_paumila_sp_lsp3blaxza
               data:
                 command: KEY_CYAN
       - type: grid
         columns: 3
         square: false
         cards:
           - type: button
             name: "1"
             tap_action:
               action: perform-action
               perform_action: remote.send_command
               target:
                 entity_id: remote.projetor_paumila_sp_lsp3blaxza
               data:
                 command: KEY_1
           - type: button
             name: "2"
             tap_action:
               action: perform-action
               perform_action: remote.send_command
               target:
                 entity_id: remote.projetor_paumila_sp_lsp3blaxza
               data:
                 command: KEY_2
           - type: button
             name: "3"
             tap_action:
               action: perform-action
               perform_action: remote.send_command
               target:
                 entity_id: remote.projetor_paumila_sp_lsp3blaxza
               data:
                 command: KEY_3
           - type: button
             name: "4"
             tap_action:
               action: perform-action
               perform_action: remote.send_command
               target:
                 entity_id: remote.projetor_paumila_sp_lsp3blaxza
               data:
                 command: KEY_4
           - type: button
             name: "5"
             tap_action:
               action: perform-action
               perform_action: remote.send_command
               target:
                 entity_id: remote.projetor_paumila_sp_lsp3blaxza
               data:
                 command: KEY_5
           - type: button
             name: "6"
             tap_action:
               action: perform-action
               perform_action: remote.send_command
               target:
                 entity_id: remote.projetor_paumila_sp_lsp3blaxza
               data:
                 command: KEY_6
           - type: button
             name: "7"
             tap_action:
               action: perform-action
               perform_action: remote.send_command
               target:
                 entity_id: remote.projetor_paumila_sp_lsp3blaxza
               data:
                 command: KEY_7
           - type: button
             name: "8"
             tap_action:
               action: perform-action
               perform_action: remote.send_command
               target:
                 entity_id: remote.projetor_paumila_sp_lsp3blaxza
               data:
                 command: KEY_8
           - type: button
             name: "9"
             tap_action:
               action: perform-action
               perform_action: remote.send_command
               target:
                 entity_id: remote.projetor_paumila_sp_lsp3blaxza
               data:
                 command: KEY_9
           - type: button
             icon: mdi:blank
           - type: button
             name: "0"
             tap_action:
               action: perform-action
               perform_action: remote.send_command
               target:
                 entity_id: remote.projetor_paumila_sp_lsp3blaxza
               data:
                 command: KEY_0
           - type: button
             icon: mdi:blank
     ```

---
