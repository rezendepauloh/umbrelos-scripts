# 🚀 umbrelOS Homelab Setup Suite

[![umbrelOS](https://img.shields.io/badge/umbrelOS-v1.x-blue.svg)](https://umbrel.com)
[![Hardware](https://img.shields.io/badge/Hardware-Blackview%20MP100%20Pro-green.svg)](https://www.blackview.hk)
[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED.svg)](https://www.docker.com)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](#)

> Guia passo a passo completo e suíte de automação pós-instalação idempotente para transformar o **Mini PC Blackview MP100 Pro (Intel Core i5-12450H / 16GB RAM / 1TB NVMe)** em uma central de Homelab poderosa, silenciosa e com armazenamento distribuído (NVMe + HDs Externos).

---

## 📋 Sumário
1. [Visão Geral do Homelab](#-visão-geral-do-homelab)
2. [Arquitetura de Armazenamento e Serviços](#-arquitetura-de-armazenamento-e-serviços)
3. [Guia Passo a Passo: Do Zero ao Homelab Operacional](#-guia-passo-a-passo-do-zero-ao-homelab-operacional)
   - [Fase 1: Download e Preparação do Pendrive Bootável](#fase-1-download-e-preparação-do-pendrive-bootável)
   - [Fase 2: Instalação no Blackview MP100 Pro (Clonagem para o NVMe)](#fase-2-instalação-no-blackview-mp100-pro-clonando-para-o-ssd-nvme-de-1tb)
   - [Fase 3: Primeiro Acesso e Configuração Inicial (Onboarding)](#fase-3-primeiro-acesso-e-configuração-inicial-onboarding)
   - [Fase 4: Instalação dos Apps Oficiais na App Store do umbrelOS](#fase-4-instalação-dos-apps-oficiais-na-app-store-do-umbrelos)
   - [Fase 5: Preparação dos 3 HDs Externos (MergerFS + SnapRAID)](#fase-5-preparação-dos-3-hds-externos-mergerfs--snapraid)
   - [Fase 6: Envio dos Scripts e Execução da Automação no Mini PC](#fase-6-envio-dos-scripts-e-execução-da-automação-no-mini-pc)
   - [Fase 7: Configuração dos Domínios Amigáveis Locais (*.pk.local)](#fase-7-configuração-dos-domínios-amigáveis-locais-pklocal)
4. [Configuração dos Serviços e Integrações](#-configuração-dos-serviços-e-integrações)
   - [Immich (Fotos) e Nextcloud (Nuvem Pessoal)](#immich-fotos-e-nextcloud-nuvem-pessoal)
   - [Jellyfin (Quick Sync) + Stack Arr + qBittorrent](#jellyfin-quick-sync--stack-arr--qbittorrent)
   - [Home Assistant e Dispositivos Inteligentes](#home-assistant-e-dispositivos-inteligentes)
   - [Compartilhamentos Samba na Rede Local (Windows / Linux / Smart TVs)](#compartilhamentos-samba-na-rede-local-windows--linux--smart-tvs)
   - [Acesso Remoto Seguro (Tailscale) e Bloqueio de Anúncios (AdGuard Home)](#acesso-remoto-seguro-tailscale-e-bloqueio-de-anúncios-adguard-home)
5. [Gerenciamento e Monitoramento (Dockge, Uptime Kuma, IT-Tools)](#-gerenciamento-e-monitoramento)
6. [Blindagem Contra Falhas de Energia (Crash-Resilience Sem Nobreak)](#-blindagem-contra-falhas-de-energia)
7. [Tabela de Portas e Serviços](#-tabela-de-portas-e-serviços)

---

## 🌟 Visão Geral do Homelab

O **Blackview MP100 Pro** foi projetado com especificações ideais para homelabs modernos:
- **Processador**: Intel Core i5-12450H (8 núcleos, 12 threads até 4.4GHz).
- **GPU Integrada**: Intel UHD Graphics com **Intel Quick Sync Video** (decodificação/transcodificação de vídeo em tempo real por hardware).
- **Memória**: 16 GB DDR4.
- **Armazenamento Interno**: 1 TB NVMe SSD M.2 (I/O de alta performance).
- **Armazenamento Externo**: 2 ou 3 HDs Externos USB (armazenamento em massa para filmes, séries, backups, uploads pesados do Immich e Nextcloud).

---

## 🏗️ Arquitetura de Armazenamento e Serviços

```
+--------------------------------------------------------------------------------+
|                        MINI PC BLACKVIEW MP100 PRO                             |
|                                                                                |
|  [ 1TB NVMe SSD ]                                                              |
|  ├── umbrelOS 1.x (Sistema Operacional base Debian)                            |
|  ├── Docker Containers & Volumes de Configuração                               |
|  └── Bancos de Dados de Alta Performance:                                      |
|      ├── PostgreSQL (Immich & Nextcloud)                                       |
|      └── SQLite / Bases de Catálogo (Jellyfin, Home Assistant)                 |
|                                                                                |
|  [ 3x HDs Externos USB Nativos (3 TB Úteis Reais) ]                             |
|  ├── disk1 (/home/umbrel/umbrel/external/disk1 - 1TB Seagate):                 |
|  │   └── media/ (movies, series, music, torrents) -> Jellyfin & Arr-Stack       |
|  ├── disk2 (/home/umbrel/umbrel/external/disk2 - 1TB A-DATA):                  |
|  │   ├── users/ (paulo, kamila) -> Samba Pessoal & Nextcloud "Meus Arquivos"   |
|  │   ├── shared/                -> Samba & Nextcloud "Compartilhado"            |
|  │   └── immich/library/        -> Fotos & Vídeos Familiares                    |
|  └── disk3 (/home/umbrel/umbrel/external/disk3 - 1TB Samsung):                 |
|      └── backups/               -> Backups locais de contingência               |
|                                                                                |
|  [ Estratégia de Backup Externo Automatizado (Regra 3-2-1) ]                   |
|  └── Cron diário -> rsync SSH -> Desktop Pop!_OS (/mnt/storage_930)            |
|      (Ping inteligente, dumps de bancos .sql.gz, retenção de 7 dias)           |
+--------------------------------------------------------------------------------+
```

---

## 📖 Guia Passo a Passo: Do Zero ao Homelab Operacional

### Fase 1: Download e Preparação do Pendrive Bootável

1. **Download da Imagem do umbrelOS**:
   - Acesse o site oficial ou repositório do umbrelOS: [umbrel.com](https://umbrel.com).
   - O arquivo baixado para PCs x86_64 é compactado: `umbrelos-amd64.img.xz`.

2. **Como Preparar o Pendrive (Escolha a Opção A ou B)**:

   #### 🔹 Opção A: Usando seu Pendrive com Ventoy (Recomendado)
   O Ventoy **não reconhece arquivos com extensão dupla compactada (`.xz`)**, ele precisa do arquivo `.img` puro descompactado:
   
   - **Passo 1: Descompactar o `.img.xz` no PopOS**:
     Abra o terminal na pasta onde você baixou a imagem (geralmente `Downloads`):
     ```bash
     cd /mnt/storage_700/Downloads/
     # Descompacta mantendo o arquivo original (-k) ou sem -k para economizar espaço:
     unxz -k umbrelos-amd64.img.xz
     ```
     *Isso vai gerar o arquivo descompactado bruto: `umbrelos-amd64.img`.*

   - **Passo 2: Copiar para o Ventoy**:
     - Copie o arquivo `umbrelos-amd64.img` diretamente para a partição do seu pendrive Ventoy.
     - *(Dica de compatibilidade do Ventoy)*: Se o seu Ventoy não listar o `.img` no menu de boot, renomeie o arquivo no pendrive para adicionar a extensão `.vtoy`:
       ```text
       umbrelos-amd64.img.vtoy
       ```
       *(O sufixo `.vtoy` força o Ventoy a tratar a imagem de disco raw no modo de emulação de disco rígido).*

   ---

   #### 🔹 Opção B: Gravando Direto no Pendrive (Balena Etcher ou Popsicle)
   > ⚠️ **Atenção**: Esta opção formata o pendrive inteiro, sobrescrevendo o Ventoy se usado no mesmo pendrive.
   - O **Balena Etcher** e o **Popsicle** aceitam o `.img.xz` diretamente sem precisar descompactar antes:
     ```bash
     popsicle
     ```
   - Selecione o arquivo `umbrelos-amd64.img.xz`, escolha o pendrive e clique em **Flash**.

---

### Fase 2: Instalação no Blackview MP100 Pro (Clonando para o SSD NVMe de 1TB)

> 💡 **Como o umbrelOS se comporta**: Ao gravar a imagem no pendrive com o Balena Etcher, o sistema dará boot diretamente a partir do pendrive USB (como sistema imutável Rugix/overlayfs). O procedimento abaixo limpa a instalação de fábrica do Windows e clona o umbrelOS em definitivo para o SSD NVMe interno de 1TB de alta velocidade.

1. **Conexões Iniciais**:
   - Conecte o Blackview MP100 Pro à energia, um cabo de rede Ethernet (conectado ao seu roteador) e o pendrive USB gravado.
   - Conecte teclado e monitor HDMI temporariamente.
   - *(Recomendação)*: Deixe os HDs externos desconectados durante essa etapa para evitar qualquer confusão entre os discos.

2. **Boot pelo Pendrive**:
   - Ligue o Mini PC e pressione repetidamente a tecla `Del` ou `F7` para entrar no menu de **Boot / BIOS UEFI**.
   - Selecione o pendrive USB como primeira opção de boot.
   - Pressione `F10` para salvar e reiniciar.

3. **Login no Terminal do umbrelOS**:
   - Quando o sistema carregar na tela, ele exibirá:
     ```text
     Your Umbrel is now accessible at:
       http://umbrel.local
       http://192.168.0.X

     umbrel login:
     ```
   - Faça login diretamente pelo teclado:
     - **Usuário**: `umbrel`
     - **Senha**: `umbrel`

4. **Verificar os Discos**:
   - Digite no terminal:
     ```bash
     lsblk
     ```
   - Identifique os discos:
     - `sda`: Pendrive USB (com as partições montadas do sistema ativo).
     - `nvme0n1`: SSD NVMe interno de 1TB (com as partições antigas de fábrica do Windows).

5. **Limpar o Windows e Clonar o umbrelOS para o NVMe**:
   - **Passo A: Limpar todas as assinaturas e partições antigas do Windows**:
     ```bash
     sudo wipefs --all --force /dev/nvme0n1
     ```
     *(Senha do sudo: `umbrel`)*.
   
   - **Passo B: Clonar o sistema diretamente do pendrive (`sda`) para o NVMe (`nvme0n1`)**:
     ```bash
     sudo dd if=/dev/sda of=/dev/nvme0n1 bs=4M status=progress conv=fsync
     ```
     *(Aguarde cerca de 1 a 3 minutos até que a cópia termine).*

6. **Desligar e Remover o Pendrive**:
   - Quando o comando `dd` terminar, desligue o Mini PC:
     ```bash
     sudo poweroff
     ```
   - Remova o pendrive USB da porta do computador e ligue o Blackview MP100 Pro.

7. **Ajuste Fino Pós-Clonagem (Expandir Partição e Evitar Erro de RAID)**:
   > ⚠️ **Por que esse passo é necessário**: O `dd` clona a tabela no tamanho exato do pendrive anterior (~124GB). Para que o umbrelOS reconheça os **1024GB (1TB) completos do NVMe** e não caia na tela `/raid-error`, faça login via SSH (`ssh umbrel@umbrel.local`) ou no terminal local e execute:

   - **Passo A: Expandir a partição 6 para 100% do disco**:
     ```bash
     sudo parted /dev/nvme0n1 resizepart 6 100%
     ```
     *(Se o parted exibir uma informação sobre fstab, é apenas um aviso de sucesso).*

   - **Passo B: Formatar a partição de dados em ext4 com o Label `data`**:
     ```bash
     sudo mkfs.ext4 -F -L data /dev/nvme0n1p6
     ```

   - **Passo C: Inicializar a estrutura canônica de diretórios do umbrelOS**:
     ```bash
     sudo mkdir -p /mnt/temp_data
     sudo mount /dev/nvme0n1p6 /mnt/temp_data
     sudo mkdir -p /mnt/temp_data/umbrel-os/{var/log,var/lib/docker,home,var/lib/systemd/timesync,kopia,state}
     sudo chown -R 1000:1000 /mnt/temp_data/umbrel-os/home
     sudo umount /mnt/temp_data
     ```

   - **Passo D: Reiniciar**:
     ```bash
     sudo reboot
     ```
   - O umbrelOS montará automaticamente a partição com os **~1TB completos** e carregará a tela limpa de onboarding (`/onboarding`)!

---

### Fase 3: Primeiro Acesso e Configuração Inicial (Onboarding)

1. No seu computador Pop!_OS (conectado na mesma rede Wi-Fi/cabo):
   - Abra o navegador e acesse:
     ```text
     http://umbrel.local
     ```
   - *(Ou pelo IP do Mini PC: `http://umbrel.local`)*.
2. Siga o assistente de boas-vindas do umbrelOS na tela:
   - Crie o seu nome de usuário e senha mestre de administrador.
   - Guarde as credenciais com segurança.

---

### Fase 4: Instalação dos Apps Oficiais na App Store do umbrelOS

> 💡 **Por que instalar esses apps pela interface antes?**
> O Immich, Nextcloud, Home Assistant e AdGuard Home possuem integração profunda com o sistema operacional do Umbrel (ícones na área de trabalho, backups integrados e single sign-on). Nosso script vai preparar a infraestrutura que esses apps consomem!

Acesse a **App Store** dentro do painel web do Umbrel e instale:
1. **AdGuard Home**: Será o nosso servidor DNS e bloqueador de anúncios da casa toda.
2. **Immich**: Servidor de fotos e vídeos para você e Kamila.
3. **Nextcloud**: Nuvem privada de arquivos.
4. **Home Assistant**: Central de automação residencial.
5. **Tailscale**: VPN Mesh para acesso remoto seguro fora de casa.
6. **Jellyfin**: Servidor de streaming de mídias com aceleração por hardware.

---

### Fase 5: Preparação dos 3 HDs Externos Nativos (3 TB Úteis Reais)
 
> 🛡️ **Arquitetura de Armazenamento Nativa e Direta (3 HDs de 1TB = 3TB)**:
> - **HD 1 (`disk1` - 1TB ext4 Seagate)**: Mídia & Downloads (Jellyfin, Radarr, Sonarr, qBittorrent).
> - **HD 2 (`disk2` - 1TB ext4 A-DATA)**: Nuvem & Usuários (Nextcloud "Meus Arquivos", "Compartilhado", Samba, Immich).
> - **HD 3 (`disk3` - 1TB ext4 Samsung)**: Backups Locais e contingência.
> - **Backup Externo (Regra 3-2-1)**: Rotina diária inteligente enviando para o Desktop Pop!_OS com retenção de 7 dias.

#### 1. Formatar os 3 HDs em `ext4` com Rótulos Nativos:
Após fazer o backup dos seus arquivos, formate cada partição dos 3 HDs em `ext4` com rótulos padronizados que o umbrelOS reconhece de primeira:

```bash
# Formatar com o rótulo correspondente:
sudo mkfs.ext4 -F -L disk1 /dev/sdX1    # Para o HD 1 (Mídias)
sudo mkfs.ext4 -F -L disk2 /dev/sdY1    # Para o HD 2 (Nuvem / Samba)
sudo mkfs.ext4 -F -L disk3 /dev/sdZ1    # Para o HD 3 (Backups Locais)
```

---

### Fase 6: Envio dos Scripts e Execução da Automação no Mini PC

#### 1. Enviar a Pasta do Projeto para o Mini PC via SSH (Sem precisar de GitHub!):
No terminal do seu **Pop!_OS** (dentro da pasta do projeto), execute:

```bash
# Envia a pasta inteira diretamente para a home do umbrel via rede local:
rsync -avzP --exclude '.git' ~/Documentos/DevProjects/Bash/umbrelos-scripts umbrel@umbrel.local:~/
```
*(Se preferir usar `scp`: `scp -r ~/Documentos/DevProjects/Bash/umbrelos-scripts umbrel@umbrel.local:~/`)*.

#### 2. Conectar via SSH e Executar a Automação:
1. Conecte os 3 HDs nas portas USB do Blackview MP100 Pro.
2. Acesse via SSH a partir do seu Pop!_OS:
   ```bash
   ssh umbrel@umbrel.local
   ```
3. Entre na pasta enviada:
   ```bash
   cd ~/umbrelos-scripts
   ```
4. Obtenha os UUIDs dos 3 HDs formatados:
   ```bash
   lsblk -f
   ```
5. Copie e preencha os UUIDs no `config.env`:
   ```bash
   cp config.env.example config.env
   nano config.env
   ```
   *Preencha `DISK1_UUID`, `DISK2_UUID` e `PARITY_UUID`.*

6. Execute o instalador unificado:
   ```bash
   sudo ./setup_umbrelos.sh
   ```
   *O instalador executará todos os módulos:*
   - Montagem do MergerFS e configuração do SnapRAID (paridade diária às 03:00);
   - Criação dos compartilhamentos Samba (`Media`, `Backups`, `Paulo`, `Kamila`);
   - Inicialização das stacks Docker complementares (**qBittorrent**, **Prowlarr**, **Jackett**, **Radarr**, **Sonarr**, **Bazarr**, **Jellyseerr**, **Dockge**, **Syncthing**, **Nginx Proxy Manager**, **Uptime Kuma** e **IT-Tools**);
   - Ajustes de firewall UFW e blindagem contra quedas de energia (journaling estrito e backup diário de bancos às 04:00).

---

### Fase 7: Configuração dos Domínios Amigáveis Locais (`*.pk.local`)

> 📖 Consulte o guia detalhado em: [Docs/dns_dominios_locais_npm.md](Docs/dns_dominios_locais_npm.md).

Para nunca mais precisar digitar números de portas (ex: `:8085`, `:8989`), você configura em apenas 2 passos:

1. **Passo 1 (AdGuard Home - 1 única regra)**:
   - Abra o **AdGuard Home** pelo painel do Umbrel.
   - Vá em **Filtros > Reescritas de DNS** e adicione:
     - Domínio: `*.pk.local`
     - IP: `192.168.0.8`
2. **Passo 2 (Nginx Proxy Manager - `http://umbrel.local:81`)**:
   - Acesse com `admin@example.com` / `changeme`.
   - Adicione os Proxy Hosts usando os nomes dos containers internos (ex: `pedidos.pk.local` -> `http://jellyseerr:5055`, `torrent.pk.local` -> `http://qbittorrent:8085`, etc.).

---

## ⚙️ Configuração dos Serviços e Integrações

### Immich (Fotos) e Nextcloud (Nuvem Pessoal)

1. **Immich (Fotos e Vídeos - Sincronização Nativa)**:
   - Instale o **Immich** pela App Store do umbrelOS.
   - O banco de dados vetorial e PostgreSQL rodam no NVMe de 1TB (garantindo busca facial instantânea e reconhecimento de IA veloz com o i5-12450H).
   - O armazenamento de fotos e vídeos aponta para a pasta montada no HD externo: `/mnt/storage/immich/library`.
   - **Como sincronizar**: Você e a Kamila usam o **aplicativo oficial do Immich** no celular (iOS/Android). O app envia metadados (GPS, câmera, data) diretamente ao banco e ativa o reconhecimento facial automático (não use Syncthing para o Immich, o app oficial faz o fluxo completo).

2. **Nextcloud + Syncthing (Nuvem Pessoal & Sincronização P2P Ultrarrápida)**:
   - Instale o **Nextcloud** pela App Store do umbrelOS.
   - Os dados de arquivos volumosos ficam em `/mnt/storage/nextcloud/data`.
   - **Syncthing (`http://umbrel.local:8384`)**:
     - Usado para sincronizar em tempo real as pastas de documentos, trabalho, notas (ex: Obsidian) e arquivos entre o seu Pop!_OS, o notebook/celular da Kamila e o Homelab.
     - Usa o protocolo P2P contínuo (sem passar pela lentidão de WebDAV/PHP).
     - Você pode ativar o aplicativo **"External storage support"** no Nextcloud e apontar para a pasta do Syncthing, permitindo visualizar e compartilhar esses arquivos também pela interface web do Nextcloud!

---

### Jellyfin (Quick Sync) + Stack Arr + qBittorrent

1. **Transcodificação por Hardware no Jellyfin**:
   - Vá no painel do Jellyfin em **Dashboard > Reprodução > Transcodificação**.
   - Selecione **Intel QuickSync (QSV)**.
   - Habilite decodificação por hardware para H.264, HEVC (H.265), VP9 e AV1 (suportados nativamente pela arquitetura Intel de 12ª geração).
   - Mapeie a biblioteca apontando para `/mnt/storage/media/movies`, `/mnt/storage/media/series` e `/mnt/storage/media/music`.
2. **Stack Arr e Automação de Downloads**:
   - O `docker-compose` em `compose/arr-stack/` sobe automaticamente:
     - **Prowlarr (`http://umbrel.local:9696`)**: Gerenciador moderno da família Arr que sincroniza seus indexadores com Radarr e Sonarr automaticamente.
     - **Jackett (`http://umbrel.local:9117`)**: Proxy tradutor de torrents complementar, excelente para trackers públicos, internacionais e alguns trackers privados brasileiros que funcionam melhor via Jackett.
     - **Radarr & Sonarr**: Adicione filmes e séries com monitoramento automático de qualidade (1080p / 4K).
     - **qBittorrent**: Acesso Web em `http://umbrel.local:8085` configurado para salvar na pasta `/mnt/storage/media/torrents`.
     - **Bazarr**: Baixa automaticamente legendas em português (PT-BR) assim que o filme/episódio termina de baixar.
     - **Jellyseerr**: Painel em `http://umbrel.local:5055` estilo streaming onde você e Kamila podem pesquisar qualquer filme ou série e pedir com 1 clique.

---

### Home Assistant e Dispositivos Inteligentes

Instale o **Home Assistant** diretamente pela App Store do umbrelOS. A máquina tem capacidade de sobra para gerenciar todos os dispositivos da casa:
- **Alexa**: Integração via aplicativo Amazon Alexa / Nabu Casa ou emulação Hue.
- **Alimentador ROJECO**: Integração via Tuya / Smart Life ou LocalTuya.
- **Robô Aspirador Xiaomi**: Integração oficial *Xiaomi Miio* (mapas, controle de zonas e automações de limpeza).
- **Câmeras (App ICSee)**: Integração via protocolo RTSP / ONVIF usando a integração genérica de câmeras ou *go2rtc* / *WebRTC* do Home Assistant.
- **Máquina de Lavar LG**: Integração *LG ThinQ* (notificação no celular/alexa quando o ciclo de lavagem terminar).
- **Ar Condicionado Samsung**: Caso o ar tenha Wi-Fi, integração via *Samsung SmartThings*. Se for modelo antigo apenas infravermelho, basta adicionar um transmissor infravermelho inteligente USB/Wi-Fi (como Tuya IR ou Broadlink) para integrá-lo ao Home Assistant.

---

### Compartilhamentos Samba na Rede Local (Windows / Linux / Smart TVs)

O script configura automaticamente os seguintes compartilhamentos no arquivo `/etc/samba/smb.conf`:

| Compartilhamento | Caminho Local | Acesso | Descrição |
| :--- | :--- | :--- | :--- |
| `\\umbrel.local\Media` | `/mnt/storage/media` | Público (Leitura/Escrita) | Acesso direto a filmes, músicas e séries para TVs e PCs |
| `\\umbrel.local\Backups` | `/mnt/storage/backups` | Usuários Autenticados | Armazenamento de backups da casa |
| `\\umbrel.local\Paulo` | `/mnt/storage/users/paulo` | Apenas Paulo | Pasta pessoal segura |
| `\\umbrel.local\Kamila` | `/mnt/storage/users/kamila` | Apenas Kamila | Pasta pessoal segura |

#### Como conectar no seu PopOS:
1. Abra o gerenciador de arquivos **Nautilus (Arquivos)**.
2. Clique em **Outros Locais** (Other Locations).
3. Na barra "Conectar ao Servidor", digite:
   ```text
   smb://umbrel.local/Media
   ```
4. Adicione aos favoritos para acesso instantâneo na barra lateral do PopOS.

---

### Acesso Remoto Seguro (Tailscale) e Bloqueio de Anúncios (AdGuard Home)

1. **Tailscale (VPN Mesh)**:
   - Para acessar seu Jellyfin, Immich e arquivos fora de casa sem precisar abrir portas perigosas no seu roteador (especialmente útil em conexões CGNAT):
     ```bash
     sudo tailscale up
     ```
   - Conecte seus celulares e o PopOS na mesma conta Tailscale. Você terá um IP seguro (ex: `100.x.y.z`) acessível de qualquer lugar do mundo.
   - **Nextcloud via Tailscale:** O Nextcloud já está configurado com `trusted_domains` e `trusted_proxies` aceitando requisições diretas via IP Tailscale e MagicDNS sem erros de domínio não confiável (detalhes em [Docs/pos_instalacao_portas_e_testes.md](Docs/pos_instalacao_portas_e_testes.md)).
2. **AdGuard Home** (Pela App Store do umbrelOS):
   - Atue como servidor DNS da sua rede doméstica.
   - Bloqueia anúncios, telemetria invasiva e malwares antes mesmo de chegarem na sua Smart TV, computadores e celulares.
   - Fornece o recurso de **DNS Rewrites** (`*.pk.local`) para navegação por nomes amigáveis.

---

## 📊 Gerenciamento e Monitoramento

- **Nginx Proxy Manager (`http://umbrel.local:81`)**:
  Cria nomes amigáveis locais (*reverse proxy*) como `jellyfin.pk.local` ou `pedidos.pk.local`, eliminando a necessidade de lembrar portas numéricas.
- **Dockge (`http://umbrel.local:5001`)**:
  Interface visual e intuitiva para você visualizar suas stacks do Docker Compose, editar variáveis `.env`, atualizar imagens com 1 clique e subir seus próprios projetos de desenvolvimento que você compilar no PopOS.
- **Syncthing (`http://umbrel.local:8384`)**:
  Sincronização contínua P2P ultrarrápida de documentos para o Nextcloud.
- **Uptime Kuma (`http://umbrel.local:3001`)**:
  Painel com visual moderno para monitorar se a internet caiu, se os sites estão online e receber notificações no Telegram ou Discord caso algum serviço falhe.
- **IT-Tools (`http://umbrel.local:8080`)**:
  Caixa de ferramentas prática (conversores JSON, geradores de hash, decodificadores de certificados, regex tester, etc.).

> 📖 **Guia Passo a Passo de Domínios Locais**: Consulte [Docs/dns_dominios_locais_npm.md](Docs/dns_dominios_locais_npm.md) para a tabela completa de domínios `*.pk.local` e como ativar via AdGuard Home.

---

## 🛡️ Blindagem Contra Falhas de Energia (Crash-Resilience Sem Nobreak)

> 📖 Para entender a fundo o funcionamento dessas proteções, veja: [Docs/blindagem_falhas_energia.md](Docs/blindagem_falhas_energia.md).

Como o Homelab ainda não possui um nobreak dedicado, o sistema foi blindado via software para minimizar qualquer risco de corrupção caso ocorra corte repentino de energia:

1. **Journaling e Flush Estrito nos HDs (`commit=5,errors=remount-ro`)**:
   - Os buffers de escrita são forçados para os discos a cada 5 segundos. Se houver falha de I/O em queda, o disco se auto-protege montando em modo somente-leitura.
2. **Ajustes de Kernel (`sysctl`)**:
   - Páginas sujas de memória (*dirty pages*) são descarregadas continuamente (`vm.dirty_writeback_centisecs = 500`).
3. **Persistência do Systemd Journald**:
   - Sincronização periódica a cada 1 minuto para não corromper histórico de boot no SSD NVMe.
4. **Rotina Automática de Backup de Bancos (`scripts/06_backup_databases.sh`)**:
   - Todo dia às **04:00 da manhã**, o script gera um dump comprimido `.sql.gz` do **PostgreSQL do Immich** e do banco do **Nextcloud** em `/mnt/storage/backups/databases/`.
   - Se uma queda severa corromper qualquer banco, você restaura o estado da noite anterior em menos de 2 minutos.

---

## 🚪 Tabela de Portas e Serviços

> 📖 **Guia Completo de Pós-Instalação, Credenciais e Testes**: Acesse [Docs/pos_instalacao_portas_e_testes.md](Docs/pos_instalacao_portas_e_testes.md) para detalhes de usuários, primeiro login, senha do qBittorrent e testes passo a passo.
> 📖 **Deploy de Projetos Dev**: Acesse [Docs/deploy_projetos_dev_coolify_npm.md](Docs/deploy_projetos_dev_coolify_npm.md) para organizar projetos Python (Streamlit), Node.js e Coolify.

| Serviço | Porta Padrão | Protocolo | Função |
| :--- | :---: | :---: | :--- |
| **umbrelOS Web** | `80` / `443` | HTTP/S | Painel Principal e App Store |
| **SSH** | `22` | TCP | Administração remota via terminal |
| **Samba** | `445`, `139` | TCP | Compartilhamento de arquivos em rede |
| **Nginx Proxy Mgr** | `81` | HTTP | Painel de controle de domínios amigáveis |
| **NPM Proxy HTTP** | `8088` | HTTP | Porta de roteamento de domínios locais |
| **Dockge** | `5001` | HTTP | Gerenciador visual de Docker Compose |
| **Syncthing Web** | `8384` | HTTP | Painel de controle e pareamento de pastas P2P |
| **Syncthing Transfer** | `22000` | TCP/UDP | Transferência direta e criptografada de arquivos |
| **Uptime Kuma** | `3001` | HTTP | Monitoramento de status de serviços |
| **IT-Tools** | `8080` | HTTP | Ferramentas para desenvolvedores |
| **Jellyseerr** | `5055` | HTTP | Solicitação e descoberta de filmes/séries |
| **qBittorrent** | `8085` | HTTP | Web UI do cliente BitTorrent |
| **Radarr** | `7878` | HTTP | Gerenciador de filmes |
| **Sonarr** | `8989` | HTTP | Gerenciador de séries e animes |
| **Bazarr** | `6767` | HTTP | Gerenciador automático de legendas |
| **Prowlarr** | `9696` | HTTP | Gerenciador de indexadores de torrent |
| **Jackett** | `9117` | HTTP | Proxy complementar de indexadores de torrent |

---

## 🛠️ Manutenção e Comandos Úteis

- **Verificar saúde dos HDs externos e NVMe**:
  ```bash
  sudo smartctl -a /dev/sda    # HD externo
  sudo nvme smart-log /dev/nvme0n1  # NVMe interno
  ```
- **Verificar temperatura do processador i5-12450h**:
  ```bash
  sensors
  ```
- **Reiniciar o serviço Samba**:
  ```bash
  sudo systemctl restart smbd nmbd
  ```
- **Verificar uso de espaço dos discos montados**:
  ```bash
  df -h
  ```

---

Desenvolvido com carinho para transformar o **Blackview MP100 Pro** em um Homelab de alta disponibilidade para a família! 🚀
