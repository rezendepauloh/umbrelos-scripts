# Guia de Configuração: TV ao Vivo e EPG (XMLTV) no Jellyfin

Este guia documenta o funcionamento da TV ao Vivo aberta brasileira no Jellyfin no mini PC homelab, os fluxos de atualização de canais e o gerador de dados da grade de programação (EPG).

---

## 1. Visão Geral da Arquitetura

O Jellyfin gerencia a TV ao Vivo através de dois componentes essenciais:

1. **Sintonizador M3U (`canais_brasil.m3u`):**
   - Lista curada e testada com streams HLS/m3u8 100% ativos de canais abertos e públicos nacionais (Record, SBT, TV Cultura, RedeTV!, Band, GloboNews, Jovem Pan News, CNN Brasil, etc.).
   - Arquivo canônico de backup no repositório: `config/iptv/canais_brasil.m3u`.
   - Arquivo de produção no mini PC: `/home/umbrel/umbrel/home/Downloads/iptv/canais_brasil.m3u`.
   - Caminho mapeado dentro do container Docker do Jellyfin: `/downloads/iptv/canais_brasil.m3u`.

2. **Provedor de Guia XMLTV (`guia_brasil.xml`):**
   - Arquivo padronizado XMLTV contendo a grade horária e dados dos programas (início, término, título e sinopse).
   - Gerado pelo script `scripts/utils/generate_epg.sh` (instalado em `/data/bin/generate_epg.sh`).
   - Caminho mapeado dentro do container do Jellyfin: `/downloads/iptv/guia_brasil.xml`.

---

## 2. Automação e Sincronização Diária

As grades das emissoras mudam constantemente. Para manter o Jellyfin sempre atualizado com a programação dos próximos dias:

- **Cronjob Ativo no Servidor:**
  Configurado em `/etc/cron.d/homelab-epg-sync`:
  ```bash
  0 5 * * * umbrel /data/bin/generate_epg.sh >/dev/null 2>&1
  ```
  Todos os dias às **05:00 da manhã**, o script:
  1. Baixa as tabelas mais recentes das fontes de EPG brasileiras (`epg.pw`, `epgshare01`);
  2. Executa a correspondência dos nomes e `tvg-id` exatos da lista `canais_brasil.m3u`;
  3. Gera o arquivo consolidado em `/home/umbrel/umbrel/home/Downloads/iptv/guia_brasil.xml`.

---

## 3. Comandos Úteis

- **Executar a geração manual do EPG no servidor:**
  ```bash
  /data/bin/generate_epg.sh
  ```
- **Forçar o Jellyfin a reler os dados do guia:**
  No painel web do Jellyfin: **Painel de Controle ➡️ TV ao Vivo ➡️ Atualizar Dados do Guia**.

