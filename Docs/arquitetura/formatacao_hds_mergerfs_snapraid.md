# 💾 Guia Passo a Passo: Preparação e Formatação dos HDs Externos

Este guia documenta o procedimento testado e validado para preparar, particionar e formatar os HDs externos em **ext4** com tabela GPT limpa e rótulos padronizados para o **MergerFS + SnapRAID**.

---

## 🎯 Arquitetura dos Discos
- **HD 1 (Dados)**: Rótulo `disk1` (ext4) -> Montado em `/mnt/disks/disk1`
- **HD 2 (Dados)**: Rótulo `disk2` (ext4) -> Montado em `/mnt/disks/disk2`
- **HD 3 (Paridade)**: Rótulo `parity1` (ext4) -> Montado em `/mnt/disks/parity1` (Dedicado ao SnapRAID)
- **Pool Virtual**: `/mnt/storage` (MergerFS unindo `disk1` e `disk2` = **2TB** de armazenamento útil com tolerância a falhas).

---

## ⚠️ Cuidados Cruciais Antes de Começar
1. **Identifique a letra correta do disco (`/dev/sdX`)**:
   Nunca execute comandos de particionamento ou formatação em `nvme...` ou no disco onde está o seu sistema operacional!
2. Execute sempre com os discos **desmontados**.
3. Execute **um comando por linha** (evite colar blocos com comentários para que o kernel registre os nós corretamente).

---

## 📋 Passo a Passo por HD

### 1. Identificar o Disco
Conecte o HD e execute no terminal:
```bash
lsblk -o NAME,SIZE,FSTYPE,LABEL,MODEL
```
Localize a letra do disco correspondente (exemplo: `sdc`, `sdb`, `sda`).

---

### 2. Formatar o HD 1 (disk1)
Supondo que o HD seja `/dev/sdc`:

```bash
# A. Desmontar partições montadas
sudo umount /dev/sdc* 2>/dev/null || true

# B. Limpar assinaturas antigas da tabela de partição
sudo wipefs --all --force /dev/sdc

# C. Criar nova tabela de partição GPT no disco inteiro
sudo parted -s /dev/sdc mklabel gpt

# D. Criar partição primária única ocupando 100% do disco
sudo parted -s -a optimal /dev/sdc mkpart primary ext4 0% 100%

# E. Notificar o kernel para reler a nova partição
sudo partprobe /dev/sdc

# F. Formatar a partição criada (sdc1) em ext4 com rótulo disk1
sudo mkfs.ext4 -F -L disk1 /dev/sdc1
```

---

### 3. Formatar o HD 2 (disk2)
Supondo que o HD seja `/dev/sdX`:

```bash
# A. Desmontar partições montadas
sudo umount /dev/sdX* 2>/dev/null || true

# B. Limpar assinaturas antigas
sudo wipefs --all --force /dev/sdX

# C. Criar nova tabela de partição GPT
sudo parted -s /dev/sdX mklabel gpt

# D. Criar partição primária única (100%)
sudo parted -s -a optimal /dev/sdX mkpart primary ext4 0% 100%

# E. Notificar o kernel
sudo partprobe /dev/sdX

# F. Formatar em ext4 com rótulo disk2
sudo mkfs.ext4 -F -L disk2 /dev/sdX1
```

---

### 4. Formatar o HD 3 (parity1 - Paridade SnapRAID)
Supondo que o HD seja `/dev/sdY`:

```bash
# A. Desmontar partições montadas
sudo umount /dev/sdY* 2>/dev/null || true

# B. Limpar assinaturas antigas
sudo wipefs --all --force /dev/sdY

# C. Criar nova tabela de partição GPT
sudo parted -s /dev/sdY mklabel gpt

# D. Criar partição primária única (100%)
sudo parted -s -a optimal /dev/sdY mkpart primary ext4 0% 100%

# E. Notificar o kernel
sudo partprobe /dev/sdY

# F. Formatar em ext4 com rótulo parity1
sudo mkfs.ext4 -F -L parity1 /dev/sdY1
```

---

## 🔑 Coleta dos UUIDs para o `config.env`

Depois de formatar os 3 discos, execute:
```bash
lsblk -f
```

Você verá as partições com seus respectivos rótulos e UUIDs:
```text
NAME        FSTYPE LABEL   UUID
sdc
└─sdc1      ext4   disk1   fc0b5d7b-1706-4461-9e1e-9d3f61e7bab0
...
```

Copie esses valores e preencha no arquivo `config.env` no Mini PC:
```env
DISK1_UUID="fc0b5d7b-1706-4461-9e1e-9d3f61e7bab0"
DISK2_UUID="<uuid-do-disk2>"
PARITY_UUID="<uuid-do-parity1>"
```

Com isso, o script `setup_umbrelos.sh` automatizará 100% da montagem no `/etc/fstab`, a criação da pool MergerFS e a proteção diária de paridade do SnapRAID!
