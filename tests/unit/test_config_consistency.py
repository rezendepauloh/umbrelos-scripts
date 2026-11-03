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
            "DISK1_MOUNT",
            "DISK2_MOUNT",
            "DISK3_MOUNT"
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
        """Impede que senhas em texto claro sejam commitadas em arquivos .example."""
        with open(CONFIG_EXAMPLE, 'r', encoding='utf-8') as f:
            content = f.read()

        # Garante que não foi esquecida senha real no example
        self.assertNotIn("senha_oculta", content, "Senha real não pode constar em config.env.example!")


if __name__ == '__main__':
    unittest.main()
