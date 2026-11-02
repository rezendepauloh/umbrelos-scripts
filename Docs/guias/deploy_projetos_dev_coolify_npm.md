# Guia de Deploy e Organização de Projetos Dev (Coolify, Dockge, Streamlit, JS e NPM)

Este guia explica como organizar suas aplicações de desenvolvimento (Python/Streamlit, Node.js/React, APIs, etc.), evitar conflitos de portas e mapear domínios amigáveis sem portas com o **Nginx Proxy Manager (NPM)** e **AdGuard Home**.

---

## 1. Arquitetura de Redes e Portas

No nosso Homelab, todos os containers rodam integrados na rede Docker interna chamada `homelab_network`.

### A Regra de Ouro do Nginx Proxy Manager (NPM):
> **Você não precisa expor portas aleatórias no host para acessar suas aplicações pelo navegador!**

Quando um container está conectado na rede `homelab_network`:
1. O NPM pode conversar diretamente com o container usando o **nome do container** (ex: `streamlit-app`) e a **porta padrão interna** (ex: `8501`).
2. O usuário no navegador acessa apenas `http://app.pk.local` (porta 80 padrão).
3. O NPM faz o roteamento transparente para o container correto.

---

## 2. Opção 1: Usando o Coolify (PaaS Self-Hosted - Estilo Vercel/Heroku)

O **Coolify** é uma plataforma tudo-em-um para gerenciar deploys via interface web.

### Como instalar o Coolify no mini PC:
O Coolify possui um instalador oficial otimizado para rodar em cima do Docker:
```bash
curl -fsSL https://cdn.coollabs.io/coolify/install.sh | sudo bash
```
- **Painel Web:** `http://umbrel.local:8000`
- **No NPM:** Crie o proxy host:
  - **Domain Names:** `coolify.pk.local`
  - **Forward Hostname / IP:** `http://umbrel.local` (ou o IP `192.168.0.74`)
  - **Forward Port:** `8000`
  - **Websockets Support:** Ativado ✅

### Fazendo Deploy no Coolify:
1. Abra `http://coolify.pk.local`.
2. Crie um projeto novo.
3. Escolha a origem:
   - **Repositório Git** (GitHub, GitLab ou repositório Git local).
   - **Dockerfile** ou **Docker Compose**.
4. O Coolify detecta automaticamente se é **Node.js**, **Python (Streamlit)**, **Static HTML**, etc.
5. Ele cuida do build, variáveis de ambiente (`.env`) e reinicializações automáticas.

---

## 3. Opção 2: Usando o Dockge ou Docker Compose na pasta `/mnt/storage/dev`

Se você prefere criar seus próprios arquivos `docker-compose.yml` para cada projeto:

### Estrutura de Pastas Recomendada em `/mnt/storage/dev`:
```text
/mnt/storage/dev/
├── streamlit-financas/
│   ├── app.py
│   ├── requirements.txt
│   ├── Dockerfile
│   └── docker-compose.yml
├── node-dashboard/
│   ├── src/
│   ├── package.json
│   ├── Dockerfile
│   └── docker-compose.yml
└── api-python/
    ├── main.py
    └── docker-compose.yml
```

> **Dica Samba:** A pasta `/mnt/storage/dev` está compartilhada via rede como `smb://umbrel.local/Dev`. Você pode abrir essa pasta diretamente no seu editor de código (VS Code/Cursor) no Pop!_OS!

---

## 4. Modelos Prontos de Deploy

### A. Projeto Python com Streamlit
Crie o arquivo `Dockerfile` na pasta do seu projeto:
```dockerfile
FROM python:3.11-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8501

ENTRYPOINT ["streamlit", "run", "app.py", "--server.port=8501", "--server.address=0.0.0.0"]
```

E o arquivo `docker-compose.yml`:
```yaml
services:
  streamlit-financas:
    build: .
    container_name: streamlit-financas
    restart: unless-stopped
    networks:
      - homelab_network

networks:
  homelab_network:
    external: true
```

---

### B. Projeto JavaScript / Node.js (Express / Fastify / React)
Arquivo `docker-compose.yml`:
```yaml
services:
  meu-app-node:
    build: .
    container_name: meu-app-node
    restart: unless-stopped
    networks:
      - homelab_network

networks:
  homelab_network:
    external: true
```

---

## 5. Como cadastrar no Nginx Proxy Manager (NPM)

1. Acesse o NPM em `http://umbrel.local:81` (Login inicial: `admin@example.com` / `changeme`).
2. Vá em **Hosts** ➡️ **Proxy Hosts** ➡️ **Add Proxy Host**.
3. Preencha os dados da sua aplicação:

| Campo | O que preencher para o Streamlit | O que preencher para o Node.js |
| :--- | :--- | :--- |
| **Domain Names** | `financas.pk.local` | `app.pk.local` |
| **Scheme** | `http` | `http` |
| **Forward Hostname / IP** | `streamlit-financas` (nome do container!) | `meu-app-node` |
| **Forward Port** | `8501` | `3000` |
| **Block Common Exploits** | Ativado ✅ | Ativado ✅ |
| **Websockets Support** | Ativado ✅ *(obrigatório para Streamlit)* | Ativado ✅ |

4. Clique em **Save**.
5. Pronto! Agora qualquer pessoa na sua casa pode acessar `http://financas.pk.local` diretamente, sem decorar portas!
