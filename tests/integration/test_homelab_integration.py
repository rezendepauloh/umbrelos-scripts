# -*- coding: utf-8 -*-
"""
Testes de Integração: Validação de Serviços, Hardware e Túneis no Homelab umbrelOS.
Executa verificações remotas diretas no mini PC (192.168.0.8) ou no próprio host se rodado nele.
"""

import os
import subprocess
import unittest

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
TESTS_DIR = os.path.join(ROOT_DIR, 'tests')


class TestHomelabIntegration(unittest.TestCase):
    """Executa a validação de infraestrutura e conectividade no mini PC."""

    def _run_sh_test(self, script_name):
        script_path = os.path.join(os.path.dirname(__file__), script_name)
        self.assertTrue(os.path.exists(script_path), f"Script {script_name} não encontrado em {os.path.dirname(__file__)}")
        res = subprocess.run(
            ['bash', script_path],
            capture_output=True,
            text=True
        )
        self.assertEqual(
            res.returncode, 0,
            f"Falha na execução de {script_name}:\n{res.stdout}\n{res.stderr}"
        )

    def test_01_storage_and_mounts(self):
        """Valida pontos de montagem dos 3 discos físicos e ausência de duplicatas *(2)."""
        self._run_sh_test('test_storage_and_mounts.sh')

    def test_02_samba_services_and_shares(self):
        """Valida daemons Samba (smbd, nmbd, wsdd2), blindagem chattr +i e acesso aos shares."""
        self._run_sh_test('test_samba_services.sh')

    def test_03_docker_stacks_and_containers(self):
        """Valida execução saudável dos containers Docker essenciais no servidor."""
        self._run_sh_test('test_docker_stacks.sh')

    def test_04_http_endpoints_and_web_uis(self):
        """Valida disponibilidade das portas HTTP de todos os serviços locais."""
        self._run_sh_test('test_http_endpoints.sh')

    def test_05_remote_tunnels_and_tailscale(self):
        """Valida acesso aos túneis públicos zrok v2 e conectividade Tailscale."""
        self._run_sh_test('test_remote_tunnels.sh')


if __name__ == '__main__':
    unittest.main()

