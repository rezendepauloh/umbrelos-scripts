# Sincronização Periódica do BeTor (`homelab-betor-sync`)

O **BeTor** possui um agendamento automático no servidor (`192.168.0.8`) que dispara a raspagem dos trackers nacionais a cada **6 horas** via `systemd timer` (configurado pelo `homelab-daemon.sh`):

- **Timer:** `homelab-betor-sync.timer`
- **Serviço:** `homelab-betor-sync.service`
- **Ação executada:** `docker exec prowlarr curl -s -X POST -H "Content-Type: application/json" -d '{"deep": 1}' http://betor-api:8000/v1/scrape/`

---

## 1. Verificar se o Timer Rodou Certinho

Do **Pop!_OS (Desktop)**, execute:

```bash
./scripts/utils/homelab_betor_sync.sh
```

O script conecta via SSH no servidor e exibe:
1. Quando foi a **última execução** (`LAST`) e quando será a **próxima** (`NEXT`).
2. O status atual do `homelab-betor-sync.service`.
3. Os últimos logs do `journalctl` para confirmar se a chamada à API do BeTor (`betor-api:8000/v1/scrape/`) funcionou.

---

## 2. Rodar Manualmente ou Reagendar

- **Rodar agora (sem alterar o agendamento do timer):**
  ```bash
  ./scripts/utils/homelab_betor_sync.sh --run
  ```
- **Rodar agora e reagendar o próximo ciclo de 6h a partir de agora:**
  ```bash
  ./scripts/utils/homelab_betor_sync.sh --reschedule
  ```
