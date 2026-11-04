# 📑 Catálogo Completo de Serviços, Portas e Roteiro de Configuração

> Este diretório documenta de forma modular todas as portas, credenciais, parâmetros de rede e roteiros de configuração de ponta a ponta para cada camada do Homelab umbrelOS no Blackview MP100 Pro.

---

## 🗺️ Índice Modular de Configuração

| Módulo / Etapa | Arquivo | O Que Documenta |
| :--- | :--- | :--- |
| **01. Tabela Geral** | [`01_tabela_geral_portas_e_roteiro.md`](01_tabela_geral_portas_e_roteiro.md) | Catálogo unificado de todos os 20+ serviços, portas, credenciais iniciais e fluxograma. |
| **02. Fundação & Rede** | [`02_etapa1_fundacao_rede_samba.md`](02_etapa1_fundacao_rede_samba.md) | Configuração de Tailscale, AdGuard Home (`*.pk.local`), redirecionamento de porta 80 do NPM e Samba. |
| **03. Dockge & Stacks** | [`03_etapa2_dockge_e_gerenciamento.md`](03_etapa2_dockge_e_gerenciamento.md) | Primeiro acesso ao Dockge (`:5001`), criação de admin e gestão centralizada de stacks. |
| **04. Download & Indexers**| [`04_etapa3_qbittorrent_prowlarr.md`](04_etapa3_qbittorrent_prowlarr.md) | Resgate de senha do qBittorrent (`:8085`), bypass CSRF, configuração do Prowlarr (`:9696`) e BeTor. |
| **05. Gestão de Conteúdo**| [`05_etapa4_radarr_sonarr_bazarr.md`](05_etapa4_radarr_sonarr_bazarr.md) | Conexão do Radarr (`:7878`), Sonarr (`:8989`), Bazarr (`:6767`), regras Dual Áudio e limpeza total. |
| **06. Mídia & Nuvem** | [`06_etapa5_streaming_e_nuvem.md`](06_etapa5_streaming_e_nuvem.md) | Jellyfin com QuickSync (`:8096`), Jellyseerr (`:5055`), Nextcloud (`:8081`) e Immich Fotos (`:2283`). |
| **07. Casa Inteligente** | [`07_etapa5_home_assistant.md`](07_etapa5_home_assistant.md) | Home Assistant (`:8123`): HACS, robô Xiaomi, câmeras ICSee PTZ WebRTC, Tuya, Alexa e TVs Samsung. |
| **08. Domínios & Energia**| [`08_dominios_npm_rotinas_e_energia.md`](08_dominios_npm_rotinas_e_energia.md) | Tabela completa de domínios `*.pk.local` com SSL, cronjobs em segundo plano e BIOS/Power 24/7. |

---

### 💡 Roteiro Recomendado de Leitura e Implantação
Para configurar um ambiente do zero ou homologar novos serviços, siga a ordem sequencial dos documentos numerados de `01` a `08`.

