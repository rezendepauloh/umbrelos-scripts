# 🧪 Suíte Unificada de Testes e Integridade (Homelab umbrelOS)

Este documento descreve a arquitetura, estrutura e o guia completo de execução da **Suíte de Testes e Integridade** desenvolvida em **Bash Nativo** para o Homelab umbrelOS.

Inspirada no modelo adotado no projeto *Sistema Karteman*, a suíte oferece relatórios no terminal com formatação rica em cores ANSI (`✔ PASS`, `✖ FAIL`, `⚡ SKIP`), cálculo de tempo de execução e contadores de cobertura.

---

## 🎯 Objetivo da Suíte

Garantir validações automatizadas de ponta a ponta sem intervenção manual após eventos críticos como:
1. Quedas de energia e reinicializações a frio (*dirty shutdowns*).
2. Atualizações de sistema do umbrelOS ou pacotes do Debian.
3. Criação ou atualização de stacks no Dockge.
4. Manutenções nas conexões USB e cabos dos HDs externos.

---

## 🏗️ Arquitetura e Módulos

A suíte está organizada no diretório [`tests/`](../tests) e é dividida em módulos independentes:

```text
umbrelos-scripts/
├── tests/
│   ├── run_all.sh                 # Runner unificado com seletor de módulos e relatório final
│   ├── test_framework.sh          # Motor de asserções, cores ANSI e alternância local/remoto
│   ├── test_storage_and_mounts.sh # Testes de UUIDs de hardware, montagens e ausência de duplicatas
│   ├── test_samba_services.sh     # Testes de daemons (smbd/nmbd/wsdd2), chattr +i e shares
│   ├── test_docker_stacks.sh      # Testes da homelab_network e status dos 40+ containers
│   └── test_http_endpoints.sh     # Testes de códigos HTTP nas portas das aplicações web
```

### O Que Cada Módulo Valida:

| Módulo | Escopo de Validação | Asserções Principais |
| :--- | :--- | :--- |
| **`storage`** | Armazenamento & Discos | Montagem de `disk1`, `disk2`, `disk3`; correspondência exata dos UUIDs de hardware (`fc0b5d7b-...` e `490440f1-...`); ausência de pontos duplicados fantasmas `*(2)`; bind mount nativo do Jellyfin em `/home/Downloads/media`. |
| **`samba`** | Compartilhamentos de Rede | Status `active` para `smbd`, `nmbd` e `wsdd2`; blindagem imutável do kernel (`chattr +i` no `/etc/samba/smb.conf`); listagem e conexão real nas shares `[Compartilhado]` e `[Midia]` via `smbclient`. |
| **`docker`** | Containers & Redes | Presença da rede Docker `homelab_network`; status `running` para Dockge, Dozzle, qBittorrent, Prowlarr, Karteman, Evolution API, BeTor, Diários Oficiais, Investimentos, Jellyfin, Nextcloud, Immich e AdGuard. |
| **`http`** | Aplicações Web | Respostas HTTP válidas (`200`, `302` ou `307`) em 13 portas de rede locais (`:5001`, `:8888`, `:8085`, `:9696`, `:8091`, `:8092`, `:8093`, `:8094`, `:8096`, `:8081`, `:81`, `:8080`, `:8384`). |

---

## 🚀 Como Executar os Testes

A suíte possui **detecção automática de ambiente**: ela identifica dinamicamente se está sendo executada a partir do seu computador pessoal (via SSH) ou de dentro do próprio mini PC.

### 💻 Opção 1: Executando a Partir do seu Computador (Pop!_OS)

Abra o terminal no repositório local e execute:

```bash
cd ~/Documentos/DevProjects/Bash/umbrelos-scripts

# 1. Executar a suíte completa de ponta a ponta (Recomendado)
./tests/run_all.sh

# 2. Executar apenas um módulo específico:
./tests/run_all.sh storage   # Apenas discos e montagens
./tests/run_all.sh samba     # Apenas serviços e shares Samba
./tests/run_all.sh docker    # Apenas containers Docker
./tests/run_all.sh http      # Apenas endpoints e portas web
```

> **Nota:** A execução remota utiliza a sua chave SSH configurada em `~/.ssh/id_ed25519` apontando para o IP do mini PC (`192.168.0.8`).

---

### 🖥️ Opção 2: Executando Diretamente no Mini PC (SSH)

Você também pode rodar a suíte diretamente no terminal do servidor:

```bash
# Conectar via SSH ao mini PC
ssh -i ~/.ssh/id_ed25519 umbrel@192.168.0.8

# Acessar a pasta e rodar
cd ~/umbrelos-scripts
./tests/run_all.sh
```

Ou em um único comando remoto:

```bash
ssh -i ~/.ssh/id_ed25519 umbrel@192.168.0.8 "/home/umbrel/umbrelos-scripts/tests/run_all.sh"
```

---

## 📊 Exemplo da Saída de Execução

```text
========================================================================
🚀 SUÍTE DE TESTES E INTEGRIDADE — HOMELAB UMBRELOS
Ambiente de Execução: REMOTO (Pop!_OS → 192.168.0.8)
========================================================================

▶ Executando Suíte: Armazenamento Físico e Montagens (Validação de UUIDs, ausência de duplicatas e bind mounts)
 ✔ PASS Ponto de montagem disk1 (Mídia & Downloads) (ext4 Seagate 1TB)
 ✔ PASS Ponto de montagem disk2 (Nuvem & Usuários) (ext4 A-DATA 1TB)
 ✔ PASS Ponto de montagem disk3 (Backups Locais) (ext4 Samsung 1TB)
 ✔ PASS UUID de hardware do disk1 confere (fc0b5d7b-1706-4461-9e1e-9d3f61e7bab0)
 ✔ PASS UUID de hardware do disk2 confere (490440f1-8f2e-41fd-bc27-00632adec790)
 ✔ PASS Inexistência de montagens duplicadas com *(2) (Limpo)
 ✔ PASS Bind mount nativo do Jellyfin (/external/disk1/media -> Downloads/media) (Ativo)

▶ Executando Suíte: Serviços e Compartilhamentos Samba (Validação de daemons, blindagem chattr +i e shares)
 ✔ PASS Serviço smbd (Samba SMB Daemon) (active)
 ✔ PASS Serviço nmbd (Samba NetBIOS Name Server) (active)
 ✔ PASS Serviço wsdd2 (WSD/LLMNR Discovery) (active)
 ✔ PASS Blindagem imutável do smb.conf (chattr +i) (Imutável contra sobrescrita do umbreld)
 ✔ PASS Conexão e listagem de share [Compartilhado] (//192.168.0.8/Compartilhado)
 ✔ PASS Conexão e listagem de share [Midia] (//192.168.0.8/Midia)

▶ Executando Suíte: Containers e Stacks Docker (Validação de integridade dos 40+ containers)
 ✔ PASS Rede compartilhada homelab_network (presente)
 ✔ PASS Container dockge (Gerenciador de Stacks - running)
 ✔ PASS Container dozzle (Visualizador de Logs - running)
 ✔ PASS Container qbittorrent (Cliente BitTorrent - running)
 ✔ PASS Container prowlarr (Gerenciador de Indexadores - running)
 ✔ PASS Container karteman-app (Sistema Karteman App - running)
 ✔ PASS Container karteman-evolution-api (Evolution API WhatsApp - running)
 ✔ PASS Container betor-api (Buscador Nacional BeTor - running)
 ✔ PASS Container betor-scrapyd (Crawler BeTor - running)
 ✔ PASS Container verifica-diarios-app (Verificador Diários Oficiais - running)
 ✔ PASS Container paulo-investimentos-app (Investimentos Pessoais - running)
 ✔ PASS Container jellyfin_server_1 (Jellyfin Media Server - running)
 ✔ PASS Container nextcloud_web_1 (Nextcloud Hub - running)
 ✔ PASS Container immich_server_1 (Immich Photo Backup - running)
 ✔ PASS Container adguard-home_server_1 (AdGuard Home DNS - running)

▶ Executando Suíte: Endpoints HTTP e Portas de Rede (Validação de disponibilidade das aplicações web)
 ✔ PASS Dockge Web UI (:5001) (HTTP 200)
 ✔ PASS Dozzle Log Viewer (:8888) (HTTP 307)
 ✔ PASS qBittorrent Web UI (:8085) (HTTP 200)
 ✔ PASS Prowlarr Indexer Manager (:9696) (HTTP 302)
 ✔ PASS Sistema Karteman App (:8091) (HTTP 302)
 ✔ PASS Evolution API (:8092) (HTTP 200)
 ✔ PASS Verificador Diários Oficiais (:8093) (HTTP 200)
 ✔ PASS Paulo Investimentos Pessoais (:8094) (HTTP 200)
 ✔ PASS Jellyfin Media Server (:8096) (HTTP 302)
 ✔ PASS Nextcloud Hub (:8081) (HTTP 302)
 ✔ PASS Nginx Proxy Manager (:81) (HTTP 200)
 ✔ PASS IT-Tools (:8080) (HTTP 200)
 ✔ PASS Syncthing (:8384) (HTTP 200)

========================================================================
✔ SUCESSO: Todos os testes passaram!
Total: 41 | Passou: 41 | Falhas: 0 | Ignorados: 0 | Tempo: 8.89s
========================================================================
```

---

## 🛠️ Manutenção e Adição de Novos Testes

Para adicionar a validação de uma nova aplicação ou serviço recém-instalado:

1. **Novo Container Docker:** Abra [`tests/test_docker_stacks.sh`](../tests/test_docker_stacks.sh) e adicione:
   ```bash
   check_container "nome-do-novo-container" "Descrição do Serviço"
   ```
2. **Nova Porta / Endpoint Web:** Abra [`tests/test_http_endpoints.sh`](../tests/test_http_endpoints.sh) e adicione:
   ```bash
   assert_http_status "Nome da Aplicação (:PORTA)" "http://${HOST_IP}:PORTA" "200|302"
   ```
3. Execute `./tests/run_all.sh` para verificar a integração.
