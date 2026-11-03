#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Executor Unificado da Suíte de Testes — umbrelOS Scripts & Homelab
Padrão arquitetural idêntico aos projetos Pop!_OS Workstation, Espanso STI e Paulo Investimentos.

Executa:
  1. Testes Unitários: Validação de sintaxe de scripts Bash, sintaxe Compose YAML,
     regras arquiteturais e conformidade de variáveis/UUIDs sem tocar no servidor.
  2. Testes de Integração Homelab: Verificação remota (ou local) da saúde do Mini PC:
     discos/montagens físicas, Samba, containers Docker, portas HTTP e túneis zrok/Tailscale.
"""

import os
import sys
import time
import unittest

RESET = "\033[0m"
BOLD = "\033[1m"
GREEN = "\033[32m"
RED = "\033[31m"
YELLOW = "\033[33m"
CYAN = "\033[36m"
WHITE = "\033[37m"
DARK_GRAY = "\033[90m"

TESTS_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR = os.path.abspath(os.path.join(TESTS_DIR, '..'))

for d in (ROOT_DIR, TESTS_DIR):
    if d not in sys.path:
        sys.path.insert(0, d)


class ColoredTestResult(unittest.TextTestResult):
    def addSuccess(self, test):
        super().addSuccess(test)
        self.stream.write(f" {GREEN}✔ PASS{RESET} {DARK_GRAY}{test.id()}{RESET}\n")
        self.stream.flush()

    def addError(self, test, err):
        super().addError(test, err)
        self.stream.write(f" {RED}✖ ERROR{RESET} {BOLD}{test.id()}{RESET}\n")
        self.stream.flush()

    def addFailure(self, test, err):
        super().addFailure(test, err)
        self.stream.write(f" {RED}✖ FAIL{RESET} {BOLD}{test.id()}{RESET}\n")
        self.stream.flush()

    def addSkip(self, test, reason):
        super().addSkip(test, reason)
        self.stream.write(f" {YELLOW}⚡ SKIP{RESET} {DARK_GRAY}{test.id()} ({reason}){RESET}\n")
        self.stream.flush()


class ColoredTestRunner(unittest.TextTestRunner):
    resultclass = ColoredTestResult


def run_suite(suite_name, suite_dir):
    print(f"\n{CYAN}▶ Executando Suíte: {BOLD}{suite_name}{RESET} ({DARK_GRAY}{suite_dir}{RESET})")
    print(f"{DARK_GRAY}{'─' * 65}{RESET}")
    start = time.perf_counter()
    loader = unittest.TestLoader()
    suite = loader.discover(suite_dir, pattern="test_*.py")
    runner = ColoredTestRunner(verbosity=0)
    result = runner.run(suite)
    elapsed = (time.perf_counter() - start) * 1000
    print(f"{DARK_GRAY}{'─' * 65}{RESET}")
    print(
        f"⏱ Tempo: {YELLOW}{elapsed:.1f}ms{RESET} | "
        f"Rodados: {BOLD}{result.testsRun}{RESET} | "
        f"Falhas: {RED if result.failures else GREEN}{len(result.failures)}{RESET} | "
        f"Erros: {RED if result.errors else GREEN}{len(result.errors)}{RESET}"
    )
    return result


def main():
    print("")
    print(f"{CYAN}╔═══════════════════════════════════════════════════════════════╗{RESET}")
    print(f"{CYAN}║     UMBRELOS SCRIPTS & HOMELAB — SUÍTE DE TESTES AUTOMATIZADA ║{RESET}")
    print(f"{CYAN}╚═══════════════════════════════════════════════════════════════╝{RESET}")

    # Suporte a flags CLI para rodar apenas unitários ou apenas integração
    args = sys.argv[1:]
    run_unit = True
    run_integration = True

    if "--unit" in args or "-u" in args:
        run_integration = False
    elif "--integration" in args or "-i" in args:
        run_unit = False

    suites = []
    if run_unit:
        suites.append(("🔧 Unitários: Sintaxe Bash, Compose YAML & Consistência de Configurações", os.path.join(TESTS_DIR, "unit")))
    if run_integration:
        suites.append(("🚀 Integração Remota: Storage, Samba, Docker, HTTP & Túneis zrok/Tailscale", os.path.join(TESTS_DIR, "integration")))

    total_run = 0
    total_failures = 0
    total_errors = 0
    total_skipped = 0
    global_start = time.perf_counter()

    for name, s_dir in suites:
        if os.path.exists(s_dir):
            res = run_suite(name, s_dir)
            total_run += res.testsRun
            total_failures += len(res.failures)
            total_errors += len(res.errors)
            total_skipped += len(res.skipped)

    total_elapsed = time.perf_counter() - global_start
    print(f"\n{CYAN}{'═' * 65}{RESET}")
    if total_failures == 0 and total_errors == 0:
        print(f" {GREEN}{BOLD}✔ SUCESSO: Todos os testes passaram perfeitamente!{RESET}")
    else:
        print(f" {RED}{BOLD}✖ ATENÇÃO: Foram encontradas falhas nos testes!{RESET}")

    print(
        f" Total: {BOLD}{total_run}{RESET} | "
        f" Passou: {GREEN}{total_run - total_failures - total_errors}{RESET} | "
        f" Falhas: {RED if total_failures else GREEN}{total_failures}{RESET} | "
        f" Erros: {RED if total_errors else GREEN}{total_errors}{RESET} | "
        f" Ignorados: {YELLOW}{total_skipped}{RESET} | "
        f" Tempo Total: {YELLOW}{total_elapsed:.2f}s{RESET}"
    )
    print(f"{CYAN}{'═' * 65}{RESET}\n")

    sys.exit(0 if (total_failures == 0 and total_errors == 0) else 1)


if __name__ == '__main__':
    main()

