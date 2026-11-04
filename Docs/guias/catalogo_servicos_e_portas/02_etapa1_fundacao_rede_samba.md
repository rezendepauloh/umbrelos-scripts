# 🌐 Etapa 1: Fundação, Acesso Remoto, DNS e Samba

### 🔹 ETAPA 1: Fundação, Acesso Remoto e Rede Local

#### 1.1. Ativar o Tailscale (Acesso Seguro Fora de Casa)
Como você instalou o app **Tailscale** pela **App Store do umbrelOS**, ele roda em um container próprio com interface Web dedicada na porta **8240**:
1. Abra no navegador: `http://umbrel.local:8240` (ou clique diretamente no ícone do Tailscale no dashboard do Umbrel).
2. Clique em **Log In** e faça a autenticação com sua conta (Google, GitHub, Microsoft ou Apple).
3. Pronto! O mini PC aparecerá imediatamente no seu painel Tailscale (no celular ou computador remoto).

> **Dica (caso prefira via terminal no futuro):**
> Para rodar comandos CLI do Tailscale que está dentro do container do Umbrel:
> ```bash
> sudo docker exec -it tailscale_web_1 tailscale status
> ```

#### 1.2. Ativar Domínios Amigáveis no AdGuard Home (`*.pk.local`)
No painel do AdGuard Home (`http://umbrel.local:8095`):
1. Vá em **Filtros (Filters)** ➡️ **Reescritas de DNS (DNS rewrites)**.
2. Clique em **Adicionar reescrita de DNS**:
   - **Nome de Domínio:** `*.pk.local`
   - **Endereço IP:** `192.168.0.8` (IP estático fixo do mini PC).
3. Salve. Agora qualquer subdomínio `.pk.local` vai responder pelo mini PC.

##### 📱 Como configurar o DNS (`192.168.0.8`) nos aparelhos da casa:

- **Smart TV Samsung & Projetor Samsung (Tizen OS):**
  1. No controle remoto, abra **Configurações (Settings)** ➡️ **Geral (General)** ➡️ **Rede (Network)**.
  2. Vá em **Status da Rede (Network Status)** ➡️ **Configurações de IP (IP Settings)**.
  3. Mude a linha **Configuração de DNS (DNS setting)** de *Obter automaticamente* para **Digitar manualmente (Enter manually)**.
  4. No campo **Servidor DNS (DNS Server)**, digite: **`192.168.0.8`**.
  5. Pressione OK. *(Pronto! A TV/Projetor bloqueia anúncios e encontra o Jellyfin pelo domínio `jellyfin.pk.local`)*.

- **Smartphone Android (Samsung / Xiaomi / Motorola):**
  1. Vá em **Configurações** ➡️ **Conexões** ➡️ **Wi-Fi**.
  2. Toque na **engrenagem ⚙️** da sua rede Wi-Fi ➡️ **Avançado** (ou ícone de lápis para editar).
  3. Em **Definições de IP**, mude de *DHCP* para **Estático**.
  4. Preencha **DNS 1**: **`192.168.0.8`** (e DNS 2: `1.1.1.1` como reserva) e salve.

- **iPhone / iPad (iOS):**
  1. Abra **Ajustes** ➡️ **Wi-Fi** ➡️ toque no botão azul **(i)** ao lado da rede conectada.
  2. Role até **Configurar DNS** ➡️ mude para **Manual**.
  3. Remova os servidores antigos, clique em **Adicionar Servidor** e digite: **`192.168.0.8`**. Salve.

- **Computadores Windows (Notebook / Desktop):**
  1. Vá em **Configurações** ➡️ **Rede e Internet** ➡️ **Wi-Fi** (ou *Ethernet*).
  2. Clique em **Propriedades da rede** ➡️ em *Atribuição de servidor DNS*, clique em **Editar**.
  3. Mude para **Manual**, ative o **IPv4** e digite no DNS Preferencial: **`192.168.0.8`**. Salve.

- **Linux (Pop!_OS / Ubuntu):**
  *(Já integrado no script `25_limpeza_otimizacao.sh`)*:
  Nas configurações da conexão de rede: IPv4 DNS = `192.168.0.8`, IPv6 = Desativado, e comando `sudo resolvectl domain eno1 "~."`.

#### 1.3. Primeiro Login no Nginx Proxy Manager (NPM) e Liberação da Porta 80
1. Acesse `http://umbrel.local:81` (ou `http://192.168.0.8:81`).
2. Login inicial:
   - Email: `admin@example.com`
   - Senha: `changeme`
3. Troque imediatamente o e-mail de administrador e defina sua senha definitiva.
4. Cadastre os domínios locais amigáveis clicando em **Hosts** ➡️ **Proxy Hosts** ➡️ **Add Proxy Host** (consulte a tabela completa de domínios no **item 3** deste guia).
   - ⚠️ **Importante:** Para o host `umbrel.pk.local`, use o **Forward Hostname**: `127.0.0.1`, Porta: `80` e marque obrigatoriamente **Websockets Support** ✅ para carregar o dashboard em tempo real!

##### 🚀 Redirecionamento da Porta 80 no iptables (Para acessar sem digitar :8088):
O Nginx Proxy Manager escuta internamente o tráfego HTTP na porta `8088` (para não colidir com o Umbrel). Para que qualquer pessoa na sua casa digite apenas `http://dockge.pk.local` ou `http://umbrel.pk.local` **sem precisar digitar nenhuma porta**, execute este comando de redirecionamento no SSH do Umbrel:

```bash
# Redirecionar requisições da porta 80 da placa de rede física para a porta 8088 do NPM
sudo iptables -t nat -A PREROUTING -i enp1s0 -p tcp --dport 80 -j REDIRECT --to-port 8088
```

> 💡 **Para tornar a regra permanente após reinicializações via Systemd:**
> ```bash
> sudo bash -c 'cat << "EOF" > /etc/systemd/system/homelab-port80-redirect.service
> [Unit]
> Description=Redirecionamento de Porta 80 para NPM (8088)
> After=network.target docker.service
> 
> [Service]
> Type=oneshot
> RemainAfterExit=yes
> ExecStart=/sbin/iptables -t nat -A PREROUTING -i enp1s0 -p tcp --dport 80 -j REDIRECT --to-port 8088
> ExecStop=/sbin/iptables -t nat -D PREROUTING -i enp1s0 -p tcp --dport 80 -j REDIRECT --to-port 8088
> 
> [Install]
> WantedBy=multi-user.target
> EOF'
> 
> sudo systemctl daemon-reload
> sudo systemctl enable --now homelab-port80-redirect.service
> ```
> *(Caso queira desativar no futuro, basta rodar: `sudo systemctl disable --now homelab-port80-redirect.service`)*.

#### 1.4. Testar os Compartilhamentos Samba e Persistência do MergerFS
No seu Pop!_OS, utilize preferencialmente o **Nautilus** (`sudo apt install nautilus gvfs-backends`), que oferece estabilidade total na escrita SMB e gerenciamento de permissões (o Cosmic Files ainda possui instabilidades de cache/gravação em conexões de rede SMB):
Pressione `Ctrl + L` no Nautilus (ou vá em *Outros Locais* ➡️ *Conectar ao Servidor*):
- `smb://192.168.0.8/Midia` (ou `smb://umbrel.local/Midia` - Leitura e gravação livre)
- `smb://192.168.0.8/Compartilhado` (Pasta colaborativa Paulo e Kamila no disk2)
- `smb://192.168.0.8/Paulo` (Pasta privada de Paulo no disk2 - autenticação exclusiva)
- `smb://192.168.0.8/Kamila` (Pasta privada de Kamila no disk2 - autenticação exclusiva)
- `smb://192.168.0.8/Fotos` (Fotos e Vídeos originais do Immich no disk2 - Paulo e Kamila)
- Entre com o usuário `paulo` (ou `kamila`) e a senha definida. Ambos têm permissão completa de criação, edição e exclusão de arquivos.

> [!NOTE]
> **Persistência do MergerFS, Jellyfin e Stacks no Reboot (Hook Oficial do umbrelOS):**
> - Como o umbrelOS utiliza sistema de arquivos base imutável (Rugix OS), o binário do **MergerFS foi gravado na partição persistente `/data/bin/mergerfs`**.
> - Toda a orquestração de boot é gerenciada pelo **Hook Oficial de Boot do umbrelOS (`/home/umbrel/umbrel/custom-hooks/pre-start`)**, que é chamado como root pelo serviço nativo do sistema `umbrel-custom-pre-start.service`.
> - Esse hook:
>   1. Restaura o symlink do MergerFS em `/usr/bin/mergerfs`.
>   2. Aguarda até 30s os HDs USB externos do Umbrel montarem e ativa o pool `/mnt/storage`.
>   3. Espelha `/mnt/storage/media` para `/home/umbrel/umbrel/home/Downloads/media` para o Jellyfin.
>   4. Restaura os usuários `paulo` e `kamila` e reativa o Samba lendo as senhas salvas em `/data/samba/passdb.tdb`.
>   5. Sobe todas as Stacks Customizadas (Dockge, NPM, IT-Tools, Uptime Kuma, qBittorrent, Sonarr, Radarr, BeTor) logo que o Docker estiver pronto.

---
