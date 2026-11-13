# -*- coding: utf-8 -*-
"""
Testes Unitários: Consistência Arquitetural, Variáveis de Configuração e Templates.
Valida o template config.env.example, UUIDs dos discos e ausência de senhas expostas.
"""

import os
import re
import unittest

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
CONFIG_EXAMPLE = os.path.join(ROOT_DIR, 'config.env.example')
AGENTS_MD = os.path.join(ROOT_DIR, 'AGENTS.md')


class TestConfigAndArchitectureConsistency(unittest.TestCase):
    """Garante coerência nas configurações e conformidade com AGENTS.md."""

    def test_01_config_example_contains_all_required_variables(self):
        """Verifica se config.env.example define as variáveis obrigatórias da infraestrutura."""
        self.assertTrue(os.path.exists(CONFIG_EXAMPLE), "config.env.example deve existir na raiz do repositório.")
        with open(CONFIG_EXAMPLE, 'r', encoding='utf-8') as f:
            content = f.read()

        required_vars = [
            "SYSTEM_PASSWORD",
            "DISK1_UUID",
            "DISK2_UUID",
            "DISK3_UUID",
            "STATIC_IP",
            "SYSTEM_USER",
            "SAMBA_USER_1",
            "SAMBA_USER_2",
            "KAMILA_PASSWORD",
            "DISK1_MOUNT",
            "DISK2_MOUNT",
            "DISK3_MOUNT",
            "TIMEZONE",
            "DOCKGE_PORT",
            "DOZZLE_PORT",
            "UPTIME_KUMA_PORT",
            "IT_TOOLS_PORT",
            "SYNCTHING_WEB_PORT",
            "HOMELAB_DOMAIN",
            "NPM_WEB_PORT",
            "NPM_HTTP_PORT",
            "NPM_HTTPS_PORT",
            "BETOR_MONGO_USER",
            "BETOR_MONGO_PASSWORD",
            "STORAGE_BASE_DIR",
            "POPOS_HOST"
        ]

        for var in required_vars:
            with self.subTest(variable=var):
                self.assertIn(var, content, f"Variável obrigatória '{var}' ausente em config.env.example")

    def test_02_agents_md_has_canonical_uuids(self):
        """Garante que o AGENTS.md documenta os UUIDs de hardware reais dos 3 discos físicos."""
        self.assertTrue(os.path.exists(AGENTS_MD), "AGENTS.md deve existir.")
        with open(AGENTS_MD, 'r', encoding='utf-8') as f:
            content = f.read()

        expected_uuids = [
            "fc0b5d7b-1706-4461-9e1e-9d3f61e7bab0",  # disk1
            "490440f1-8f2e-41fd-bc27-00632adec790",  # disk2
            "e106affb-35da-4e93-a92d-e1ef5df32bb5"   # disk3
        ]

        for uuid in expected_uuids:
            with self.subTest(uuid=uuid):
                self.assertIn(uuid, content, f"UUID {uuid} deve estar documentado na tabela de armazenamento do AGENTS.md")

    def test_03_no_exposed_passwords_in_tracked_examples(self):
        """Impede que senhas em texto claro ou segredos reais sejam commitados em QUALQUER arquivo rastreado pelo Git."""
        import subprocess
        with open(CONFIG_EXAMPLE, 'r', encoding='utf-8') as f:
            example_content = f.read()

        # Garante que não foi esquecida senha real no example
        self.assertNotIn("senha_root", example_content.replace('SYSTEM_PASSWORD="senha_root"', ""))
        self.assertNotIn("senha_kamila", example_content.replace('KAMILA_PASSWORD="senha_kamila"', ""))

        # Padrões proibidos de credenciais hardcoded que nunca devem existir no código
        forbidden_literals = [
            "M!n0t@ur0",
            "moneyprintergobrrr",
            "Paulo#Homelab2026",
            "Kamila#Homelab2026",
            "mLcLDdt5qqMxlq3wv8Din3UD44bTZHzRFhIktw38kWg=",
            "16:158FBE422B1A9D996073BE2B9EC38852C70CE12362CA016F8F6859C426",
        ]

        # Extrair segredos reais de config.env (se existir localmente)
        config_env_path = os.path.join(ROOT_DIR, 'config.env')
        real_secrets = {}
        if os.path.exists(config_env_path):
            with open(config_env_path, 'r', encoding='utf-8') as f:
                env_content = f.read()
            for match in re.finditer(r'^(SYSTEM_PASSWORD|KAMILA_PASSWORD|ZROK_ENABLE_TOKEN|BETOR_MONGO_PASSWORD)=["\']?([^"\'\n]+)["\']?', env_content, re.M):
                var_name, val = match.group(1), match.group(2).strip()
                # Ignora placeholders genéricos ou nome curto de serviço
                if val and val not in ("senha_root", "senha_kamila", "seu_token_aqui", "senha_segura_betor", "betor"):
                    real_secrets[var_name] = val

        # Listar todos os arquivos rastreados pelo Git
        res = subprocess.run(['git', 'ls-files'], cwd=ROOT_DIR, capture_output=True, text=True)
        tracked_files = [line.strip() for line in res.stdout.splitlines() if line.strip()]

        for rel_path in tracked_files:
            # Ignorar este próprio arquivo de teste ao checar a lista de strings proibidas
            if rel_path == "tests/unit/test_config_consistency.py":
                continue
            abs_path = os.path.join(ROOT_DIR, rel_path)
            if not os.path.isfile(abs_path):
                continue
            try:
                with open(abs_path, 'r', encoding='utf-8') as f:
                    file_text = f.read()
            except Exception:
                continue

            for lit in forbidden_literals:
                self.assertNotIn(lit, file_text, f"Credencial hardcoded proibida ('{lit[:6]}...') detectada em {rel_path}!")

            for secret_name, secret_val in real_secrets.items():
                self.assertNotIn(
                    secret_val, file_text,
                    f"Vazamento de segredo real ({secret_name}) de config.env detectado no arquivo rastreado {rel_path}!"
                )

    def test_04_tunnels_compose_has_staggered_delays_and_backoff(self):
        """Garante que compose/tunnels/docker-compose.yml possui proteção contra rate limits do zrok."""
        tunnels_compose = os.path.join(ROOT_DIR, 'compose', 'tunnels', 'docker-compose.yml')
        self.assertTrue(os.path.exists(tunnels_compose), "compose/tunnels/docker-compose.yml deve existir.")

        with open(tunnels_compose, 'r', encoding='utf-8') as f:
            content = f.read()

        # Verifica se todos os serviços usam restart com backoff finito em vez de looping infinito
        self.assertIn("restart: on-failure:5", content, "Túneis zrok devem usar 'restart: on-failure:5'.")
        self.assertNotIn("restart: unless-stopped", content, "Túneis zrok não devem usar 'unless-stopped' para evitar looping de HTTP 429.")

        # Verifica se há escalonamento com sleeps no command/entrypoint para proteger contra rate limit (HTTP 429)
        self.assertIn("sleep 20", content, "Túneis devem possuir escalonamento de pelo menos 20s.")
        self.assertIn("sleep 40", content, "Túneis devem possuir escalonamento de pelo menos 40s.")
        self.assertIn("sleep 60", content, "Túneis devem possuir escalonamento de pelo menos 60s.")
        self.assertIn("sleep 80", content, "Túneis devem possuir escalonamento de pelo menos 80s.")

    def test_05_unified_env_architecture_and_no_legacy_dotenv_generation(self):
        """Garante que a arquitetura unificada de variáveis (.env symlink para config.env) está em vigor."""
        setup_04 = os.path.join(ROOT_DIR, 'scripts', 'setup', '04_docker_custom_stacks.sh')
        daemon_sh = os.path.join(ROOT_DIR, 'scripts', 'daemons', 'homelab-daemon.sh')
        update_stacks_sh = os.path.join(ROOT_DIR, 'scripts', 'utils', 'homelab_atualizar_stacks.sh')

        self.assertTrue(os.path.exists(setup_04), "04_docker_custom_stacks.sh deve existir.")
        self.assertTrue(os.path.exists(daemon_sh), "homelab-daemon.sh deve existir.")
        self.assertTrue(os.path.exists(update_stacks_sh), "homelab_atualizar_stacks.sh deve existir.")

        # 1. 04_docker_custom_stacks.sh NÃO deve gerar .env estático hardcoded
        with open(setup_04, 'r', encoding='utf-8') as f:
            setup_04_content = f.read()
        self.assertNotIn('cat <<EOF > "$ENV_FILE"', setup_04_content, "04_docker_custom_stacks.sh não deve gerar .env paralelo hardcoded.")
        self.assertIn('ln -sfn "${ENV_FILE}" "${SCRIPT_DIR}/.env"', setup_04_content, "04_docker_custom_stacks.sh deve criar symlink para o config canônico.")

        # 2. homelab-daemon.sh deve usar ENV_FILE unificado
        with open(daemon_sh, 'r', encoding='utf-8') as f:
            daemon_content = f.read()
        self.assertIn('docker compose --env-file "$ENV_FILE" up -d', daemon_content, "homelab-daemon.sh deve invocar docker compose com --env-file $ENV_FILE.")
        self.assertNotIn('--env-file /home/umbrel/umbrelos-scripts/.env', daemon_content, "homelab-daemon.sh não deve apontar para o antigo .env estático.")

        # 3. homelab_atualizar_stacks.sh deve usar ENV_FILE unificado
        with open(update_stacks_sh, 'r', encoding='utf-8') as f:
            update_content = f.read()
        self.assertIn('docker compose --env-file "$ENV_FILE"', update_content, "homelab_atualizar_stacks.sh deve usar ENV_FILE.")
        self.assertIn('ln -sfn "$ENV_FILE"', update_content, "homelab_atualizar_stacks.sh deve garantir symlink de .env.")

    def test_06_security_hardening_fail_closed_and_permissions(self):
        """Valida regras de segurança: Fail-Closed no ttyd e zrok, bind local em proxies internos e sanitização CLI."""
        # 1. ttyd Fail-Closed
        mgmt_compose = os.path.join(ROOT_DIR, 'compose', 'management', 'docker-compose.yml')
        with open(mgmt_compose, 'r', encoding='utf-8') as f:
            mgmt_content = f.read()
        self.assertIn('SYSTEM_PASSWORD=${SYSTEM_PASSWORD:?', mgmt_content, "ttyd deve exigir SYSTEM_PASSWORD via :? no Compose.")
        self.assertIn('exit 1', mgmt_content, "ttyd deve abortar com exit 1 caso credenciais estejam vazias (Fail-Closed).")
        self.assertNotIn('CRED_OPT=""', mgmt_content, "ttyd não deve permitir inicialização sem credenciais (Fail-Open).")

        # 2. Túneis zrok Fail-Closed e ausência de zrok-umbrel
        tunnels_compose = os.path.join(ROOT_DIR, 'compose', 'tunnels', 'docker-compose.yml')
        with open(tunnels_compose, 'r', encoding='utf-8') as f:
            tunnels_content = f.read()
        self.assertNotIn('zrok-umbrel', tunnels_content, "O painel umbrelOS não deve ser exposto via zrok-umbrel.")
        self.assertIn('SYSTEM_PASSWORD=${SYSTEM_PASSWORD:?', tunnels_content, "Túneis com Basic Auth devem exigir SYSTEM_PASSWORD.")
        self.assertIn('KAMILA_PASSWORD=${KAMILA_PASSWORD:?', tunnels_content, "Túneis com Basic Auth devem exigir KAMILA_PASSWORD.")

        # 3. Bind localhost para serviços internos (FlareSolverr e BeTor API) e senha obrigatória no MongoDB
        arr_compose = os.path.join(ROOT_DIR, 'compose', 'arr-stack', 'docker-compose.yml')
        with open(arr_compose, 'r', encoding='utf-8') as f:
            arr_content = f.read()
        self.assertIn('127.0.0.1:8191:8191', arr_content, "FlareSolverr deve fazer bind apenas em 127.0.0.1.")

        betor_compose = os.path.join(ROOT_DIR, 'compose', 'betor', 'docker-compose.yml')
        with open(betor_compose, 'r', encoding='utf-8') as f:
            betor_content = f.read()
        self.assertIn('127.0.0.1:8005:8000', betor_content, "BeTor API deve fazer bind apenas em 127.0.0.1.")
        self.assertNotIn('BETOR_MONGO_PASSWORD:-betor', betor_content, "BeTor não deve ter senha fallback fraca hardcoded.")

        # 4. Sanitização contra Command Injection em homelab_restaurar_servicos.sh
        restore_sh = os.path.join(ROOT_DIR, 'scripts', 'utils', 'homelab_restaurar_servicos.sh')
        with open(restore_sh, 'r', encoding='utf-8') as f:
            restore_content = f.read()
        self.assertIn('^[a-zA-Z0-9_-]+$', restore_content, "homelab_restaurar_servicos.sh deve validar argumentos com regex estrita.")
        self.assertIn('bash -s -- "$mode" "$arg"', restore_content, "homelab_restaurar_servicos.sh deve passar argumentos posicionais seguros.")


if __name__ == '__main__':
    unittest.main()
