# 📊 Tabela Geral de Serviços, Portas e Credenciais

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
| **Home Assistant** | `http://home.pk.local` (`:8123`) | Criado no onboarding | Criada no onboarding | Automação residencial, Xiaomi, ICSee, Rojeco e Alexa |

---

## 2. 🗺️ Roteiro de Configuração Passo a Passo (Ordem Recomendada)

Configurar os serviços na ordem abaixo evita refazer trabalho, pois as aplicações da Stack Arr e multimídia dependem umas das outras:

```
[1. Fundação & Rede] ──> [2. Dockge & Senhas] ──> [3. Download & Indexadores] ──> [4. Automação de Mídia] ──> [5. Streaming & Nuvem]
 (Tailscale, AdGuard,        (Trocar senhas e        (qBittorrent + Prowlarr)          (Radarr, Sonarr,           (Jellyfin, Jellyseerr,
      NPM e Samba)             criar admins)                                                Bazarr)                  Immich, Nextcloud)
```

---
