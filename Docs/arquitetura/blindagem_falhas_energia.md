# 🛡️ Blindagem Contra Falhas de Energia e Proteção de Dados (Sem Nobreak)

Este documento detalha as configurações implementadas no **umbrelos-scripts** para proteger o Mini PC Blackview MP100 Pro, seus HDs externos e os bancos de dados do Immich e Nextcloud contra corrupção em casos de corte repentino de energia (*dirty shutdown*).

---

## 🛑 O Desafio de Rodar Sem Nobreak

Quando a energia acaba repentinamente:
1. **Dados em RAM (Buffer de Escrita)**: O Linux costuma manter arquivos recém-escritos na memória RAM por até 30 segundos antes de gravar fisicamente no disco. Se a energia cai nesse meio tempo, esses dados se perdem.
2. **Inconsistência em Metadados**: Se a cabeça do HD estiver no meio de uma gravação quando a luz apagar, a partição pode ficar marcada como "suja" (*dirty*), arriscando que novos dados sobrescrevam setores válidos.
3. **Bancos de Dados**: O PostgreSQL (Immich) e o MariaDB (Nextcloud) podem sofrer corrupção de tabelas se as transações de disco forem interrompidas sem um *Write-Ahead Log* consistente.

---

## 🛠️ Camadas de Proteção Implementadas na Suíte

### 1. Sistema de Arquivos com Journaling Estrito (`/etc/fstab`)
Nas opções de montagem de cada HD externo em `config.env` e no script `02_storage_setup.sh`:
- **`commit=5`**: Força o kernel a sincronizar o cache de memória com o disco físico a cada **5 segundos** (reduzindo a janela de risco em 85%).
- **`errors=remount-ro`**: Se uma falha grave de I/O ocorrer na queda de luz, o Linux trava o disco imediatamente como **somente-leitura** (*read-only*), impedindo qualquer sobrescrita destrutiva em blocos de dados sadios.
- **`noatime`**: Evita gravações contínuas de data/hora de acesso a cada leitura de arquivo, poupando a mecânica dos HDs.

---

### 2. Parâmetros de Kernel para Escrita Rápida de Buffer (`sysctl`)
No script `01_system_prep.sh`, afinamos o comportamento de memória suja (*dirty memory*) do Linux:
- `vm.dirty_background_ratio = 5`
- `vm.dirty_ratio = 10`
- `vm.dirty_writeback_centisecs = 500` (descarrega buffers a cada 5 segundos)
- `vm.dirty_expire_centisecs = 1500` (nenhum dado fica mais de 15 segundos em RAM)

Isso garante que grandes transferências de fotos ou downloads sejam persistidos quase em tempo real no NVMe e nos HDs.

---

### 3. Proteção do Systemd Journald no NVMe
No arquivo `/etc/systemd/journald.conf.d/99-homelab-crash-resilience.conf`:
- `Storage=persistent`
- `SyncIntervalSec=1m`: O log do sistema é sincronizado a cada minuto para que você nunca perca o histórico de boot após uma queda.

---

### 4. Rotina Automática Diária de Backup dos Bancos (`scripts/06_backup_databases.sh`)
O antídoto definitivo para qualquer queda catastrófica é ter o dump leve do banco salvo:
- Todo dia às **04:00 da manhã**, o script roda automaticamente via cron:
  - Localiza o container Postgres do **Immich** e executa `pg_dumpall | gzip`;
  - Localiza o container de banco do **Nextcloud** e executa `mariadb-dump / mysqldump | gzip`;
  - Salva em `/mnt/storage/backups/databases/`;
  - Mantém histórico rotativo de **7 dias** apagando dumps mais antigos;
  - Executa `sync` para forçar a gravação no disco.

Se por acaso um banco de dados quebrar após uma tempestade ou queda de luz, basta restaurar o arquivo `.sql.gz` da madrugada anterior em menos de 2 minutos!

---

## 🔌 Dica Opcional e Barata para o Futuro: Mini Nobreak DC
Se mais para frente você quiser blindar a conexão de rede da sua casa gastando muito pouco (na faixa de R$ 150 a R$ 250):
- Um **Mini Nobreak DC de 12V** (ex: Intelbras ou similares) alimenta apenas o seu modem/roteador Wi-Fi da operadora por até 2 a 4 horas.
- Ele evita que a sua rede local caia durante oscilações rápidas de energia e mantém a internet de pé para celulares e notebooks.
