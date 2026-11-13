# 🧪 Suíte de Testes Automatizada — Homelab umbrelOS

Esta suíte de testes padronizada segue rigorosamente a mesma arquitetura dos projetos **Pop!_OS Workstation Setup**, **Espanso STI** e **Paulo Investimentos**, com suporte tanto para validação estática de código (unitários) quanto para integridade remota da infraestrutura (integração).

---

## 📁 Estrutura de Diretórios

```
tests/
├── run_all.py                    # Runner principal unificado com saída ANSI e estatísticas
├── run_all.sh                    # Wrapper Bash com fallback automático e opções CLI
├── test_framework.sh             # Biblioteca core de asserções Bash e comandos remotos
├── unit/                         # 🔧 Testes Unitários (Rodam no Pop!_OS sem tocar no servidor)
│   ├── test_syntax.py            # Validação de sintaxe Bash (bash -n), Compose YAML e +x
│   └── test_config_consistency.py# Validação de templates, AGENTS.md, UUIDs e auditoria anti-vazamento de segredos
└── integration/                  # 🚀 Testes de Integração (Rodam no Mini PC via SSH ou localmente)
    ├── test_homelab_integration.py # Ponte Python para orquestrar os testes de infraestrutura
    ├── test_storage_and_mounts.sh  # Pontos de montagem disk1, disk2, disk3 e bind mounts
    ├── test_samba_services.sh      # Daemons smbd, nmbd, wsdd2, chattr +i e shares
    ├── test_docker_stacks.sh       # Stacks e 20+ containers Docker essenciais
    ├── test_http_endpoints.sh      # Portas HTTP, UIs web locais e autenticação do ttyd
    ├── test_remote_tunnels.sh      # 5 túneis públicos zrok v2, Basic Auth, bloqueio do painel e VPN Tailscale
    └── test_config_unification.sh  # Symlinks .env -> /data/config.env, permissões 600/640 e compose config
```

---

## 🚀 Como Executar

### 1. Executar Suíte Completa (Unitários + Integração Remota)
```bash
./tests/run_all.sh
# ou
python3 tests/run_all.py
```

### 2. Executar Apenas Testes Unitários de Código (Local / Rápido)
Testa apenas a sintaxe de todos os scripts `.sh`, permissões, arquivos Docker Compose e arquivos de configuração, sem precisar de acesso à rede ou ao mini PC:
```bash
./tests/run_all.sh --unit
# ou
python3 tests/run_all.py --unit
```

### 3. Executar Apenas Testes de Integração no Servidor (Remoto)
Verifica discos, Samba, containers, portas e túneis diretamente no mini PC `192.168.0.8`:
```bash
./tests/run_all.sh --integration
# ou
python3 tests/run_all.py --integration
```

### 4. Executar no Modo Puramente Bash
Caso queira rodar via runner tradicional Bash sem Python:
```bash
./tests/run_all.sh --bash
```

