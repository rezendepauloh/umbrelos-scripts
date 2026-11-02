# 🔒 Guia de Instalação do Certificado SSL Local (Homelab Root CA)

Este guia ensina como instalar o certificado raiz **Homelab Root CA** em todos os seus aparelhos (Android, iOS, iPadOS, Windows e Pop!_OS) para eliminar o aviso *"Não seguro"* e ativar o **cadeado verde seguro 🔒** nos acessos a:
- `https://*.pk.local` (`jellyfin.pk.local`, `nuvem.pk.local`, `dockge.pk.local`, etc.)
- `https://192.168.0.8` (Painel do umbrelOS)
- `https://umbrel.local`

---

## 📥 Onde está o arquivo do Certificado?

O arquivo raiz que precisa ser instalado nos aparelhos chama-se **`homelab-ca.crt`**.
Ele está localizado em:
- **No Pop!_OS:** `/home/rezendepauloh/Documentos/DevProjects/Bash/umbrelos-scripts/config/ssl/homelab-ca.crt`
- **Via Rede Samba:** Você pode copiar esse arquivo para a pasta `[Compartilhado]` ou `[Paulo]` para baixá-lo em qualquer dispositivo!

---

## 📱 1. Celulares e Tablets Samsung (Android)

1. Envie ou baixe o arquivo `homelab-ca.crt` para o seu aparelho (pode enviar pelo WhatsApp, Telegram ou baixar da pasta de rede).
2. Abra as **Configurações** do celular/tablet Samsung.
3. Vá em: **Segurança e privacidade** (ou *Biometria e segurança*).
4. Role até o fim e toque em **Mais configurações de segurança** (ou *Outras configurações de segurança*).
5. Toque em **Instalar do armazenamento do dispositivo** (ou *Instalar a partir do armazenamento*).
6. Escolha a opção **Certificado CA**.
   - *O sistema exibirá um aviso de segurança dizendo "Sua privacidade pode estar em risco...". Toque em **Instalar mesmo assim**.*
7. Selecione o arquivo `homelab-ca.crt` que você baixou.
8. Digite o PIN/Biometria do aparelho para confirmar.

> ✅ **Pronto!** Ao abrir o Chrome ou Samsung Internet e navegar em `https://nuvem.pk.local` ou `https://jellyfin.pk.local`, o cadeado verde aparecerá sem aviso de perigo.

---

## 🍏 2. iPhone e iPad (iOS / iPadOS)

1. Envie o arquivo `homelab-ca.crt` para o aparelho via **AirDrop**, ou baixe-o pelo navegador Safari.
2. O iOS exibirá uma mensagem: *"Perfil Baixado"*.
3. Vá em **Ajustes** ➡️ logo no topo clique em **Perfil Baixado** e toque em **Instalar** (digite a senha do iPad/iPhone).
4. **Passo Fundamental no iOS (Confiança Total):**
   - No app **Ajustes**, vá em: **Geral** ➡️ **Sobre** ➡️ role até o fim e toque em **Ajustes de Confiança de Certificados**.
   - Na seção *"Habilitar confiança total para certificados raiz"*, localize o **Homelab Root CA** e **ative a chavinha**.
   - Confirme no pop-up.

> ✅ **Pronto!** O Safari passará a reconhecer todos os domínios locais com HTTPS e cadeado seguro.

---

## 💻 3. Computador Windows (PC da Kamila)

1. Copie o arquivo `homelab-ca.crt` para o Windows (pode abrir o compartilhamento de rede `\\192.168.0.8\Compartilhado`).
2. Dê **duplo clique** no arquivo `homelab-ca.crt`.
3. Na janelinha que abrir, clique em **Instalar Certificado...**.
4. Escolha:
   - Local do Repositório: **Máquina Local** (ou *Usuário Atual*) ➡️ Avançar.
   - Marque: **Colocar todos os certificados no repositório a seguir** e clique em **Procurar...**.
   - Selecione a pasta: **Autoridades de Certificação Raiz Confiáveis** (*Trusted Root Certification Authorities*).
   - Clique em **OK** ➡️ **Avançar** ➡️ **Concluir**.
5. Se aparecer um aviso de segurança perguntando se deseja confiar na CA, clique em **Sim**.

> ✅ **Pronto!** Chrome, Edge e Firefox no Windows exibirão o cadeado verde imediatamente.

---

## 🐧 4. Pop!_OS (Desktop de Trabalho)

*(Já instalado e configurado automaticamente!)*
Caso queira reinstalar manualmente no futuro:
```bash
sudo cp config/ssl/homelab-ca.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates
certutil -d sql:$HOME/.pki/nssdb -A -t "C,," -n "Homelab Root CA" -i config/ssl/homelab-ca.crt
```

---

## 🔍 Como Testar

Abra o navegador no seu computador ou dispositivo configurado e acesse:
- 🎬 `https://jellyfin.pk.local`
- ☁️ `https://nuvem.pk.local`
- 🐳 `https://dockge.pk.local`
- 🖥️ `https://192.168.0.8`

O cadeado estará fechado e verde, e a conexão 100% segura e criptografada!

