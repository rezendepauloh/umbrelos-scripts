# 🛠️ Guia de Autonomia e Manutenção Remota do Homelab

> **Objetivo:** Este manual documenta a suíte de scripts executáveis desenvolvida para que você possa diagnosticar, auditar e manter o seu Mini PC (`umbrelOS`) com **100% de autonomia diretamente do seu Pop!_OS**, sem necessitar do auxílio constante de IA ou comandos manuais complexos via SSH.

---

## 📌 Visão Geral dos Utilitários em `scripts/utils/`

| Script | Função Principal | Quando Usar |
| :--- | :--- | :--- |
| **[`homelab_verificar_quedas.sh`](scripts/utils/homelab_verificar_quedas.sh)** | Analisador ativo de quedas, portas com 502 Bad Gateway/000, containers em loop, OOMKilled e erros de I/O em discos. | Quando o Dozzle mostrar tudo 'Up' mas o app estiver inacessível, der 502 Bad Gateway ou upload travar. |
| **[`homelab_restaurar_servicos.sh`](scripts/utils/homelab_restaurar_servicos.sh)** | Restaurador inteligente de containers e auto-cura de discos/bind mounts com flags `--service`, `--stack` ou `--all`. | Para reanimar o Immich, Jellyfin, Nextcloud ou qualquer stack travada sem reiniciar o mini PC. |
| **[`homelab_dashboard_saude.sh`](scripts/utils/homelab_dashboard_saude.sh)** | Painel completo de CPU, memória, temperatura, horas de uso e saúde SMART dos discos. | Para acompanhar a saúde física de hardware, tempo ligado e estado dos HDs. |
| **[`recuperar_hds_remoto.sh`](scripts/utils/recuperar_hds_remoto.sh)** | Desmonta montagens fantasmas com erro de I/O, remonta por UUID e restaura Samba/Jellyfin. | Quando uma pasta Samba sumir ou o cabo USB oscilar/desconectar. |
| **[`homelab_atualizar_stacks.sh`](scripts/utils/homelab_atualizar_stacks.sh)** | Varre as stacks Compose, baixa novas imagens e só recria o que mudou. | Periodicamente (ex: semanalmente) para manter os apps atualizados. |
| **[`homelab_limpeza_docker.sh`](scripts/utils/homelab_limpeza_docker.sh)** | Poda de imagens órfãs, containers mortos e trunca logs gigantescos do Docker. | Quando quiser liberar gigabytes de espaço no SSD NVMe. |
| **[`homelab_auditar_zrok.sh`](scripts/utils/homelab_auditar_zrok.sh)** | Testa os 6 túneis zrok v2 e o Tailscale com códigos de retorno HTTP. | Antes de sair de casa para garantir que os links externos estão funcionando. |
| **[`homelab_backup_pre_upgrade.sh`](scripts/utils/homelab_backup_pre_upgrade.sh)** | Snapshot completo de bancos, app-data, compose e /data no disk3 e no Pop!_OS. | Obrigatório antes de migrar versão do umbrelOS ou de apps críticos. |
| **[`homelab_rollback.sh`](scripts/utils/homelab_rollback.sh)** | Restaura versão anterior do OS (Rugix A/B), bancos, app-data ou stacks. | Em caso de falha pós-update de OS ou corrupção de app/banco. |
| **[`homelab-backup-semanal.sh`](scripts/utils/homelab-backup-semanal.sh)** | Snapshot local no disk3 e espelhamento remoto via rsync inteligente para o Pop!_OS. | Automático pelo cron ou manual se for fazer mudanças grandes. |

---

## 🚀 Como Executar cada Utilitário a partir do Pop!_OS

Abra o seu terminal na pasta raiz do repositório:
```bash
cd ~/Documentos/DevProjects/Bash/umbrelos-scripts
```

### 1. Painel de Saúde do Hardware e Discos
```bash
./scripts/utils/homelab_dashboard_saude.sh
```
Exibe:
- **Uptime:** Tempo de atividade contínuo e data do boot.
- **CPU & RAM:** Carga de processamento, temperatura da CPU Intel e uso de RAM.
- **Espaço:** Tabela com NVMe, `disk1` (Mídia), `disk2` (Nuvem/Fotos) e `disk3` (Backups).
- **SMART:** Status (`PASSED`), horas totais ligado de cada HD e temperatura individual.
- **Barramento USB:** Alertas caso algum cabo USB tenha sido desconectado recentemente.
- **Containers:** Status geral dos containers Docker.

---

### 2. Recuperação em 1 Clique de HDs e Samba
Se você esbarrar em algum cabo USB ou o compartilhamento de rede parecer vazio no Nautilus:
```bash
./scripts/utils/recuperar_hds_remoto.sh
```
O script remonta os discos Seagate, A-DATA e Samsung pelos seus UUIDs canônicos, restabelece os bind mounts do Jellyfin e do Immich e reinicia o Samba sem você precisar reiniciar o Mini PC.

---

### 3. Atualizador Automático de Stacks Docker
```bash
./scripts/utils/homelab_atualizar_stacks.sh
```
Ele acessa as stacks `management`, `arr-stack` e `tunnels`, faz o download silencioso das imagens e recria apenas os containers que possuem versão mais nova, mantendo intactos todos os dados e bancos.

---

### 4. Faxina Preventiva do Docker
```bash
./scripts/utils/homelab_limpeza_docker.sh
```
Remove resíduos de atualizações antigas do Docker e trunca logs que excedam 300 MB, recuperando espaço útil no SSD NVMe.

---

### 5. Auditor de Acesso Remoto (zrok & Tailscale)
```bash
./scripts/utils/homelab_auditar_zrok.sh
```
Faz o disparo instantâneo para:
- Dashboard Umbrel (`umbrel-paulo.shares.zrok.io`)
- Nextcloud (`cloud-paulo.shares.zrok.io`)
- Jellyfin (`jellyfin-paulo.shares.zrok.io`)
- Karteman (`karteman-paulo.shares.zrok.io`)
- Verifica Diários (`diarios-paulo.shares.zrok.io`)
- Investimentos (`investimentos-paulo.shares.zrok.io`)
- Ping no IP Tailscale (`100.88.159.41`)
Retornando em segundos se todas as portas e túneis estão verdes `[ONLINE]`.

---

### 6. Snapshot Completo Pré-Upgrade (Segurança Máxima)
Antes de clicar em qualquer atualização de versão maior do umbrelOS (ex: 2.0.x) ou atualizações de banco de dados:
```bash
./scripts/utils/homelab_backup_pre_upgrade.sh
```
O script executa um congelamento seguro com:
1. Dumps SQL completos de todos os bancos (`immich_db.sql.gz`, `nextcloud_db.sql.gz`, `karteman_db.sql.gz`).
2. Backup de todo o diretório `app-data/` dos serviços oficiais (Jellyfin, Nextcloud, Immich, etc.).
3. Backup de todas as stacks customizadas do Docker Compose.
4. Backup das configurações persistentes de `/data` (excluindo montagens Rugix).
5. Backup de arquivos e diretórios compartilhados de usuários no `disk2`.
6. Gravação imediata no **`disk3`** do Mini PC e espelhamento remoto via rede para o Pop!_OS em **`/mnt/storage_930/Backups_Homelab/pre_upgrade_<DATA>`**.

---

### 7. Rollback e Restauração em Caso de Falha
Se uma atualização do sistema quebrar o umbrelOS ou corromper os dados de algum aplicativo:
```bash
./scripts/utils/homelab_rollback.sh
```
O script abre um menu interativo permitindo escolher exatamente o que restaurar:
- **Opção 1 (Rollback de Sistema Operacional):** Alterna o slot de inicialização A/B do Rugix OS, fazendo o mini PC reiniciar imediatamente na versão anterior do umbrelOS.
- **Opção 2 (Restauração Completa de Snapshot):** Restaura os bancos de dados, arquivos de configuração dos apps, /data e stacks a partir do snapshot salvo no `disk3`.
- **Opção 3 (Restauração Granular de Banco):** Permite restaurar individualmente o banco do Nextcloud (MariaDB), Immich (Postgres) ou Karteman (Postgres).
- **Opção 4 (Restauração de App Específico):** Restaura apenas a pasta de configuração de um app que deu defeito (ex: `jellyfin`, `nextcloud`, `adguard-home`, `home-assistant`).

---

### 8. Análise de Quedas e Diagnóstico de Serviços (502 Bad Gateway & Loopings)
Se o Dozzle indicar que os containers estão rodando, mas ao abrir o navegador você receber **`502 Bad Gateway`**, **`Connection Refused`** ou o upload maciço de fotos/mídias travar:
```bash
./scripts/utils/homelab_verificar_quedas.sh
```
O script audita o sistema em 4 camadas em menos de 5 segundos:
1. **Armazenamento e I/O:** Testa a leitura real nos 3 HDs e nos bind mounts (`Downloads/media` e `immich/upload`). Detecta montagens fantasmas (quando o cabo USB oscila e o disco re-enumera de `/dev/sda` para `/dev/sdd`, deixando o container com `EIO: i/o error`).
2. **Containers Docker:** Detecta containers em reinício contínuo (`Restarting`), mortos com erro (`ExitCode != 0`), abatidos por falta de memória RAM (`OOMKilled`) ou com healthcheck interno falho (`unhealthy`).
3. **Auditoria de Endpoints HTTP:** Faz testes reais nas 21 portas de serviços locais e no Gateway do Umbrel, detectando códigos `502`, `503`, `504` ou portas mortas.
4. **Inspeção de Logs dos Afetados:** Coleta automaticamente as últimas 15 linhas de erro do container com defeito e indica exatamente qual comando de restauração executar.

---

### 9. Restaurador Inteligente de Serviços & Auto-Cura de Armazenamento
Para reanimar serviços travados, reparar montagens zumbis ou restaurar o Immich/Jellyfin/Nextcloud após uploads intensos ou oscilação de cabo USB:

#### A. Modo Inteligente (Auto-Cura Automática)
```bash
./scripts/utils/homelab_restaurar_servicos.sh
```
Escaneia o estado do Homelab e só mexe no que estiver realmente com problema (se apenas o Immich estiver fora, restaura apenas o Immich e suas dependências sem derrubar o resto do sistema).

#### B. Restauração Específica do Immich (Fotos & IA)
```bash
./scripts/utils/homelab_restaurar_servicos.sh --service immich
```
Executa a cadeia completa de auto-cura do Immich:
1. Verifica se o `disk2` está com erro de I/O e remonta por UUID se necessário.
2. Re-aplica o bind mount de `/upload` do Immich.
3. Reinicia os bancos de dados (`immich_postgres_1` e `immich_redis_1`).
4. Reinicia os motores de IA e aplicação (`immich_machine-learning_1` e `immich_server_1`).
5. Valida a API via HTTP 200 e confirma o restabelecimento do serviço.

#### C. Restauração Específica do Jellyfin ou Nextcloud
```bash
# Restaurar Servidor de Mídia Jellyfin (re-amarra bind mount de mídia no disk1)
./scripts/utils/homelab_restaurar_servicos.sh --service jellyfin

# Restaurar Nuvem de Arquivos Nextcloud
./scripts/utils/homelab_restaurar_servicos.sh --service nextcloud
```

#### D. Reinicialização de Stacks Compose Customizadas
```bash
# Recriar stack Arr (qBittorrent, Prowlarr, Radarr, Sonarr, Bazarr)
./scripts/utils/homelab_restaurar_servicos.sh --stack arr-stack

# Recriar stack de Gerenciamento (Dockge, Dozzle, IT-Tools, NPM)
./scripts/utils/homelab_restaurar_servicos.sh --stack management

# Recriar stack de Túneis Remotos zrok v2
./scripts/utils/homelab_restaurar_servicos.sh --stack tunnels
```

#### E. Restauração Geral Completa (Força Total)
```bash
./scripts/utils/homelab_restaurar_servicos.sh --all
```
Executa a faxina completa de desmontagem forçada (`umount -l`) de pontos zumbis, remonta os 3 HDs canônicos pelos seus UUIDs de hardware, re-aplica todos os bind mounts de mídia/fotos, reinicia Samba e todos os containers oficiais e customizados.



