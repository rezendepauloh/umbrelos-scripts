# 🛠️ Manual de Recuperação de HDs e Compartilhamentos Samba

> **Objetivo:** Este guia explica como diagnosticar e resolver rapidamente desconexões acidentais de cabos USB ou oscilações de energia nos HDs externos do Mini PC (`umbrelOS`), executando a recuperação diretamente do seu **Pop!_OS (Desktop)** com apenas um comando.

---

## 1. O que acontece quando um cabo USB oscila ou é desconectado?

Quando um HD USB perde contato ou é desconectado com o servidor ligado:
1. **Erro de Leitura (I/O Error):** O kernel do Linux fecha o sistema de arquivos por segurança para evitar corrompimento (`EXT4 error -5 reading directory block`).
2. **Mudança de Letra do Dispositivo:** Ao reconectar o cabo, o Linux atribui novas letras ao disco (ex: o que era `/dev/sda1` vira `/dev/sdd1`).
3. **Ponto de Montagem Fantasma:** O diretório de montagem anterior (`/home/umbrel/umbrel/external/disk1`) fica bloqueado com montagens mortas.
4. **Sintoma Prático:** A pasta de rede no Nautilus (`smb://umbrel.local/midia`) parece vazia ou não abre.

---

## 2. Como Recuperar em 1 Clique a partir do Pop!_OS

Criamos o utilitário automatizado [`recuperar_hds_remoto.sh`](/scripts/utils/recuperar_hds_remoto.sh).

### Passo a Passo:

1. **Reconecte o cabo USB** no Mini PC ou Hub USB (caso tenha desconectado).
2. No seu **Pop!_OS**, abra o terminal na pasta do projeto e execute:

```bash
cd /home/rezendepauloh/Documentos/DevProjects/Bash/umbrelos-scripts
./scripts/utils/recuperar_hds_remoto.sh
```

---

## 3. O que o Script faz automaticamente nos bastidores:

1. **Testa a Conectividade SSH:** Garante que o Mini PC (`192.168.0.8`) está respondendo.
2. **Limpa Montagens Mortas (`umount -l`):** Desmonta os pontos em estado de I/O error (`disk1`, `disk2`, `disk3` e os bind mounts).
3. **Remonta por UUID Canônico:**
   - **`disk1` (Seagate):** `fc0b5d7b-1706-4461-9e1e-9d3f61e7bab0` ➔ Mídia (Jellyfin/Arr)
   - **`disk2` (A-DATA):** `490440f1-8f2e-41fd-bc27-00632adec790` ➔ Nextcloud e Immich Fotos
   - **`disk3` (Samsung):** `e106affb-35da-4e93-a92d-e1ef5df32bb5` ➔ Backups locais
4. **Restaura os Bind Mounts Nativos:**
   - Jellyfin: `/home/umbrel/umbrel/home/Downloads/media` ➔ `disk1/media`
   - Immich: `/home/umbrel/umbrel/app-data/immich/data/upload` ➔ `disk2/immich/upload`
5. **Reinicia Serviços:** Reinicia o Samba (`smbd`/`nmbd`) e o container `jellyfin_server_1`.
6. **Valida o Status:** Faz um teste de conexão real na share `[Midia]` e exibe a tabela de espaço dos discos.

---

## 4. Como Validar após a Execução

No seu Pop!_OS:
- Abra o gerenciador de arquivos (Nautilus).
- Clique em **Outros Locais** ➡️ **midia em umbrel.local** (ou pressione `Ctrl + L` e digite `smb://umbrel.local/midia`).
- As pastas `movies`, `music`, `series` e `torrents` abrirão instantaneamente com todos os arquivos disponíveis.

