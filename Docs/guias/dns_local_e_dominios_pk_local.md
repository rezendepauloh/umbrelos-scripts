# Guia de DNS Local e Domínios `*.pk.local`

Este guia explica como funciona a resolução de nomes local (`*.pk.local`) no homelab, por que dispositivos novos (como Windows ou celulares) precisam de ajuste manual e como diagnosticar/corrigir falhas usando o script automatizado.

---

## 1. Como funciona a arquitetura

1. **AdGuard Home (`192.168.0.8:53` / painel `:8095`):**
   - Atua como servidor DNS local.
   - Possui uma regra *wildcard* resolvendo `*.pk.local` → `192.168.0.8`.
2. **Nginx Proxy Manager (`192.168.0.8:81` / HTTP `:8088` / HTTPS `:8443`):**
   - Recebe as requisições dos domínios `*.pk.local` e encaminha internamente para cada serviço (Immich, Jellyfin, Dockge, Nextcloud, etc.).

> **Por que o roteador da Claro não faz isso sozinho?**
> O roteador da operadora (`192.168.0.1`) bloqueia a alteração do servidor DNS via DHCP. Por isso, qualquer dispositivo novo na rede recebe o DNS da Claro por padrão — que não conhece `*.pk.local`.

---

## 2. Script de Diagnóstico e Correção (`homelab_verificar_dns.sh`)

Para verificar rapidamente se o DNS local e o Proxy Reverso estão funcionando a partir do Pop!_OS:

```bash
./scripts/utils/homelab_verificar_dns.sh
```

### O que ele verifica:
1. **Resolução local:** Testa se `fotos.pk.local`, `jellyfin.pk.local` e `dockge.pk.local` resolvem para `192.168.0.8`.
2. **Serviços no Mini PC:** Testa a porta DNS (`53`) do AdGuard Home e o Nginx Proxy Manager (`:8088` e `:8443`).
3. **Configuração do Pop!_OS:** Confirma se a conexão ativa no `NetworkManager` está configurada com DNS `192.168.0.8`.

### Correção automática (`--fix`)
Se algum item falhar, rode com `--fix`:
```bash
./scripts/utils/homelab_verificar_dns.sh --fix
```
O modo `--fix`:
- Reaplica `ipv4.dns 192.168.0.8` e `ipv4.dns-search ~pk.local` na conexão ativa do Pop!_OS.
- Reinicia o container do AdGuard Home no Mini PC via SSH, caso necessário.

---

## 3. Configuração em Outros Dispositivos (Windows 11 / Celular)

Em dispositivos que não usam o script do Pop!_OS:
- **Opção A (DNS manual):** Nas configurações de rede (Wi-Fi/Ethernet), mude o DNS IPv4 de *Automático* para *Manual* e informe **`192.168.0.8`**.
- **Opção B (Arquivo `hosts` no Windows):** Adicione `192.168.0.8 <dominio>.pk.local` em `C:\Windows\System32\drivers\etc\hosts` (como Administrador).
- **Portas:** Como as portas padrão `80`/`443` do umbrelOS são redirecionadas ou ocupadas pelo painel, o acesso via Proxy Reverso utiliza **`:8088` (HTTP)** ou **`:8443` (HTTPS)** (ex.: `http://fotos.pk.local:8088` ou `https://fotos.pk.local:8443`).

