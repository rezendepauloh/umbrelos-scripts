#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

DAEMON="${REPO_ROOT}/scripts/daemons/homelab-daemon.sh"
UTIL="${REPO_ROOT}/scripts/utils/homelab_fix_mounts.sh"
GUIDE="${REPO_ROOT}/Docs/guias/persistencia_volumes_loja_umbrel.md"

echo "=== Testando Persistência de Mounts (--fix-mounts) ==="

# 1. Sintaxe Bash
bash -n "$DAEMON"
bash -n "$UTIL"
echo "✔ Sintaxe Bash válida (daemon e util)"

# 2. Permissões de execução
[ -x "$UTIL" ] || { echo "✖ $UTIL não é executável"; exit 1; }
echo "✔ $UTIL é executável"

# 3. Funções e flag --fix-mounts no homelab-daemon.sh
for pattern in "ensure_jellyfin_bind_mount" "ensure_immich_bind_mount" "ensure_nextcloud_volumes" "--fix-mounts"; do
    grep -q -- "$pattern" "$DAEMON" || { echo "✖ Padrão '$pattern' ausente em $DAEMON"; exit 1; }
done
echo "✔ Funções de mount e flag --fix-mounts presentes no daemon"

# 4. Script utilitário aponta para --fix-mounts
grep -q "/data/bin/homelab-daemon.sh --fix-mounts" "$UTIL" || { echo "✖ $UTIL não chama --fix-mounts"; exit 1; }
echo "✔ Script utilitário chama /data/bin/homelab-daemon.sh --fix-mounts"

# 5. Guia de documentação existe e está atualizado
[ -f "$GUIDE" ] || { echo "✖ Guia $GUIDE não encontrado"; exit 1; }
grep -q "homelab_fix_mounts.sh" "$GUIDE" || { echo "✖ Guia não referencia homelab_fix_mounts.sh"; exit 1; }
grep -q "Immich" "$GUIDE" || { echo "✖ Guia não referencia Immich"; exit 1; }
echo "✔ Guia de documentação verificado"

echo "=== TODOS OS TESTES PASSARAM (100%) ==="
