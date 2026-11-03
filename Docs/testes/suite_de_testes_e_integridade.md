# 🧪 Suíte Unificada de Testes e Integridade (Homelab umbrelOS)

Este documento descreve a arquitetura, estrutura e o guia completo de execução da **Suíte de Testes Automatizada** do Homelab umbrelOS.

Seguindo o mesmo padrão arquitetural dos nossos projetos **Pop!_OS Workstation Setup**, **Espanso STI** e **Paulo Investimentos**, a suíte foi reformulada para oferecer:
1. **Testes Unitários Locais:** Validação estática e sintática instantânea dos scripts Bash (`bash -n`), permissões de execução (`+x`), arquivos Docker Compose e templates de configuração, sem precisar de rede ou tocar no servidor.
2. **Testes de Integração Remota:** Auditoria de infraestrutura no mini PC (`192.168.0.8`) cobrindo discos físicos, Samba, daemons de persistência, containers Docker, portas HTTP, túneis públicos zrok v2 e VPN Tailscale.
3. **Runners Flexíveis:** Suporte tanto a runner moderno em Python (`run_all.py` com estatísticas ANSI detalhadas em milissegundos) quanto a wrapper executável em Bash (`run_all.sh`).

---

## 🎯 Objetivo da Suíte

Garantir validações automatizadas de ponta a ponta sem intervenção manual após eventos críticos como:
1. Quedas de energia e reinicializações a frio (*dirty shutdowns*).
2. Atualizações de sistema do umbrelOS ou pacotes do Debian.
3. Criação ou atualização de stacks no Dockge.
4. Manutenções nas conexões USB e cabos dos HDs externos.
5. Edições em scripts de infraestrutura ou adições de novas variáveis/stacks.

---

## 🏗️ Arquitetura e Estrutura de Diretórios

A suíte está organizada no diretório [`tests/`](../../tests) com separação estrita entre testes unitários e de integração:

```text
tests/
├── run_all.py                      # Runner unificado Python com formatação ANSI, tempos e estatísticas
├── run_all.sh                      # Wrapper executável Bash inteligente com detecção de flags
├── README.md                       # Documentação técnica rápida de execução
├── test_framework.sh               # Biblioteca core de asserções Bash e comandos remotos via SSH
│
├── unit/                           # 🔧 TESTES UNITÁRIOS LOCAIS (Pop!_OS / Zero efeito colateral)
│   ├── test_syntax.py              # Valida 'bash -n' em scripts, YAML do Compose e permissões (+x)
│   └── test_config_consistency.py  # Valida consistência de config.env.example, UUIDs e ausência de senhas
│
└── integration/                    # 🚀 TESTES DE INTEGRAÇÃO REMOTA (Mini PC 192.168.0.8 via SSH)
    ├── test_homelab_integration.py # Ponte Python para orquestrar os testes de infraestrutura
    ├── test_storage_and_mounts.sh  # Testes de UUIDs de hardware, montagens e ausência de duplicatas
    ├── test_samba_services.sh      # Testes de daemons (smbd/nmbd/wsdd2), chattr +i e shares SMB
    ├── test_docker_stacks.sh       # Testes da homelab_network e status dos containers
    ├── test_http_endpoints.sh      # Testes de códigos HTTP nas portas das aplicações web
    └── test_remote_tunnels.sh      # Testes dos túneis públicos zrok v2 e VPN Tailscale
```

---

## 📋 O Que Cada Módulo Valida

| Módulo / Camada | Arquivo | Escopo de Validação |
| :--- | :--- | :--- |
| **Unitários: Sintaxe** | `unit/test_syntax.py` | Valida sintaxe de todos os scripts `.sh` via `bash -n`, verifica permissão de execução (`+x`), shebangs e integridade sintática dos arquivos `docker-compose.yml`. |
| **Unitários: Configs** | `unit/test_config_consistency.py` | Valida variáveis obrigatórias no `config.env.example`, confere UUIDs de hardware contra o `AGENTS.md` e bloqueia senhas reais expostas em arquivos commitáveis. |
| **Integração: Storage** | `integration/test_storage_and_mounts.sh` | Montagem de `disk1`, `disk2`, `disk3`; correspondência exata dos UUIDs de hardware (`fc0b5d7b-...` e `490440f1-...`); ausência de montagens duplicadas `*(2)`; bind mount nativo do Jellyfin em `/home/Downloads/media`. |
| **Integração: Samba** | `integration/test_samba_services.sh` | Status `active` para `smbd`, `nmbd` e `wsdd2`; blindagem imutável do kernel (`chattr +i` no `/etc/samba/smb.conf`); listagem e conexão real nas shares `[Compartilhado]` e `[Midia]` via `smbclient`. |
| **Integração: Docker** | `integration/test_docker_stacks.sh` | Presença da rede Docker `homelab_network`; status `running` para Dockge, Dozzle, qBittorrent, Prowlarr, Jackett, Radarr, Sonarr, Jellyseerr, Bazarr, Karteman, Evolution API, BeTor, Diários Oficiais, Investimentos, Jellyfin, Nextcloud, Immich, Tailscale e AdGuard. |
| **Integração: HTTP** | `integration/test_http_endpoints.sh` | Respostas HTTP válidas (`200`, `301`, `302`, `307`) em 19 portas de serviços locais (`:5001`, `:8888`, `:8085`, `:9696`, `:9117`, `:7878`, `:8989`, `:5055`, `:6767`, `:8123`, `:8091`, `:8092`, `:8093`, `:8094`, `:8096`, `:8081`, `:81`, `:8080`, `:8384`). |
| **Integração: Túneis** | `integration/test_remote_tunnels.sh` | Resposta online e código HTTP válido para os 6 túneis zrok v2 (`umbrel-paulo`, `cloud-paulo`, `jellyfin-paulo`, `karteman-paulo`, `diarios-paulo`, `investimentos-paulo`) e conectividade da VPN Tailscale (`100.88.159.41`). |

---

## 🚀 Como Executar os Testes

A suíte possui **detecção automática de ambiente**: identifica se está sendo executada a partir do Pop!_OS (disparando comandos remotos via SSH autenticado por chave) ou diretamente dentro do terminal do mini PC.

### 💻 1. Executar Apenas Testes Unitários de Código (Local e Instantâneo)
Ideal para verificar rapidamente se novos scripts foram criados com sintaxe válida e permissões corretas, sem depender de rede ou de conexão ao mini PC (executa em ~50ms):
```bash
./tests/run_all.sh --unit
# ou via Python diretamente:
python3 tests/run_all.py --unit
```

### 🖥️ 2. Executar Apenas Testes de Integração no Servidor (Remoto)
Conecta via SSH ao mini PC (`192.168.0.8`), executa checagens com privilégios adequados e audita periféricos, discos, containers, portas e túneis:
```bash
./tests/run_all.sh --integration
# ou via Python diretamente:
python3 tests/run_all.py --integration
```

### ⚡ 3. Executar a Suíte Completa de Ponta a Ponta (Recomendado)
Executa a bateria unitária local e, em seguida, a bateria remota completa:
```bash
./tests/run_all.sh
# ou:
python3 tests/run_all.py
```

### 🐚 4. Executar no Modo Puramente Bash
Caso esteja diretamente no servidor e queira rodar apenas os scripts `.sh` sem acionar o interpretador Python:
```bash
./tests/run_all.sh --bash
```

---

## 📊 Exemplo da Saída de Execução

```text
╔═══════════════════════════════════════════════════════════════╗
║     UMBRELOS SCRIPTS & HOMELAB — SUÍTE DE TESTES AUTOMATIZADA ║
╚═══════════════════════════════════════════════════════════════╝

▶ Executando Suíte: 🔧 Unitários: Sintaxe Bash, Compose YAML & Consistência de Configurações (/home/rezendepauloh/Documentos/DevProjects/Bash/umbrelos-scripts/tests/unit)
─────────────────────────────────────────────────────────────────
 ✔ PASS test_config_consistency.TestConfigAndArchitectureConsistency.test_01_config_example_contains_all_required_variables
 ✔ PASS test_config_consistency.TestConfigAndArchitectureConsistency.test_02_agents_md_has_canonical_uuids
 ✔ PASS test_config_consistency.TestConfigAndArchitectureConsistency.test_03_no_exposed_passwords_in_tracked_examples
 ✔ PASS test_syntax.TestBashSyntaxAndPermissions.test_01_all_bash_scripts_syntax_valid
 ✔ PASS test_syntax.TestBashSyntaxAndPermissions.test_02_all_scripts_have_shebang_and_permissions
 ✔ PASS test_syntax.TestBashSyntaxAndPermissions.test_03_docker_compose_files_valid_yaml
─────────────────────────────────────────────────────────────────
⏱ Tempo: 49.4ms | Rodados: 6 | Falhas: 0 | Erros: 0

▶ Executando Suíte: 🚀 Integração Remota: Storage, Samba, Docker, HTTP & Túneis zrok/Tailscale (/home/rezendepauloh/Documentos/DevProjects/Bash/umbrelos-scripts/tests/integration)
─────────────────────────────────────────────────────────────────
 ✔ PASS test_homelab_integration.TestHomelabIntegration.test_01_storage_and_mounts
 ✔ PASS test_homelab_integration.TestHomelabIntegration.test_02_samba_services_and_shares
 ✔ PASS test_homelab_integration.TestHomelabIntegration.test_03_docker_stacks_and_containers
 ✔ PASS test_homelab_integration.TestHomelabIntegration.test_04_http_endpoints_and_web_uis
 ✔ PASS test_homelab_integration.TestHomelabIntegration.test_05_remote_tunnels_and_tailscale
─────────────────────────────────────────────────────────────────
⏱ Tempo: 31101.0ms | Rodados: 5 | Falhas: 0 | Erros: 0

═════════════════════════════════════════════════════════════════
 ✔ SUCESSO: Todos os testes passaram perfeitamente!
 Total: 11 |  Passou: 11 |  Falhas: 0 |  Erros: 0 |  Ignorados: 0 |  Tempo Total: 31.15s
═════════════════════════════════════════════════════════════════
```

---

## 🛠️ Manutenção e Adição de Novos Testes

Para adicionar a validação de um novo serviço, aplicação ou túnel recém-adicionado:

1. **Novo Container Docker:** Abra [`tests/integration/test_docker_stacks.sh`](../../tests/integration/test_docker_stacks.sh) e adicione:
   ```bash
   check_container "nome-do-novo-container" "Descrição do Serviço"
   ```
2. **Nova Porta / Endpoint Web:** Abra [`tests/integration/test_http_endpoints.sh`](../../tests/integration/test_http_endpoints.sh) e adicione:
   ```bash
   assert_http_status "Nome da Aplicação (:PORTA)" "http://${HOST_IP}:PORTA" "200|302"
   ```
3. **Novo Túnel zrok v2:** Abra [`tests/integration/test_remote_tunnels.sh`](../../tests/integration/test_remote_tunnels.sh) e adicione:
   ```bash
   test_tunnel "Nome do Túnel" "https://subdominio.shares.zrok.io" "usuario:senha"
   ```
4. **Novas Variáveis de Configuração:** Adicione a variável na lista `required_vars` em [`tests/unit/test_config_consistency.py`](../../tests/unit/test_config_consistency.py).
5. Execute `./tests/run_all.sh` para confirmar que tudo passa com 100% de sucesso.
