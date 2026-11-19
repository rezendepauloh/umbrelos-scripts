#!/usr/bin/env bash
# ==============================================================================
# Script: fix_nextcloud_volumes.sh
# Descrição: Reinjeta os mapeamentos do disk2 (/storage/users e /storage/shared)
#            no docker-compose.yml do Nextcloud após atualizações pela App Store
#            do umbrelOS e reinicia o app via umbreld.
# Execução: Pode ser executado tanto no Pop!_OS (conecta via SSH automaticamente)
#           quanto diretamente no Mini PC.
# ==============================================================================

set -euo pipefail

# Se não estiver no Mini PC, delega a execução via SSH automaticamente
if [ ! -d "/home/umbrel/umbrel" ]; then
    echo "Detectado ambiente externo (Pop!_OS). Conectando ao Mini PC (umbrel@192.168.0.8) via SSH..."
    exec ssh -t umbrel@192.168.0.8 "bash -s" < "$0"
fi

NC_COMPOSE="/home/umbrel/umbrel/app-data/nextcloud/docker-compose.yml"
CONFIG_ENV="/data/config.env"

if [ ! -f "$NC_COMPOSE" ]; then
    echo "ERRO: Arquivo $NC_COMPOSE não encontrado."
    exit 1
fi

# Carrega SYSTEM_PASSWORD se disponível para uso com sudo não-interativo
SUDO_CMD="sudo"
if [ -f "$CONFIG_ENV" ]; then
    # shellcheck disable=SC1090
    source "$CONFIG_ENV"
    if [ -n "${SYSTEM_PASSWORD:-}" ]; then
        SUDO_CMD="echo \"$SYSTEM_PASSWORD\" | sudo -S"
    fi
fi

echo "Verificando volumes externos no $NC_COMPOSE..."

if grep -q "/storage/users" "$NC_COMPOSE" 2>/dev/null; then
    echo "Os volumes /storage/users e /storage/shared já estão presentes no docker-compose.yml."
else
    echo "Reinjetando volumes do disk2 (/storage/users e /storage/shared)..."
    eval "$SUDO_CMD python3 -c '
p = \"$NC_COMPOSE\"
with open(p, \"r\") as f:
    txt = f.read()

target = \"      - \${APP_DATA_DIR}/hooks/pre-start:/umbrel-migration-hook:ro\"
add = \"      - /home/umbrel/umbrel/external/disk2/users:/storage/users\n      - /home/umbrel/umbrel/external/disk2/shared:/storage/shared\n\"

if target in txt:
    # Sintaxe moderna umbrelOS 2.0: injeta nos serviços web e cron (pula a 1ª ocorrência que é o db)
    parts = txt.split(target)
    if len(parts) >= 3:
        new_txt = parts[0] + target + parts[1] + add + target + parts[2] + add + target.join([\"\"] + parts[3:])
        with open(p, \"w\") as f:
            f.write(new_txt)
        print(\"Volumes injetados com sucesso (sintaxe moderna).\")
    else:
        print(\"ERRO: Estrutura inesperada no docker-compose.yml.\")
        exit(1)
elif \"\${APP_DATA_DIR}/data/nextcloud:/var/www/html\" in txt:
    # Sintaxe clássica umbrelOS 1.x
    old_line = \"      - \${APP_DATA_DIR}/data/nextcloud:/var/www/html\"
    new_txt = txt.replace(old_line, old_line + \"\n\" + add.rstrip(\"\n\"))
    with open(p, \"w\") as f:
        f.write(new_txt)
    print(\"Volumes injetados com sucesso (sintaxe clássica).\")
else:
    print(\"ERRO: Padrão de volume /var/www/html não encontrado no docker-compose.yml.\")
    exit(1)
'"
fi

echo "Reiniciando o Nextcloud via umbreld..."
eval "$SUDO_CMD umbreld client apps.restart.mutate --appId nextcloud"

echo "Validando montagem dentro do container nextcloud_web_1..."
eval "$SUDO_CMD docker exec nextcloud_web_1 ls -la /storage/users /storage/shared" >/dev/null
echo "Sucesso! /storage/users e /storage/shared estão acessíveis no Nextcloud."
