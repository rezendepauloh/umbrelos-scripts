# 🛠️ Guia de Autonomia e Manutenção Remota do Homelab

> **Objetivo:** Este manual documenta a suíte de scripts executáveis desenvolvida para que você possa diagnosticar, auditar e manter o seu Mini PC (`umbrelOS`) com **100% de autonomia diretamente do seu Pop!_OS**, sem necessitar do auxílio constante de IA ou comandos manuais complexos via SSH.

---

## 📌 Visão Geral dos Utilitários em `scripts/utils/`

| Script | Função Principal | Quando Usar |
| :--- | :--- | :--- |
| **[`homelab_dashboard_saude.sh`](scripts/utils/homelab_dashboard_saude.sh)** | Painel completo de CPU, memória, temperatura, horas de uso e saúde SMART dos discos. | Para acompanhar a saúde física de hardware, tempo ligado e estado dos HDs. |
| **[`recuperar_hds_remoto.sh`](scripts/utils/recuperar_hds_remoto.sh)** | Desmonta montagens fantasmas com erro de I/O, remonta por UUID e restaura Samba/Jellyfin. | Quando uma pasta Samba sumir ou o cabo USB oscilar/desconectar. |
| **[`homelab_atualizar_stacks.sh`](scripts/utils/homelab_atualizar_stacks.sh)** | Varre as stacks Compose, baixa novas imagens e só recria o que mudou. | Periodicamente (ex: semanalmente) para manter os apps atualizados. |
| **[`homelab_limpeza_docker.sh`](scripts/utils/homelab_limpeza_docker.sh)** | Poda de imagens órfãs, containers mortos e trunca logs gigantescos do Docker. | Quando quiser liberar gigabytes de espaço no SSD NVMe. |
| **[`homelab_auditar_zrok.sh`](scripts/utils/homelab_auditar_zrok.sh)** | Testa os 6 túneis zrok v2 e o Tailscale com códigos de retorno HTTP. | Antes de sair de casa para garantir que os links externos estão funcionando. |
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

