# 💾 Backups, Retenção (7 Snapshots) e Sincronização com o Pop!_OS

Guia operacional completo da rotina de backups consolidados do Homelab (`disk3` no Mini PC + espelho incremental no Pop!_OS), explicando frequência, política de retenção, proteção contra falhas de I/O e automação leve no desktop.

---

## 1. Arquitetura e Frequência: Semanal vs. Diário

O fluxo opera em **duas pontas complementares** (Regra 3-2-1):

| Ponta | Serviço / Timer | Frequência | O que faz |
| :--- | :--- | :--- | :--- |
| **Mini PC (`192.168.0.8`)** | `homelab-backup.timer` → `/data/bin/homelab-backup-semanal.sh` | **Semanal** (`Sun *-*-* 04:00:00`) | Gera dumps de todos os bancos (`immich`, `nextcloud`, `karteman`, `home-assistant`, `jellyfin`, etc.), copia configs e dados do `disk2` para o `disk3` com `--link-dest`, aplica retenção no `disk3` e tenta enviar ao Pop!_OS se estiver ligado. |
| **Pop!_OS (`192.168.0.16`)** | `homelab-backup-sync.timer` → `homelab_auditar_e_sincronizar_backups.sh --auto` | **Diário** (`daily`, `Persistent=true`) | Roda de forma leve quando o PC é ligado, verifica via SSH se há snapshots novos e validados (`.backup_complete`) no `disk3`, puxa apenas as diferenças via `rsync` + `--link-dest` para `/mnt/storage_930/Backups_Homelab` e garante a retenção nos dois lados. |

> [!NOTE]
> **Por que o servidor às vezes dispara backup após um reboot?**
> No `umbrelOS` (Rugix OS com raiz imutável), `/var/lib/systemd/timers/` é volátil e é zerado a cada reinicialização. Como `homelab-backup.timer` possui `Persistent=true`, o `systemd` interpreta após o boot que o ciclo de domingo ficou pendente e dispara o serviço. Como os snapshots usam `--link-dest`, execuções incrementais levam apenas alguns minutos.

### Como alterar a frequência do servidor para Diário (opcional)
Se preferir gerar snapshots **diários** no `disk3` em vez de semanais:
1. Em [scripts/daemons/homelab-daemon.sh](../../scripts/daemons/homelab-daemon.sh), altere `OnCalendar=Sun *-*-* 04:00:00` para `OnCalendar=*-*-* 04:00:00` (todo dia às 04:00).
2. Reaplique o unit no servidor (`/etc/systemd/system/homelab-backup.timer`) e execute `sudo systemctl daemon-reload && sudo systemctl restart homelab-backup.timer`.

---

## 2. Política de Retenção e Staging Atômico

A variável `BACKUP_RETENTION_DAYS=7` (em `config.env` / `/data/config.env`, com suporte também a `BACKUP_RETENTION_COUNT`) define o **número máximo de snapshots `backup_*` mantidos** (7 no `disk3` e 7 no Pop!_OS — ao concluir o 8º, o mais antigo é removido).

Para evitar que quedas ou falhas de `rsync` quebrem a cadeia de hardlinks ou acumulem pastas órfãs:

- **Staging atômico (`.inprogress_backup_*`):** O backup é gravado inicialmente em `/home/umbrel/umbrel/external/disk3/backups/.inprogress_backup_<TIMESTAMP>`. Somente após todos os dumps e `rsync`s terminarem sem erro fatal é gravado o arquivo marcador `.backup_complete` e a pasta é renomeada para `backup_<TIMESTAMP>`.
- **Retomada segura:** Se um backup grande for interrompido no meio, a próxima execução usa o último `backup_*` válido como base primária de `--link-dest` e o último `.inprogress_backup_*` como base secundária de retomada, limpando o staging antigo após concluir.
- **Retenção garantida:** A limpeza dos snapshots excedentes usa ordenação cronológica determinística pelo nome (`find ... -name 'backup_*' | sort -r`) e executa **mesmo que o backup atual ou a sincronização remota falhem**.
- **Tolerância a código `24` do `rsync`:** Arquivos temporários que somem durante a cópia (como WAL/SHM de bancos SQLite ativos) registram apenas aviso e não abortam mais a rotina.

---

## 3. Automação Leve no Pop!_OS (`systemd --user timer`)

Para evitar gargalos de CPU, disco e rede durante o uso normal da workstation, a varredura e sincronização no Pop!_OS roda via `systemd --user` em prioridade mínima:

- **Units instalados:**
  - `~/.config/systemd/user/homelab-backup-sync.service` (`Nice=19`, `IOSchedulingClass=idle`, `CPUQuota=35%`, `nice -n 19 ionice -c3`, `--bwlimit=20000` KB/s)
  - `~/.config/systemd/user/homelab-backup-sync.timer` (`OnCalendar=daily`, `Persistent=true`, `RandomizedDelaySec=10min`)
- **Comportamento fora de casa:** Em modo `--auto`, se o Mini PC (`192.168.0.8`) não responder ao SSH em 5 segundos, o serviço registra o aviso no log e encerra com código `0` (sem marcar falha no systemd).
- **Log local:** `~/.local/state/homelab-backup-sync.log`.

---

## 4. Comandos Úteis de Operação e Diagnóstico

### No Pop!_OS (Desktop)
```bash
# Auditar bancos, fotos e snapshots pendentes sem transferir dados
./scripts/utils/homelab_auditar_e_sincronizar_backups.sh --check

# Forçar sincronização manual imediata (com progresso)
./scripts/utils/homelab_auditar_e_sincronizar_backups.sh --sync

# Verificar agendamento e última execução do timer leve
systemctl --user list-timers homelab-backup-sync.timer --all
systemctl --user status homelab-backup-sync.service
tail -n 50 ~/.local/state/homelab-backup-sync.log
```

### No Mini PC (`ssh umbrel@192.168.0.8`)
```bash
# Ver log da rotina consolidada no servidor
source /data/config.env && echo "$SYSTEM_PASSWORD" | sudo -S tail -n 80 /data/homelab-backup.log

# Disparar um snapshot completo manualmente em background via systemd
source /data/config.env && echo "$SYSTEM_PASSWORD" | sudo -S systemctl start --no-block homelab-backup.service

# Acompanhar execução e status do timer no servidor
systemctl status homelab-backup.timer homelab-backup.service
```

---

## 5. Diagnóstico Rápido: Erros de I/O no `disk3` (`ext4` read-only)

O `disk3` (`Samsung S2 Portable`, `UUID=e106affb-35da-4e93-a92d-e1ef5df32bb5`) limita a gravação a `--bwlimit=15000` (15 MB/s) para não sobrecarregar a ponte USB 2.0. Caso ocorra queda de energia ou desconexão USB e o `disk3` entre em `Input/output error` / `read-only`:

```bash
# No Mini PC (ssh umbrel@192.168.0.8)
source /data/config.env
echo "$SYSTEM_PASSWORD" | sudo -S bash -c '
  umount /home/umbrel/umbrel/external/disk3
  e2fsck -p -f /dev/sdc1
  mount UUID=e106affb-35da-4e93-a92d-e1ef5df32bb5 /home/umbrel/umbrel/external/disk3
'
```

> [!TIP]
> Se o `disk3` voltar a apresentar erros `DID_ERROR` no `dmesg` sob escrita contínua, conecte-o diretamente a uma porta USB 3.0 traseira do Mini PC (evitando hubs USB 2.0 sem alimentação externa).

