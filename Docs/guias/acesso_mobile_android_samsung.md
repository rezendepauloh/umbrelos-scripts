# Guia Prático: Acesso ao Homelab em Celular e Tablet Android (Samsung Galaxy)

Este guia prático ensina como acessar todos os serviços do Homelab (Nextcloud, Jellyfin, Sistema Karteman, painéis e ferramentas) nos seus dispositivos móveis Samsung (smartphone e tablet), tanto conectado ao Wi-Fi de casa quanto remotamente pela rede móvel (4G/5G).

---

## ⚠️ Entendendo a Limitação do Android e do Roteador Claro

1. **Roteador Claro Sagemcom (`192.168.0.1`):** A operadora Claro bloqueia o acesso à interface web de administração do roteador (`http://192.168.0.1`). Por isso, não é possível alterar o DNS geral da casa diretamente nele nem criar reservas DHCP na caixa da Claro.
2. **Android e o Domínio `.local`:** O sistema Android (Samsung One UI), por padrão de segurança, ignora anúncios mDNS locais (`umbrel.local`). Além disso, se o recurso **"DNS Privado"** estiver ativado no aparelho, ele ignora qualquer DNS local e redireciona consultas para a nuvem (Google/Cloudflare).

Por esses dois motivos, preparamos duas formas extremamente fáceis e confiáveis para você acessar tudo sem dor de cabeça.

---

## 🚀 Método 1: Acesso Direto por IP e Atalhos na Tela Inicial (Mais Rápido e Simples)

Na sua rede Wi-Fi doméstica, o mini PC possui o **IP fixo `192.168.0.8`**. Você pode abrir qualquer serviço pelo navegador (Chrome ou Samsung Internet) e adicioná-lo como um ícone de aplicativo na tela inicial do celular ou tablet.

### Lista de Portas e Endereços Diretos:

| Serviço / Aplicação | Endereço no Navegador do Celular/Tablet | Função |
| :--- | :--- | :--- |
| **Painel Umbrel OS** | `http://192.168.0.8` | Painel principal do servidor |
| **Sistema Karteman** | `http://192.168.0.8:8091` | Sistema de Gestão Karteman |
| **Evolution API (WhatsApp)** | `http://192.168.0.8:8092` | API de automação do WhatsApp |
| **Verifica Diários Oficiais** | `http://192.168.0.8:8093` | App de busca em diários |
| **Investimentos Pessoais** | `http://192.168.0.8:8094` | Dashboard financeiro Streamlit |
| **Jellyfin (Filmes e Séries)** | `http://192.168.0.8:8096` | Streaming de mídias (ou app Jellyfin) |
| **Nextcloud (Nuvem e Fotos)** | `http://192.168.0.8:8081` | Arquivos pessoais e compartilhados |
| **Immich (Galeria de Fotos)** | `http://192.168.0.8:2283` | Backup de fotos do smartphone |
| **Dockge** | `http://192.168.0.8:5001` | Gerenciador de Stacks Docker |
| **Dozzle** | `http://192.168.0.8:8888` | Visualizador de logs e consumo de CPU/RAM |
| **Uptime Kuma** | `http://192.168.0.8:3001` | Monitor de status dos serviços |
| **AdGuard Home** | `http://192.168.0.8:8095` | Painel do bloqueador de anúncios e DNS |
| **Jellyseerr (Seerr)** | `http://192.168.0.8:5055` | Solicitação de filmes e séries |
| **qBittorrent** | `http://192.168.0.8:8085` | Gerenciador de downloads |

### Como criar um ícone na Tela Inicial do Android:
1. Abra o **Google Chrome** ou o **Samsung Internet** no celular/tablet.
2. Acesse o endereço desejado (ex: `http://192.168.0.8:8091` para o Karteman).
3. Toque no menu de três pontos (**⋮**) no canto superior direito.
4. Selecione **"Adicionar à tela inicial"** (ou *"Instalar aplicativo"* se disponível).
5. O ícone ficará acessível na sua tela inicial como se fosse um app instalado.

---

## 🌐 Método 2: Habilitar Domínios Amigáveis (`*.pk.local`) no Android via Wi-Fi

Se você prefere digitar nomes bonitos como `karteman.pk.local`, `jellyfin.pk.local` ou `nuvem.pk.local` no celular e tablet, basta configurar a conexão Wi-Fi do aparelho para usar o **AdGuard Home (`192.168.0.8`)** como servidor de DNS:

### Passo a Passo no Smartphone ou Tablet Samsung:

1. Abra as **Configurações** do Android.
2. Vá em **Conexões** > **Wi-Fi**.
3. Toque no ícone de **Engrenagem** ao lado da sua rede Wi-Fi conectada.
4. Toque em **Avançado** (ou *"Ver mais"*).
5. Em **Definições de IP**, mude de *DHCP* para **Estático**:
   - **Endereço IP:** mantenha o IP que o aparelho já tem (ex: `192.168.0.25`).
   - **Gateway:** `192.168.0.1`
   - **Comprimento do prefixo de rede:** `24`
   - **DNS 1:** `192.168.0.8` *(Endereço do nosso servidor AdGuard Home)*
   - **DNS 2:** `1.1.1.1` *(Fallback Cloudflare)*
6. **Importante (Desativar DNS Privado do Android):**
   - Vá em **Configurações** > **Conexões** > **Mais configurações de conexão**.
   - Toque em **DNS privado** e selecione **Desativado** (se estiver em automático, o Android desvia do AdGuard Home).
7. Pronto! Agora qualquer navegador no seu celular ou tablet abrirá diretamente:
   - `http://karteman.pk.local:8088` (ou `http://karteman.pk.local` se a porta 80 estiver redirecionada)
   - `http://jellyfin.pk.local:8088`
   - `http://nuvem.pk.local:8088`

---

## 🔒 Método 3: Acesso Remoto Fora de Casa via Tailscale (4G / 5G / Qualquer Lugar)

O Tailscale já está rodando 100% no mini PC no endereço **`100.88.159.41`**.

1. Baixe o app **Tailscale** na Google Play Store no celular e no tablet.
2. Faça login com a mesma conta que você usa no Homelab.
3. Ative a chave de conexão (VPN do Tailscale).
4. Você terá acesso aos serviços de qualquer lugar do mundo como se estivesse no sofá de casa:
   - Painel Umbrel: `http://100.88.159.41` ou `http://umbrel.tail9accc5.ts.net`
   - Sistema Karteman: `http://100.88.159.41:8091`
   - Nextcloud: `http://100.88.159.41:8081`
   - Jellyfin: `http://100.88.159.41:8096`
   - Diários Oficiais: `http://100.88.159.41:8093`
   - Investimentos: `http://100.88.159.41:8094`

---

## 📱 Aplicativos Oficiais Recomendados para Instalar no Android

Para a melhor experiência no celular e tablet, instale os aplicativos dedicados:

- **Jellyfin:** Instale o app oficial *Jellyfin* da Play Store. No endereço do servidor, coloque `http://192.168.0.8:8096`. O player ajusta a resolução e áudio perfeitamente para a tela do seu Samsung.
- **Nextcloud:** Instale o app oficial *Nextcloud*. No servidor, aponte para `http://192.168.0.8:8081` (ou use a conta via Tailscale `http://100.88.159.41:8081`).
- **Immich:** Instale o app oficial *Immich* para fazer backup automático das fotos da câmera direto para o disco rígido do Homelab. No servidor, coloque `http://192.168.0.8:2283`.
