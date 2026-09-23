# 🚀 Guia Prático: Backup Rápido de Discos NTFS e Formatação Pós-Backup

Este guia ensina como resolver problemas de permissões ao fazer backup de HDs externos antigos (formatados em **NTFS/FAT32**), acelerar a transferência usando o `rsync` com driver nativo do kernel (sem travar o gerenciador de arquivos gráfico) e desmontar com segurança para formatar em **ext4**.

---

## 🛑 O Problema Comum com HDs NTFS no Linux
Ao tentar recortar ou mover arquivos de HDs externos NTFS pelo Cosmic Files ou Nautilus:
- Erros de "Permissão negada" acontecem porque partições NTFS não aceitam `chmod 777` clássico; as permissões do NTFS no Linux são definidas **no ato da montagem**.
- A transferência gráfica costuma ser lenta e instável (~20 a 30 MB/s) devido ao driver em espaço de usuário (FUSE) e ao cálculo visual de miniaturas.

---

## 🛠️ Passo a Passo Completo

### 1. Montagem com Permissão Total (777) e Driver Nativo do Kernel
Identifique a partição do seu HD (exemplo: `/dev/sdc1`):
```bash
lsblk
```

Desmonte e remonte em um ponto temporário com permissão total para o seu usuário (UID/GID 1000):

```bash
# A. Desmonta a partição se ela foi montada automaticamente
sudo umount /dev/sdc1 2>/dev/null || true

# B. Cria a pasta temporária de montagem
sudo mkdir -p /mnt/hd_temp

# C. Opção Recomendada (Driver nativo 'ntfs3' do kernel - ultrarrápido):
sudo mount -t ntfs3 -o uid=1000,gid=1000,iocharset=utf8,noatime,prealloc /dev/sdc1 /mnt/hd_temp

# (Alternativa caso sua distribuição use apenas o driver ntfs-3g tradicional):
# sudo mount -t ntfs-3g -o rw,uid=1000,gid=1000,dmask=000,fmask=000 /dev/sdc1 /mnt/hd_temp
```

---

### 2. Cópia Rápida e Inteligente via `rsync` (Sem Sobrescrever o que já foi copiado)
O `rsync` é 3x a 5x mais rápido que copiar pela interface gráfica. Ele verifica o destino e **apenas copia o que falta**, pulando arquivos que já foram copiados anteriormente:

```bash
# Sintaxe com aspas no destino caso contenha espaços no nome da pasta:
rsync -avhW --no-compress --info=progress2 /mnt/hd_temp/ "/mnt/storage_930/backup hd movies/"
```

- **`-W` (`--whole-file`)**: Gravação contínua direta, atingindo o limite de leitura/escrita física do HD USB (~80 a 110 MB/s).
- **`--no-compress`**: Desativa compressão (desnecessária em transferências locais, economiza CPU).
- **`--info=progress2`**: Exibe uma única barra de progresso com porcentagem geral, velocidade real e tempo restante.
- **Continuação automática**: Se você cancelar com `Ctrl + C` e rodar novamente, ele retoma exatamente de onde parou!

---

### 3. Desmontar a Pasta Temporária com Segurança
Assim que a transferência terminar 100%:

```bash
# Desmonta a pasta temporária
sudo umount /mnt/hd_temp

# (Opcional) Remove o ponto de montagem temporário
sudo rmdir /mnt/hd_temp
```

---

### 4. Formatação Definitiva do Disco para o Homelab (`ext4` com Label)
Agora que o backup dos arquivos está seguro, formate o disco físico correspondente (exemplo: `/dev/sdc`):

> ⚠️ **Atenção**: Aplique os passos no **disco inteiro** (`/dev/sdc`) e a formatação na **partição criada** (`/dev/sdc1`).

```bash
# 1. Limpa todas as assinaturas antigas da tabela de partições do disco
sudo wipefs --all --force /dev/sdc

# 2. Cria uma nova tabela de partições GPT limpa
sudo parted -s /dev/sdc mklabel gpt

# 3. Cria partição primária única ocupando 100% do disco
sudo parted -s -a optimal /dev/sdc mkpart primary ext4 0% 100%

# 4. Força o kernel a reler a nova partição imediatamente
sudo partprobe /dev/sdc

# 5. Formata a nova partição (sdc1) como ext4 com o rótulo correspondente:
# Para o HD 1:
sudo mkfs.ext4 -F -L disk1 /dev/sdc1

# (Ou use disk2 para o HD 2, ou parity1 para o HD 3 de paridade do SnapRAID)
```

---

### 5. Conferir o Novo UUID
Verifique o disco formatado e copie o UUID para preencher no `config.env`:

```bash
lsblk -f /dev/sdc
```
Pronto! O disco está 100% limpo, com journal estrito, seguro e pronto para integrar a pool do Homelab!
