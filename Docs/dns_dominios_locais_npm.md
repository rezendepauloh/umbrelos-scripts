# 🌐 Guia de Domínios Amigáveis Locais com Nginx Proxy Manager e DNS Local

Este guia ensina como eliminar o uso de números de portas (ex: `:8085`, `:8989`, `:9696`) e acessar todos os serviços do Homelab por nomes amigáveis em qualquer computador, celular e Smart TV da casa (ex: `jellyfin.pk.local`, `nuvem.pk.local`, `torrent.pk.local`).

---

## 🏗️ Como a Mágica Funciona

```text
[Seu Pop!_OS / Celular / Smart TV]
               │
               ▼  Digita: "jellyfin.pk.local"
[AdGuard Home (DNS Local & Bloqueador no Mini PC)]
               │
               ▼  Resolve: "jellyfin.pk.local -> 192.168.0.74" (IP do Mini PC)
[Nginx Proxy Manager (Porta 8088 / 80)]
               │
               ▼  Lê o domínio e despacha direto para o container interno!
[Container Docker do Jellyfin / Arr / Nextcloud / Immich]
```

---

## 📋 Tabela Canônica de Domínios Amigáveis Sugeridos (`*.pk.local`)

| Domínio Sugerido | Serviço | Host de Destino no NPM | Porta Interna |
| :--- | :--- | :--- | :---: |
| **`jellyfin.pk.local`** | Servidor de Filmes/Séries | `172.17.0.1` *(host)* | `8096` |
| **`pedidos.pk.local`** | Jellyseerr (Pedidos de Mídia) | `jellyseerr` | `5055` |
| **`torrent.pk.local`** | qBittorrent Web UI | `qbittorrent` | `8085` |
| **`filmes.pk.local`** | Radarr | `radarr` | `7878` |
| **`series.pk.local`** | Sonarr | `sonarr` | `8989` |
| **`legendas.pk.local`** | Bazarr | `bazarr` | `6767` |
| **`trackers.pk.local`** | Prowlarr | `prowlarr` | `9696` |
| **`jackett.pk.local`** | Jackett | `jackett` | `9117` |
| **`nuvem.pk.local`** | Nextcloud | `172.17.0.1` *(host)* | *(Porta Umbrel)* |
| **`fotos.pk.local`** | Immich | `172.17.0.1` *(host)* | `2283` |
| **`syncthing.pk.local`** | Syncthing | `syncthing` | `8384` |
| **`dockge.pk.local`** | Dockge (Gerenciador Docker) | `dockge` | `5001` |
| **`status.pk.local`** | Uptime Kuma (Monitoramento) | `uptime-kuma` | `3001` |
| **`tools.pk.local`** | IT-Tools | `it-tools` | `80` |
| **`proxy.pk.local`** | Nginx Proxy Manager Admin | `nginx-proxy-manager` | `81` |

---

## 🛠️ Passo a Passo para Configurar

### Etapa 1: Primeiro Acesso ao Nginx Proxy Manager (NPM)
1. No seu navegador, acesse:
   ```text
   http://umbrel.local:81
   ```
2. Credenciais padrão de fábrica do NPM:
   - **E-mail**: `admin@example.com`
   - **Senha**: `changeme`
3. O sistema solicitará que você defina seu nome, um novo e-mail e uma nova senha segura.

---

### Etapa 2: Adicionar um Proxy Host (Exemplo: Jellyseerr)
1. No menu superior do NPM, clique em **Proxy Hosts** > **Add Proxy Host**.
2. Preencha os campos:
   - **Domain Names**: `pedidos.pk.local` (pressione Enter após digitar).
   - **Scheme**: `http`
   - **Forward Hostname / IP**: `jellyseerr` *(como estão na mesma rede `homelab_network`, você pode usar o nome do container! Se for um app do Umbrel como Jellyfin, use o IP do host `172.17.0.1`)*.
   - **Forward Port**: `5055`
   - Marque:
     - ☑️ **Block Common Exploits**
     - ☑️ **Websockets Support** (essencial para Uptime Kuma, Jellyfin e Dockge).
3. Clique em **Save**.

---

### Etapa 3: Fazer Toda a Rede Doméstica Conhecer os Domínios (Via AdGuard Home)

Para que o celular da Kamila, Smart TVs e computadores resolvam `*.pk.local` automaticamente:

#### No AdGuard Home (Recomendado):
1. Instale o **AdGuard Home** pela App Store do umbrelOS.
2. Abra o AdGuard Home e vá em: **Filtros** > **Reescritas de DNS** (*DNS Rewrites*).
3. Clique em **Adicionar reescrita de DNS**:
   - **Domínio**: `*.pk.local` *(o asterisco captura todos os subdomínios!)*
   - **Endereço IP**: `192.168.0.8` *(IP fixo do seu Mini PC Blackview)*.
4. Salve a alteração.

Pronto! Agora qualquer requisição para `qualquercoisa.pk.local` feita por qualquer aparelho na sua casa será direcionada automaticamente para o mini PC.

*(Dica: Se por algum motivo o AdGuard estiver desativado, você pode adicionar entradas no arquivo `/etc/hosts` dos computadores como plano B)*:
```text
192.168.0.8  jellyfin.pk.local pedidos.pk.local nuvem.pk.local torrent.pk.local status.pk.local
```
Salvar e pronto! Digite `pedidos.pk.local:8088` no navegador e ele abrirá direto!
