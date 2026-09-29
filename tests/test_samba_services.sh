#!/usr/bin/env bash
# ==============================================================================
# tests/test_samba_services.sh - Testes do Servidor Samba e Compartilhamentos
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test_framework.sh"

start_suite "Serviços e Compartilhamentos Samba" "Validação de daemons, blindagem chattr +i e shares"

# 1. Checar daemons ativos no systemd
assert_cmd_success "Serviço smbd (Samba SMB Daemon)" "systemctl is-active --quiet smbd" "active"
assert_cmd_success "Serviço nmbd (Samba NetBIOS Name Server)" "systemctl is-active --quiet nmbd" "active"
assert_cmd_success "Serviço wsdd2 (WSD/LLMNR Discovery)" "systemctl is-active --quiet wsdd2" "active"

# 2. Checar se a blindagem imutável chattr +i do smb.conf está ativa
SMB_ATTR=$(run_target_cmd "lsattr /etc/samba/smb.conf 2>/dev/null | awk '{print \$1}' | grep -o 'i' || true")
if [ "$SMB_ATTR" = "i" ]; then
    assert_pass "Blindagem imutável do smb.conf (chattr +i)" "Imutável contra sobrescrita do umbreld"
else
    assert_fail "smb.conf desprotegido contra sobrescrita" "Atributo 'i' ausente em /etc/samba/smb.conf"
fi

# 3. Testar conexão às shares de rede via smbclient
PASSWD='M!n0t@ur0'
if command -v smbclient >/dev/null 2>&1; then
    TARGET_IP="${TARGET_HOST}"
    [ "$IS_LOCAL_HOST" = true ] && TARGET_IP="127.0.0.1"

    if smbclient "//${TARGET_IP}/Compartilhado" -U "paulo%${PASSWD}" -c "ls" >/dev/null 2>&1; then
        assert_pass "Conexão e listagem de share [Compartilhado]" "//${TARGET_IP}/Compartilhado"
    else
        assert_fail "Falha ao conectar no compartilhamento [Compartilhado]"
    fi

    if smbclient "//${TARGET_IP}/Midia" -U "paulo%${PASSWD}" -c "ls" >/dev/null 2>&1; then
        assert_pass "Conexão e listagem de share [Midia]" "//${TARGET_IP}/Midia"
    else
        assert_fail "Falha ao conectar no compartilhamento [Midia]"
    fi
else
    assert_skip "smbclient não instalado no ambiente local" "Instale smbclient para validar shares"
fi
