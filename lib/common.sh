#!/usr/bin/env bash
# ==============================================================================
# lib/common.sh - Biblioteca de funções utilitárias e idempotentes
# ==============================================================================

# Cores e Formatação ANSI
BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Funções de Logging
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "\n${BOLD}${CYAN}==>${NC} ${BOLD}$1${NC}"
}

# Verificação de privilégios de root
check_root() {
    if [[ "$EUID" -ne 0 ]]; then
        log_error "Este script precisa ser executado como root ou via sudo."
        exit 1
    fi
}

# Checar se um comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Criar diretório idempotente com permissões específicas
ensure_dir() {
    local dir_path="$1"
    local owner="${2:-$SYSTEM_USER}"
    local group="${3:-$SYSTEM_GROUP}"
    local mode="${4:-775}"

    if [[ ! -d "$dir_path" ]]; then
        mkdir -p "$dir_path"
        log_info "Diretório criado: $dir_path"
    fi

    if id "$owner" >/dev/null 2>&1; then
        chown -R "$owner":"$group" "$dir_path" 2>/dev/null || true
    fi
    chmod "$mode" "$dir_path" 2>/dev/null || true
}

# Inserção idempotente em arquivo de configuração delimitada por bloco
# Uso: ensure_config_block "identificador" "/caminho/arquivo" "conteudo"
ensure_config_block() {
    local block_id="$1"
    local file_path="$2"
    local content="$3"
    local start_marker="# BEGIN UMBREL_SETUP_${block_id}"
    local end_marker="# END UMBREL_SETUP_${block_id}"

    touch "$file_path"

    if grep -qF "$start_marker" "$file_path"; then
        # Substitui bloco existente
        sed -i "/${start_marker}/,/${end_marker}/d" "$file_path"
    fi

    {
        echo "$start_marker"
        echo -e "$content"
        echo "$end_marker"
    } >> "$file_path"
    log_success "Bloco de configuração [${block_id}] aplicado em ${file_path}"
}

# Adição de linha única idempotente em arquivo
ensure_line_in_file() {
    local line="$1"
    local file_path="$2"

    touch "$file_path"
    if ! grep -Fxq "$line" "$file_path"; then
        echo "$line" >> "$file_path"
        log_info "Linha adicionada em $file_path: $line"
    fi
}
