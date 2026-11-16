#!/usr/bin/env bash
# ==============================================================================
# tests/integration/test_betor_arr_hardlinks.sh
# Valida BeTor (API, Scrapyd, workers Celery, timer systemd), integração com
# Prowlarr/Radarr/Sonarr/qBittorrent e suporte real a hardlinks em /media.
# Executa todas as checagens em UMA única sessão SSH para evitar rate-limit.
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../test_framework.sh"

start_suite "BeTor, Arr-Stack & Hardlinks" "Validação ponta a ponta no Mini PC"

remote_b64=$(base64 -w0 << 'REMOTE_EOF'
#!/usr/bin/env bash
set -u

emit() {
    echo "$1|$2|$3"
}

# 1. Containers BeTor + FlareSolverr
for c in betor-api betor-scrapyd betor-worker-items betor-worker-torrents betor-mongodb betor-redis flaresolverr; do
    st=$(sudo -n docker inspect --format '{{.State.Status}}' "$c" 2>/dev/null || docker inspect --format '{{.State.Status}}' "$c" 2>/dev/null || echo 'not_found')
    if [ "$st" = "running" ]; then
        emit "PASS" "Container ${c}" "running"
    else
        emit "FAIL" "Container ${c} não está rodando" "Status: ${st}"
    fi
done

# 2. BeTor API /v1/items/
betor_total=$(docker exec prowlarr curl -sf 'http://betor-api:8000/v1/items/?size=1' 2>/dev/null | python3 -c 'import sys,json; print(json.load(sys.stdin).get("total",0))' 2>/dev/null || echo 0)
if [ "${betor_total:-0}" -gt 0 ] 2>/dev/null; then
    emit "PASS" "BeTor API /v1/items/" "${betor_total} itens no MongoDB"
else
    emit "FAIL" "BeTor API /v1/items/" "Sem resposta ou catálogo vazio (${betor_total})"
fi

# 3. Scrapyd spiders
if docker exec prowlarr curl -sf 'http://betor-scrapyd:6800/listspiders.json?project=betor' 2>/dev/null | grep -q 'comando-torrents'; then
    emit "PASS" "BeTor Scrapyd lista spiders (bludv/comando-torrents)" "spiders ativos"
else
    emit "FAIL" "BeTor Scrapyd lista spiders" "Falha ao consultar scrapyd"
fi

# 4. Systemd timer
if systemctl is-active --quiet homelab-betor-sync.timer 2>/dev/null; then
    emit "PASS" "Timer systemd homelab-betor-sync ativo" "active"
else
    emit "FAIL" "Timer systemd homelab-betor-sync ativo" "inactive"
fi

# 5. betor.yml
BETOR_YML="/home/umbrel/umbrelos-scripts/compose/arr-stack/data/prowlarr/config/Definitions/Custom/betor.yml"
if grep -q 'http://betor-api:8000' "$BETOR_YML" 2>/dev/null; then
    emit "PASS" "betor.yml existe e aponta para betor-api:8000" "configurado"
else
    emit "FAIL" "betor.yml existe e aponta para betor-api:8000" "ausente ou incorreto"
fi

if [ -f "$BETOR_YML" ] && ! grep -q 'else if' "$BETOR_YML" 2>/dev/null; then
    emit "PASS" "betor.yml sem erro de template '{{ else if'" "template Cardigann válido"
else
    emit "FAIL" "betor.yml sem erro de template '{{ else if'" "sintaxe inválida detectada"
fi

# 6. Health APIs e DBs do Prowlarr/Radarr/Sonarr
arr_res=$(python3 - << 'PYEOF'
import json, sqlite3, urllib.request, xml.etree.ElementTree as ET

base = '/home/umbrel/umbrelos-scripts/compose/arr-stack/data'
def get_key(app):
    return ET.parse(f'{base}/{app}/config/config.xml').getroot().findtext('ApiKey')

errors = []
try:
    for app, port, ver in [('prowlarr', 9696, 'v1'), ('radarr', 7878, 'v3'), ('sonarr', 8989, 'v3')]:
        req = urllib.request.Request(f'http://127.0.0.1:{port}/api/{ver}/health', headers={'X-Api-Key': get_key(app)})
        with urllib.request.urlopen(req, timeout=5) as resp:
            if resp.status != 200:
                errors.append(f'{app} health HTTP {resp.status}')
            data = json.loads(resp.read().decode())
            if app == 'radarr':
                for item in data:
                    if item.get('source') == 'MovieCollectionRootFolderCheck':
                        errors.append('radarr MovieCollectionRootFolderCheck ativo')

    p_conn = sqlite3.connect(f'file:{base}/prowlarr/config/prowlarr.db?mode=ro', uri=True)
    p_betor = p_conn.execute("SELECT Enable, Priority FROM Indexers WHERE Name LIKE '%BeTor%'").fetchone()
    p_conn.close()
    if not p_betor or p_betor[0] != 1 or p_betor[1] != 1:
        errors.append(f'Prowlarr BeTor Enable/Priority invalido: {p_betor}')

    for app, expected_root in [('radarr', '/media/movies/'), ('sonarr', '/media/series/')]:
        conn = sqlite3.connect(f'file:{base}/{app}/config/{app}.db?mode=ro', uri=True)
        roots = [r[0] for r in conn.execute('SELECT Path FROM RootFolders').fetchall()]
        rpm = conn.execute("SELECT Host, RemotePath, LocalPath FROM RemotePathMappings WHERE Host='qbittorrent'").fetchall()
        hl = conn.execute("SELECT Value FROM Config WHERE Key='copyusinghardlinks'").fetchone()
        idx = conn.execute("SELECT EnableRss, Priority FROM Indexers WHERE Name LIKE '%BeTor%'").fetchone()
        conn.close()
        if expected_root not in roots:
            errors.append(f'{app} RootFolders={roots}')
        if ('qbittorrent', '/downloads/', '/media/torrents/') not in rpm:
            errors.append(f'{app} RemotePathMappings ausente')
        if not hl or hl[0] != 'True':
            errors.append(f'{app} copyusinghardlinks={hl}')
        if not idx or idx[1] != 1:
            errors.append(f'{app} BeTor Priority invalida: {idx}')
except Exception as e:
    errors.append(str(e))

print('OK' if not errors else '; '.join(errors))
PYEOF
)
if [ "$arr_res" = "OK" ]; then
    emit "PASS" "Prowlarr/Radarr/Sonarr DBs, Health e Prioridade BeTor=1" "validado"
else
    emit "FAIL" "Prowlarr/Radarr/Sonarr DBs e Health" "$arr_res"
fi

# 7. qBittorrent SavePath
if grep -q '^Session\\DefaultSavePath=/media/torrents/' /home/umbrel/umbrelos-scripts/compose/arr-stack/data/qbittorrent/config/qBittorrent/qBittorrent.conf 2>/dev/null; then
    emit "PASS" "qBittorrent DefaultSavePath=/media/torrents/" "/media/torrents/"
else
    emit "FAIL" "qBittorrent DefaultSavePath=/media/torrents/" "SavePath divergente"
fi

# 8. Device ID único e teste real de hardlink
devs=$(for c in qbittorrent radarr sonarr bazarr; do docker exec "$c" stat -c '%d' /media 2>/dev/null || echo fail; done | sort -u | wc -l)
if [ "${devs:-0}" = "1" ]; then
    emit "PASS" "Device ID único em /media (qbittorrent/radarr/sonarr/bazarr)" "mesmo filesystem"
else
    emit "FAIL" "Device ID único em /media" "contagem única=${devs}"
fi

if docker exec radarr sh -c 't=/media/torrents/.hl_ci_test_$$; m=/media/movies/.hl_ci_test_$$; touch "$t" && ln "$t" "$m" && [ "$(stat -c %i "$t")" = "$(stat -c %i "$m")" ]; rc=$?; rm -f "$t" "$m"; exit $rc' >/dev/null 2>&1; then
    emit "PASS" "Teste real de hardlink (ln) dentro do container radarr" "mesmo inode confirmado"
else
    emit "FAIL" "Teste real de hardlink (ln) dentro do container radarr" "falha ao criar hardlink"
fi

# 9. Script homelab_hardlinks.sh status
if /home/umbrel/umbrelos-scripts/scripts/utils/homelab_hardlinks.sh status >/dev/null 2>&1; then
    emit "PASS" "Script homelab_hardlinks.sh status operacional" "exit 0"
else
    emit "FAIL" "Script homelab_hardlinks.sh status operacional" "falha na execução"
fi
REMOTE_EOF
)

output=$(run_target_cmd "sudo bash -c 'echo ${remote_b64} | base64 -d | bash'")
if [ -z "$output" ]; then
    assert_fail "Execução remota da suíte BeTor/Arr/Hardlinks" "Sem retorno do servidor (SSH timeout)"
    exit 1
fi

while IFS='|' read -r status name detail; do
    [ -z "$status" ] && continue
    if [ "$status" = "PASS" ]; then
        assert_pass "$name" "$detail"
    elif [ "$status" = "FAIL" ]; then
        assert_fail "$name" "$detail"
    fi
done <<< "$output"

exit $((TESTS_FAILED > 0 ? 1 : 0))
