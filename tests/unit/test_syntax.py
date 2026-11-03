# -*- coding: utf-8 -*-
"""
Testes Unitários: Validação de sintaxe Bash (AST/Parser) e conformidade de scripts.
Executa localmente sem necessidade de conexão SSH ao mini PC.
"""

import glob
import os
import subprocess
import unittest

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
SCRIPTS_DIR = os.path.join(ROOT_DIR, 'scripts')
COMPOSE_DIR = os.path.join(ROOT_DIR, 'compose')


class TestBashSyntaxAndPermissions(unittest.TestCase):
    """Garante a integridade sintática e de execução de todos os scripts do repositório."""

    def test_01_all_bash_scripts_syntax_valid(self):
        """Valida 'bash -n' em todos os scripts Bash em scripts/ e tests/."""
        bash_files = sorted(glob.glob(os.path.join(SCRIPTS_DIR, '**', '*.sh'), recursive=True))
        bash_files.extend(sorted(glob.glob(os.path.join(ROOT_DIR, 'tests', '*.sh'))))

        self.assertGreaterEqual(len(bash_files), 10, "Deveria encontrar pelo menos 10 scripts Bash.")

        for script in bash_files:
            rel = os.path.relpath(script, ROOT_DIR)
            with self.subTest(script=rel):
                res = subprocess.run(
                    ['bash', '-n', script],
                    capture_output=True,
                    text=True
                )
                self.assertEqual(
                    res.returncode, 0,
                    f"Erro de sintaxe Bash em {rel}:\n{res.stderr}"
                )

    def test_02_all_scripts_have_shebang_and_permissions(self):
        """Verifica se os scripts possuem shebang válido (#!/usr/bin/env bash ou #!/bin/bash) e permissão de execução."""
        bash_files = sorted(glob.glob(os.path.join(SCRIPTS_DIR, '**', '*.sh'), recursive=True))
        for script in bash_files:
            rel = os.path.relpath(script, ROOT_DIR)
            with self.subTest(script=rel):
                with open(script, 'r', encoding='utf-8') as f:
                    first_line = f.readline().strip()
                self.assertTrue(
                    first_line.startswith('#!') and ('bash' in first_line or 'sh' in first_line),
                    f"{rel} deve iniciar com shebang válido (#!)"
                )
                self.assertTrue(os.access(script, os.X_OK), f"{rel} deve ter permissão de execução (+x)")

    def test_03_docker_compose_files_valid_yaml(self):
        """Verifica se todos os arquivos docker-compose.yml possuem sintaxe YAML válida."""
        compose_files = sorted(glob.glob(os.path.join(COMPOSE_DIR, '**', 'docker-compose*.yml'), recursive=True))
        self.assertGreaterEqual(len(compose_files), 4, "Devem existir ao menos 4 stacks compose.")

        try:
            import yaml
            has_yaml = True
        except ImportError:
            has_yaml = False

        for c_file in compose_files:
            rel = os.path.relpath(c_file, ROOT_DIR)
            with self.subTest(compose=rel):
                if has_yaml:
                    with open(c_file, 'r', encoding='utf-8') as f:
                        try:
                            yaml.safe_load(f)
                        except Exception as e:
                            self.fail(f"Erro de sintaxe YAML em {rel}: {e}")
                else:
                    # Fallback via python básico
                    with open(c_file, 'r', encoding='utf-8') as f:
                        lines = f.readlines()
                    self.assertGreater(len(lines), 5, f"{rel} parece vazio")


if __name__ == '__main__':
    unittest.main()

