# 📚 Documentação Técnica — Homelab umbrelOS

> Bem-vindo à central de documentação e engenharia do **Homelab umbrelOS** rodando no **Blackview MP100 Pro** (Intel Core i5-12450H, 16GB RAM DDR4, 1TB NVMe, 3TB HDs externos).

Esta pasta organiza de forma clara, modular e rastreável todos os manuais operacionais, decisões arquiteturais, relatórios de contexto, testes automatizados e pendências do sistema.

---

## 🗂️ Estrutura e Mapa de Navegação

```text
Docs/
├── README.md                                 # Este índice central unificado
│
├── 📖 guias/                                 # Manuais práticos de operação, manutenção e setup
│   ├── catalogo_servicos_e_portas/           # Catálogo modular de portas, apps e credenciais
│   │   ├── README.md                         # Índice do catálogo de serviços
│   │   ├── 01_tabela_geral_portas_e_roteiro.md
│   │   ├── 02_etapa1_fundacao_rede_samba.md
│   │   ├── 03_etapa2_dockge_e_gerenciamento.md
│   │   ├── 04_etapa3_qbittorrent_prowlarr.md
│   │   ├── 05_etapa4_radarr_sonarr_bazarr.md
│   │   ├── 06_etapa5_streaming_e_nuvem.md
│   │   ├── 07_etapa5_home_assistant.md
│   │   └── 08_dominios_npm_rotinas_e_energia.md
│   ├── guia_autonomia_e_manutencao_remota.md # Scripts em 1 comando (Dashboard, Limpeza, Rollback)
│   ├── recuperacao_hds_e_samba.md            # Diagnóstico e remontagem por UUID pós-queda de energia
│   ├── pos_instalacao_portas_e_testes.md     # Índice de transição e resumo de portas
│   ├── acesso_mobile_android_samsung.md      # Acesso via smartphones Samsung / Android
│   ├── iptv_e_guia_epg_jellyfin.md           # Grade XMLTV e IPTV curado para o Jellyfin
│   ├── backup_rapido_ntfs_e_formatacao.md    # Migração inicial e particionamento ext4
│   └── deploy_projetos_dev_coolify_npm.md    # Orquestração e deploy de stacks de desenvolvimento
│
├── 🏛️ arquitetura/                           # Decisões fundamentais e topologia de engenharia
│   ├── blindagem_falhas_energia.md           # Estratégia contra corrupção e dirty shutdowns
│   ├── formatacao_hds_mergerfs_snapraid.md   # Razões para a arquitetura 100% nativa sem camadas virtuais
│   ├── dns_dominios_locais_npm.md            # AdGuard Home + Nginx Proxy Manager (*.pk.local)
│   ├── zrok_acesso_remoto.md                 # Túneis Zero-Trust públicos via zrok v2
│   ├── cloudflare_tunnels_acesso_remoto.md   # Túneis Cloudflare alternativos
│   └── instalacao_certificado_ssl_homelab.md # Autoridade Certificadora local (CA) e HTTPS
│
├── 🧪 testes/                                # Validação e testes automatizados
│   └── suite_de_testes_e_integridade.md      # Manual da suíte de testes (Python + Bash / Unitários + Integração)
│
├── 🚨 issues/                                # Registro de pendências e melhorias
│   └── issues_e_pendencias.md                # Roadmap de homologações (BeTor, TVs, Issue 9 .env)
│
└── 📋 relatorios/                            # Histórico e registros de contexto
    └── nova_conversa_contexto.md             # Linha do tempo e decisões acumuladas do projeto
```

---

## 🚀 Acessos Rápidos Mais Utilizados

### 1. Rotinas Diárias e Manutenção
- **Como monitorar a saúde do Mini PC:** [Guia de Autonomia e Manutenção Remota](guias/guia_autonomia_e_manutencao_remota.md#1-painel-de-saúde-do-hardware-e-discos)
- **O que fazer se um HD sumir ou cair o cabo USB:** [Recuperação de HDs e Samba](guias/recuperacao_hds_e_samba.md)
- **Como rodar testes de integridade:** [Suíte de Testes e Integridade](testes/suite_de_testes_e_integridade.md)

### 2. Configurações e Portas das Aplicações
- **Tabela de Portas e Credenciais:** [Catálogo 01 - Portas e Serviços](guias/catalogo_servicos_e_portas/01_tabela_geral_portas_e_roteiro.md)
- **Home Assistant (Câmeras, Xiaomi, Alexa, TVs):** [Catálogo 07 - Home Assistant](guias/catalogo_servicos_e_portas/07_etapa5_home_assistant.md)
- **Streaming e Nuvem (Jellyfin, Immich, Nextcloud):** [Catálogo 06 - Streaming e Nuvem](guias/catalogo_servicos_e_portas/06_etapa5_streaming_e_nuvem.md)
- **Acesso Remoto Seguro Fora de Casa:** [Arquitetura de Túneis zrok v2](arquitetura/zrok_acesso_remoto.md)

---

## 🛡️ Princípios Canônicos do Repositório
Para qualquer intervenção no servidor, consulte previamente as diretrizes centrais em:
👉 **[`AGENTS.md`](../AGENTS.md)** (Topologia, senhas, IP fixo `192.168.0.8`, regras de `sudo` e Rugix OS).

