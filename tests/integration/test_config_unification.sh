#!/usr/bin/env bash
# ==============================================================================
# tests/test_config_unification.sh - Validação da Unificação de Variáveis (.env vs config.env)
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../test_framework.sh"

start_suite "Unificação de Configurações (.env / config.env)" "Validação de symlinks canônicos e ausência de warnings em stacks Docker"

# 1. Verificar se /data/config.env existe, tem permissões seguras (sem leitura para 'others') e possui as variáveis unificadas
assert_cmd_success "/data/config.env existe no servidor" "test -f /data/config.env" "presente"
assert_cmd_success "Permissões restritas em /data/config.env (600 ou 640)" "stat -c '%a' /data/config.env | grep -qxE '600|640'" "protegido contra leitura pública"
assert_cmd_success "Permissões restritas em config.env local do servidor (600 ou ausente)" "test ! -f /home/umbrel/umbrelos-scripts/config.env || stat -c '%a' /home/umbrel/umbrelos-scripts/config.env | grep -qxE '600|640'" "protegido"
assert_cmd_success "Variável BETOR_MONGO_USER presente" "grep -q '^BETOR_MONGO_USER=' /data/config.env" "configurado"
assert_cmd_success "Variável BETOR_MONGO_PASSWORD presente" "grep -q '^BETOR_MONGO_PASSWORD=' /data/config.env" "configurado"
assert_cmd_success "Variável STORAGE_BASE_DIR presente" "grep -q '^STORAGE_BASE_DIR=' /data/config.env" "configurado"

# 2. Verificar se /home/umbrel/umbrelos-scripts/.env é um symlink para /data/config.env
assert_cmd_success "Symlink /home/umbrel/umbrelos-scripts/.env aponta para /data/config.env" \
    "test -L /home/umbrel/umbrelos-scripts/.env && [ \"\$(readlink -f /home/umbrel/umbrelos-scripts/.env)\" = '/data/config.env' ]" \
    "symlink válido"

# 3. Testar validação de sintaxe e interpolação de variáveis no Docker Compose para todas as stacks
test_stack_compose() {
    local stack_name="$1"
    local compose_dir="/home/umbrel/umbrelos-scripts/compose/${stack_name}"
    
    # Executa docker compose config passando --env-file /data/config.env e captura stderr
    local out
    out=$(run_target_cmd "cd ${compose_dir} && docker compose --env-file /data/config.env config 2>&1")
    
    if echo "$out" | grep -qi "variable is not set"; then
        assert_fail "docker compose config ${stack_name}" "Aviso de variável não definida detectado: ${out}"
    else
        assert_pass "docker compose config ${stack_name}" "Configuração válida e sem avisos de variáveis vazias"
    fi
}

test_stack_compose "management"
test_stack_compose "arr-stack"
test_stack_compose "betor"
test_stack_compose "tunnels"

