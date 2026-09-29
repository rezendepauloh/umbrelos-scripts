#!/usr/bin/env bash
# ==============================================================================
# tests/test_storage_and_mounts.sh - Testes de Discos, UUIDs e Montagens
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test_framework.sh"

start_suite "Armazenamento Físico e Montagens" "Validação de UUIDs, ausência de duplicatas e bind mounts"

# 1. Testar montagens canônicas
assert_cmd_success "Ponto de montagem disk1 (Mídia & Downloads)" "mountpoint -q /home/umbrel/umbrel/external/disk1" "ext4 Seagate 1TB"
assert_cmd_success "Ponto de montagem disk2 (Nuvem & Usuários)" "mountpoint -q /home/umbrel/umbrel/external/disk2" "ext4 A-DATA 1TB"
assert_cmd_success "Ponto de montagem disk3 (Backups Locais)" "mountpoint -q /home/umbrel/umbrel/external/disk3" "ext4 Samsung 1TB"

# 2. Testar UUIDs de hardware correspondentes
UUID1=$(run_target_cmd "findmnt -n -o UUID /home/umbrel/umbrel/external/disk1 2>/dev/null || true")
if [[ "$UUID1" == "fc0b5d7b-1706-4461-9e1e-9d3f61e7bab0" ]]; then
    assert_pass "UUID de hardware do disk1 confere" "$UUID1"
else
    assert_fail "UUID de hardware do disk1 divergente" "Esperado fc0b5d7b..., recebido: '$UUID1'"
fi

UUID2=$(run_target_cmd "findmnt -n -o UUID /home/umbrel/umbrel/external/disk2 2>/dev/null || true")
if [[ "$UUID2" == "490440f1-8f2e-41fd-bc27-00632adec790" ]]; then
    assert_pass "UUID de hardware do disk2 confere" "$UUID2"
else
    assert_fail "UUID de hardware do disk2 divergente" "Esperado 490440f1..., recebido: '$UUID2'"
fi

# 3. Testar ausência absoluta de montagens duplicadas sufixadas com (2)
DUP_MOUNTS=$(run_target_cmd "mount | grep -E 'external/.*\(2\)' || true")
if [ -z "$DUP_MOUNTS" ]; then
    assert_pass "Inexistência de montagens duplicadas com *(2)" "Limpo"
else
    assert_fail "Detectadas montagens duplicadas residuais" "$DUP_MOUNTS"
fi

# 4. Testar Bind mount do Jellyfin
assert_cmd_success "Bind mount nativo do Jellyfin (/external/disk1/media -> Downloads/media)" "mountpoint -q /home/umbrel/umbrel/home/Downloads/media" "Ativo"
