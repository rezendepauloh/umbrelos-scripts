#!/usr/bin/env bash
# ==============================================================================
# scripts/utils/homelab_hardlinks.sh
# ------------------------------------------------------------------------------
# Utilitario para eliminar arquivos duplicados entre qBittorrent (torrents/)
# e Jellyfin/Radarr/Sonarr (movies/ e series/) usando hardlinks nativos em ext4,
# alem de permitir organizar downloads manuais futuros via hardlink (1x espaco).
#
# Uso:
#   ./scripts/utils/homelab_hardlinks.sh status
#   ./scripts/utils/homelab_hardlinks.sh dedup [--dry-run | --apply] [--fast] [--min-mb 10]
#   ./scripts/utils/homelab_hardlinks.sh link <origem_em_torrents> <destino>
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../.." && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.env"
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

SERVER_HOST="${SERVER_HOST:-192.168.0.8}"
SERVER_USER="${SERVER_USER:-umbrel}"
SSH_KEY="${HOME}/.ssh/id_ed25519"
MEDIA_BASE="${MEDIA_DIR:-/home/umbrel/umbrel/external/disk1/media}"

IS_LOCAL=false
if [[ "$(hostname 2>/dev/null || true)" == "umbrel" ]] || [[ -d "/data/umbrel-os" ]] || [[ -d "$MEDIA_BASE" ]]; then
    IS_LOCAL=true
fi

usage() {
    cat << 'EOF'
Uso:
  homelab_hardlinks.sh status
      Mostra resumo rapido (por tamanho e inode) de arquivos hardlinked vs duplicados.

  homelab_hardlinks.sh dedup [--dry-run | --apply] [--fast] [--min-mb N]
      Compara arquivos em torrents/ com movies/ e series/.
      Por padrao usa SHA-256 completo e roda em --dry-run (nao altera nada).
      --fast: valida por tamanho exato + SHA-256 de 3 amostras de 1 MiB (inicio, meio e fim),
              concluindo em poucos segundos no HD externo.
      --apply: substitui copias identicas por hardlinks preservando o seed e os nomes do Jellyfin.

  homelab_hardlinks.sh link <origem> <destino>
      Organiza um arquivo ou pasta de download manual criando hardlinks (cp -al / ln)
      em vez de copia fisica. Ambos os caminhos devem estar no disk1.
EOF
}

if [[ $# -lt 1 ]]; then
    usage
    exit 1
fi

CMD="$1"
shift

if [[ "$IS_LOCAL" = false ]]; then
    exec ssh -i "${SSH_KEY}" -o ConnectTimeout=5 "${SERVER_USER}@${SERVER_HOST}" \
        bash -s -- "$CMD" "$@" < "${BASH_SOURCE[0]}"
fi

run_dedup_python() {
    local mode="$1"
    local apply_flag="$2"
    local min_mb="$3"
    local fast_flag="$4"

    python3 - "$MEDIA_BASE" "$mode" "$apply_flag" "$min_mb" "$fast_flag" << 'PYEOF'
import hashlib
import os
import sys
from collections import defaultdict

media_base = sys.argv[1]
mode = sys.argv[2]
apply_changes = sys.argv[3] == "true"
min_bytes = int(sys.argv[4]) * 1024 * 1024
fast_mode = sys.argv[5] == "true"

torrents_dir = os.path.join(media_base, "torrents")
target_dirs = [os.path.join(media_base, "movies"), os.path.join(media_base, "series")]

if not os.path.isdir(torrents_dir):
    print(f"Erro: diretorio nao encontrado: {torrents_dir}", file=sys.stderr)
    sys.exit(1)

torrents_dev = os.stat(torrents_dir).st_dev
for td in target_dirs:
    if os.path.isdir(td) and os.stat(td).st_dev != torrents_dev:
        print(f"Erro: {td} esta em dispositivo/mount diferente de {torrents_dir}. Hardlinks impossiveis.", file=sys.stderr)
        sys.exit(1)

def should_skip(path: str) -> bool:
    rel = os.path.relpath(path, media_base)
    parts = rel.split(os.sep)
    if "incomplete" in parts or "@eaDir" in parts:
        return True
    if path.endswith(".!qB") or ".hl_tmp." in os.path.basename(path):
        return True
    return False

def file_fingerprint(path: str, size: int, cache: dict) -> str:
    key = (path, fast_mode)
    if key in cache:
        return cache[key]
    h = hashlib.sha256()
    if fast_mode:
        block = 1024 * 1024
        offsets = [0]
        if size > block * 2:
            offsets.append(max(0, (size // 2) - (block // 2)))
        if size > block:
            offsets.append(max(0, size - block))
        with open(path, "rb") as f:
            for off in offsets:
                f.seek(off)
                h.update(f.read(block))
    else:
        with open(path, "rb") as f:
            while True:
                chunk = f.read(4 * 1024 * 1024)
                if not chunk:
                    break
                h.update(chunk)
    digest = h.hexdigest()
    cache[key] = digest
    return digest

by_size = defaultdict(list)
t_count = 0
t_hardlinked = 0

for dp, _, fns in os.walk(torrents_dir):
    for fn in fns:
        p = os.path.join(dp, fn)
        if should_skip(p):
            continue
        try:
            st = os.stat(p)
        except OSError:
            continue
        if st.st_size < min_bytes:
            continue
        t_count += 1
        if st.st_nlink > 1:
            t_hardlinked += 1
        by_size[st.st_size].append((p, st.st_ino, st.st_nlink))

print(f"Torrents (>= {sys.argv[4]} MiB): {t_count} arquivos ({t_hardlinked} ja em hardlink)", flush=True)

hash_cache = {}
total_candidates = 0
total_converted = 0
total_bytes_saved = 0
total_errors = 0
hash_label = "amostra 3x1MiB" if fast_mode else "SHA-256 completo"

for td in target_dirs:
    if not os.path.isdir(td):
        continue
    td_name = os.path.basename(td)
    td_files = 0
    td_hl = 0
    td_dup = 0
    td_dup_bytes = 0

    for dp, _, fns in os.walk(td):
        for fn in sorted(fns):
            tgt = os.path.join(dp, fn)
            if should_skip(tgt):
                continue
            try:
                st = os.stat(tgt)
            except OSError:
                continue
            if st.st_size < min_bytes:
                continue
            td_files += 1
            if st.st_size not in by_size:
                if st.st_nlink > 1:
                    td_hl += 1
                continue

            src_list = by_size[st.st_size]
            src_inos = {x[1] for x in src_list}
            if st.st_ino in src_inos:
                td_hl += 1
                continue

            if mode == "status":
                td_dup += 1
                td_dup_bytes += st.st_size
                total_candidates += 1
                total_bytes_saved += st.st_size
                continue

            tgt_hash = file_fingerprint(tgt, st.st_size, hash_cache)
            matched_src = None
            for src_path, _, _ in src_list:
                if file_fingerprint(src_path, st.st_size, hash_cache) == tgt_hash:
                    matched_src = src_path
                    break

            if not matched_src:
                continue

            td_dup += 1
            td_dup_bytes += st.st_size
            total_candidates += 1
            gib = st.st_size / (1024 ** 3)

            if not apply_changes:
                print(f"[DRY-RUN] {tgt} -> {matched_src} ({gib:.2f} GiB)", flush=True)
                total_bytes_saved += st.st_size
                continue

            tmp_path = f"{tgt}.hl_tmp.{os.getpid()}"
            try:
                if os.path.exists(tmp_path):
                    os.unlink(tmp_path)
                os.link(matched_src, tmp_path)
                if os.stat(tmp_path).st_ino != os.stat(matched_src).st_ino:
                    raise RuntimeError("Inode divergente apos os.link")
                os.replace(tmp_path, tgt)
                total_converted += 1
                total_bytes_saved += st.st_size
                print(f"[HARDLINK] {tgt} -> {matched_src} ({gib:.2f} GiB)", flush=True)
            except Exception as exc:
                total_errors += 1
                print(f"[ERRO] Falha ao criar hardlink para {tgt}: {exc}", file=sys.stderr, flush=True)
                try:
                    if os.path.exists(tmp_path):
                        os.unlink(tmp_path)
                except OSError:
                    pass

    print(
        f"{td_name}: {td_files} arquivos | {td_hl} em hardlink | "
        f"{td_dup} duplicados ({td_dup_bytes / (1024 ** 3):.2f} GiB)",
        flush=True,
    )

print("-" * 60)
if mode == "status":
    print(f"Candidatos a deduplicacao (por tamanho): {total_candidates} arquivos ({total_bytes_saved / (1024 ** 3):.2f} GiB)")
elif not apply_changes:
    print(f"[DRY-RUN | {hash_label}] Validados: {total_candidates} arquivos ({total_bytes_saved / (1024 ** 3):.2f} GiB economizaveis)")
    print("Execute com '--apply' para converter essas copias em hardlinks.")
else:
    print(f"Convertidos em hardlinks ({hash_label}): {total_converted}/{total_candidates} | Erros: {total_errors} | Espaco liberado: {total_bytes_saved / (1024 ** 3):.2f} GiB")
    if total_errors > 0:
        sys.exit(1)
PYEOF
}

case "$CMD" in
    status)
        run_dedup_python "status" "false" "10" "false"
        ;;
    dedup)
        APPLY="false"
        FAST="false"
        MIN_MB="10"
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --apply) APPLY="true"; shift ;;
                --dry-run) APPLY="false"; shift ;;
                --fast) FAST="true"; shift ;;
                --min-mb) MIN_MB="${2:?Informe valor para --min-mb}"; shift 2 ;;
                -h|--help) usage; exit 0 ;;
                *) echo "Opcao desconhecida: $1" >&2; usage; exit 1 ;;
            esac
        done
        run_dedup_python "dedup" "$APPLY" "$MIN_MB" "$FAST"
        ;;
    link)
        if [[ $# -ne 2 ]]; then
            echo "Erro: 'link' exige <origem> e <destino>." >&2
            usage
            exit 1
        fi
        SRC="$1"
        DST="$2"
        if [[ ! -e "$SRC" ]]; then
            echo "Erro: origem nao existe: $SRC" >&2
            exit 1
        fi
        DEV_SRC=$(stat -c '%d' "$SRC")
        mkdir -p "$(dirname "$DST")"
        DEV_DST=$(stat -c '%d' "$(dirname "$DST")")
        if [[ "$DEV_SRC" != "$DEV_DST" ]]; then
            echo "Erro: origem ($SRC) e destino ($DST) estao em filesystems diferentes. Hardlink impossivel." >&2
            exit 1
        fi
        if [[ -d "$SRC" ]]; then
            cp -al "$SRC" "$DST"
        else
            ln -f "$SRC" "$DST"
        fi
        echo "Hardlink criado com sucesso: $DST -> $SRC"
        ;;
    -h|--help|help)
        usage
        ;;
    *)
        echo "Subcomando desconhecido: $CMD" >&2
        usage
        exit 1
        ;;
esac
