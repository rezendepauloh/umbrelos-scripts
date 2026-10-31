# Guia: Cloudflare Tunnels para Acesso Remoto (Homelab umbrelOS)

Este documento documenta o uso de **Cloudflare Tunnels (Zero Trust)** para publicação segura de serviços do homelab, contornando firewalls corporativos restritivos (como o Fortinet do MPMS) sem abrir portas no roteador residencial (CGNAT/NAT) e com custo zero.

---

## 1. Por que o Cloudflare Tunnel?

- **Zero Port-Forwarding:** O túnel estabelece conexões apenas de saída (*outbound*) para a rede global da Cloudflare via porta TCP `443`.
- **Bypass de Firewalls Corporativos:** Como o tráfego utiliza certificados públicos da Cloudflare e protocolo HTTPS padrão na porta 443, firewalls com bloqueio de VPN (como FortiGate bloqueando WireGuard/Tailscale) tratam o tráfego como navegação web comum.
- **Custo:** 100% gratuito no plano Cloudflare Zero Trust Free.

---

## 2. Modalidade 1: Quick Tunnel (TryCloudflare) — Testes Rápidos sem Domínio

Ideal para testes rápidos ou compartilhamento temporário sem necessidade de cadastro de domínio:

```bash
docker run -d \
  --name cloudflare-quick-tunnel \
  --network homelab_network \
  --restart no \
  cloudflare/cloudflared:latest tunnel --url http://karteman-app:8081
```

Para descobrir a URL gerada:
```bash
docker logs cloudflare-quick-tunnel 2>&1 | grep -o 'https://.*trycloudflare.com'
```

*Nota: A cada reinício do container uma nova URL aleatória é gerada.*

---

## 3. Modalidade 2: Cloudflare Tunnel Persistente (com Domínio Fixo)

Para ter URLs fixas e permanentes (ex: `karteman.seudominio.com`, `jellyfin.seudominio.com`):

### Passo a Passo:
1. **Criar conta gratuita na Cloudflare:**
   - Acesse [dash.cloudflare.com](https://dash.cloudflare.com/) e cadastre um domínio (ex: `.com.br`, `.com` ou subdomínio delegado).
2. **Criar o Túnel no painel Zero Trust:**
   - Vá em **Zero Trust** ➡️ **Networks** ➡️ **Tunnels**.
   - Clique em **Create a Tunnel** ➡️ Selecione **Cloudflared**.
   - Dê um nome ao túnel (ex: `homelab-umbrel`).
   - Copie o token do túnel fornecido na tela (ex: `eyJh...`).
3. **Adicionar o container ao Docker Compose:**
   No arquivo `compose/management/docker-compose.yml`:
   ```yaml
     cloudflared:
       image: cloudflare/cloudflared:latest
       container_name: cloudflared
       restart: always
       command: tunnel --no-autoupdate run --token ${CLOUDFLARE_TUNNEL_TOKEN}
       networks:
         - homelab_network
   ```
4. **Cadastrar as Rotas Públicas (Public Hostnames):**
   No painel da Cloudflare:
   - Subdomínio: `karteman` | Domínio: `seudominio.com` ➡️ URL do serviço: `http://karteman-app:8081`
   - Subdomínio: `investimentos` | Domínio: `seudominio.com` ➡️ URL do serviço: `http://paulo-investimentos-app:8094`
   - Subdomínio: `jellyfin` | Domínio: `seudominio.com` ➡️ URL do serviço: `http://192.168.0.8:8096`

---

## 4. Camada de Autenticação Extra (Cloudflare Access)

Para proteger seus serviços públicos sem expor a tela de login diretamente para a internet:
1. No painel Zero Trust, vá em **Access** ➡️ **Applications**.
2. Adicione sua URL (`karteman.seudominio.com`).
3. Crie uma política permitindo apenas o seu e-mail pessoal via código OTP (One-Time PIN).
4. Ao acessar pelo trabalho, você digita seu e-mail, recebe um código de 6 dígitos e navega com total segurança.

