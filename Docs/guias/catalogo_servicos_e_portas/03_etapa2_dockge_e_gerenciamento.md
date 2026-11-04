# 🐳 Etapa 2: Dockge e Gerenciamento de Stacks

### 🔹 ETAPA 2: Dockge e Credenciais de Gerenciamento

#### 2.1. Dockge (`http://umbrel.local:5001`)
1. No primeiro acesso, crie seu usuário e senha master de administrador.
2. Você verá as stacks `management` e `arr-stack` listadas em verde como ativas.

#### 2.2. Uptime Kuma (`http://umbrel.local:3001`)
1. Crie a conta de administrador.
2. Adicione os primeiros monitores HTTP para acompanhar a saúde dos serviços:
   - Tipo: HTTP(s)
   - Nome: `umbrelOS` ➡️ `http://umbrel.local`
   - Nome: `Dockge` ➡️ `http://umbrel.local:5001`
   - Nome: `NPM` ➡️ `http://umbrel.local:81`

---
