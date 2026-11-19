# Guia: Restauração dos Volumes Externos do Nextcloud após Updates

## Por que o erro acontece?

No nosso homelab, as pastas **`Compartilhado`** (`/storage/shared`) e **`Meus Arquivos`** (`/storage/users`) do Nextcloud são mapeadas diretamente para o **`disk2`** (`/home/umbrel/umbrel/external/disk2/`).

Quando o **Nextcloud é atualizado pela App Store do umbrelOS**, o Umbrel sobrescreve o arquivo `/home/umbrel/umbrel/app-data/nextcloud/docker-compose.yml` com o template padrão da loja, removendo os volumes customizados `/storage/users` e `/storage/shared`.

Como resultado, o cliente Nextcloud (Pop!_OS / Desktop / Mobile) passa a exibir:
- `Compartilhado: A pasta não está acessível no servidor.`
- `Meus Arquivos: A pasta não está acessível no servidor.`

> **Importante:** Os dados no `disk2` não são perdidos; apenas o mapeamento dentro do container `nextcloud_web_1` foi removido pelo update.

---

## Como corrigir rapidamente

Execute o script utilitário [fix_nextcloud_volumes.sh](scripts/utils/fix_nextcloud_volumes.sh) diretamente **no Pop!_OS** (ele detecta o ambiente e conecta via SSH automaticamente) ou **no Mini PC**:

```bash
./scripts/utils/fix_nextcloud_volumes.sh
```

### O que o script faz:
1. Verifica se `/storage/users` e `/storage/shared` estão ausentes no `/home/umbrel/umbrel/app-data/nextcloud/docker-compose.yml`.
2. Reinjeta os dois volumes nos serviços `web` e `cron` (suportando tanto a sintaxe moderna do umbrelOS 2.0 quanto a clássica do 1.x).
3. Reinicia o app Nextcloud de forma limpa via `umbreld client apps.restart.mutate --appId nextcloud`.
4. Valida que `/storage/users` e `/storage/shared` estão montados e acessíveis dentro do container `nextcloud_web_1`.

---

## Prevenção automática no boot

O daemon `/data/bin/homelab-daemon.sh` também verifica e reinjeta esses volumes automaticamente durante a inicialização do servidor. Caso o problema ocorra imediatamente após um update da App Store sem reiniciar o Mini PC, basta rodar o comando acima.
