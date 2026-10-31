# Acesso Remoto Externo com zrok v2 (Zero-Trust & Custo Zero)

Este documento descreve a implementação, arquitetura e manutenção do túnel público seguro com o **zrok v2**, permitindo acesso a serviços internos do homelab (como o **Karteman**) a partir de qualquer rede externa ou corporativa com restrições severas de firewall (como o Fortinet do MPMS), com **custo zero** e **URL HTTPS pública e fixa**.

---

## 1. Por que zrok v2?

- **Custo Zero Real (R$ 0,00):** Sem necessidade de comprar ou renovar domínio próprio (`.com.br`, `.xyz`, etc.).
- **URL Fixa e Reservada:** O zrok v2 permite reservar um nome exclusivo (ex: `https://karteman-paulo.shares.zrok.io`), que não expira nem muda aleatoriamente após reboots.
- **Bypass de Firewalls Corporativos:** Como a conexão de saída é iniciada de dentro do homelab via TLS/HTTPS padrão (Porta 443), ela contorna bloqueios de portas e protocolos UDP/WireGuard (Tailscale).
- **Certificado SSL Válido Internacionalmente:** O tráfego HTTPS é assinado publicamente pela autoridade certificadora do `*.shares.zrok.io`, abrindo perfeitamente em qualquer navegador sem necessidade de instalar certificados adicionais.

---

## 2. Topologia e Arquitetura no Homelab

```mermaid
flowchart LR
    subgraph WAN [Internet / Rede Externa]
        Client["Dispositivo Externo\n(MPMS / 5G / Celular)"]
    end

    subgraph ZrokCloud [zrok.io Edge Global]
        ZrokEdge["karteman-paulo.shares.zrok.io\n(HTTPS Público Oficial)"]
    end

    subgraph MiniPC [umbrelOS Mini PC - 192.168.0.8]
        ZrokClient["Container Docker: zrok-karteman\n(openziti/zrok2:latest)"]
        KartemanApp["Container Docker: karteman-app\n(Rede: homelab_network:8081)"]
    end

    Client -->|HTTPS 443| ZrokEdge
    ZrokClient -.->|Túnel Outbound Seguro| ZrokEdge
    ZrokClient -->|HTTP 8081 interno| KartemanApp
```

---

## 3. Configuração e Persistência no umbrelOS

O umbrelOS possui raiz imutável via Rugix. Por esse motivo, todos os dados de autenticação e identidade do zrok são armazenados na partição persistente:

- **Diretório Persistente de Identidade:** `/data/zrok/.zrok2`
- **Volume montado no container:** `/data/zrok/.zrok2 -> /home/ziggy/.zrok2`
- **Variáveis de Ambiente:** Centralizadas em `config.env` (e `/data/config.env`):
  ```bash
  ZROK_ENABLE_TOKEN="<seu_token_aqui>"
  ZROK_UNIQUE_NAME="karteman-paulo"
  ```

---

## 4. Declaração no Docker Compose

Os 5 túneis essenciais estão organizados de forma dedicada na stack `compose/tunnels/docker-compose.yml`, conectando-se diretamente à bridge `homelab_network`:

```yaml
services:
  # 1. Painel Principal umbrelOS
  zrok-umbrel:
    image: openziti/zrok2:latest
    container_name: zrok-umbrel
    restart: unless-stopped
    user: "1000:1000"
    command: ["share", "public", "http://172.18.0.1:80", "-n", "public:umbrel-paulo", "--headless"]
    volumes:
      - /data/zrok/.zrok2:/home/ziggy/.zrok2

  # 2. Plataforma Clínica Karteman
  zrok-karteman:
    image: openziti/zrok2:latest
    container_name: zrok-karteman
    restart: unless-stopped
    user: "1000:1000"
    command: ["share", "public", "http://karteman-app:8081", "-n", "public:karteman-paulo", "--headless"]
    volumes:
      - /data/zrok/.zrok2:/home/ziggy/.zrok2

  # 3. Robô Verifica Diários Oficiais (Blindado com Basic Auth)
  zrok-diarios:
    image: openziti/zrok2:latest
    container_name: zrok-diarios
    restart: unless-stopped
    user: "1000:1000"
    command: ["share", "public", "http://verifica-diarios-app:8093", "-n", "public:diarios-paulo", "--basic-auth", "${SAMBA_USER_1:-paulo}:${SYSTEM_PASSWORD}", "--headless"]
    volumes:
      - /data/zrok/.zrok2:/home/ziggy/.zrok2

  # 4. App Investimentos Pessoais (Blindado com Basic Auth)
  zrok-investimentos:
    image: openziti/zrok2:latest
    container_name: zrok-investimentos
    restart: unless-stopped
    user: "1000:1000"
    command: ["share", "public", "http://paulo-investimentos-app:8094", "-n", "public:investimentos-paulo", "--basic-auth", "${SAMBA_USER_1:-paulo}:${SYSTEM_PASSWORD}", "--headless"]
    volumes:
      - /data/zrok/.zrok2:/home/ziggy/.zrok2

  # 5. Nextcloud (Nuvem de Arquivos e Documentos)
  zrok-cloud:
    image: openziti/zrok2:latest
    container_name: zrok-cloud
    restart: unless-stopped
    user: "1000:1000"
    command: ["share", "public", "http://172.18.0.1:8081", "-n", "public:cloud-paulo", "--headless"]
    volumes:
      - /data/zrok/.zrok2:/home/ziggy/.zrok2

  # 6. Jellyfin (Servidor de Streaming & TV)
  zrok-jellyfin:
    image: openziti/zrok2:latest
    container_name: zrok-jellyfin
    restart: unless-stopped
    user: "1000:1000"
    command: ["share", "public", "http://172.18.0.1:8096", "-n", "public:jellyfin-paulo", "--headless"]
    volumes:
      - /data/zrok/.zrok2:/home/ziggy/.zrok2
```

O script `homelab-daemon.sh` garante que a stack `compose/tunnels` inicie automaticamente em qualquer reinicialização do sistema.

---

## 5. URLs de Acesso Ativas

| Serviço | URL Pública Externa (zrok) | Apontamento Interno | Autenticação / Proteção |
| :--- | :--- | :--- | :--- |
| 🖥️ **Painel umbrelOS** | [https://umbrel-paulo.shares.zrok.io](https://umbrel-paulo.shares.zrok.io) | `http://172.18.0.1:80` | Senha Mestre do Umbrel |
| 🩺 **Clínica Karteman** | [https://karteman-paulo.shares.zrok.io](https://karteman-paulo.shares.zrok.io) | `http://karteman-app:8081` | Login da Aplicação Karteman |
| 🍿 **Jellyfin (Streaming/TV)** | [https://jellyfin-paulo.shares.zrok.io](https://jellyfin-paulo.shares.zrok.io) | `http://172.18.0.1:8096` | Login Oficial do Jellyfin |
| 📰 **Verifica Diários** | [https://diarios-paulo.shares.zrok.io](https://diarios-paulo.shares.zrok.io) | `http://verifica-diarios-app:8093` | 🔒 Usuário/Senha (`paulo:senha`) |
| 💰 **Investimentos** | [https://investimentos-paulo.shares.zrok.io](https://investimentos-paulo.shares.zrok.io) | `http://paulo-investimentos-app:8094` | 🔒 Usuário/Senha (`paulo:senha`) |
| ☁️ **Nextcloud** | [https://cloud-paulo.shares.zrok.io](https://cloud-paulo.shares.zrok.io) | `http://172.18.0.1:8081` | Login Nextcloud |



