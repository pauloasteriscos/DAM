# DailyTalk.pt API

Backend/API do projeto **DailyTalk.pt**, desenvolvido com **Cloudflare Workers** e **Hono**, no âmbito da unidade curricular **DAM - Desenvolvimento de Aplicações Móveis**.

A API suporta a aplicação Flutter mobile/Web do DailyTalk.pt, disponibilizando autenticação, preferências de utilizador, submissões de atividades, sincronização entre mobile e Web e recuperação de palavra-passe em modo protótipo/debug.

---

## Estrutura do projeto

```text
dailytalk-api/
├── src/
│   └── index.ts
├── package.json
├── package-lock.json
├── wrangler.jsonc
└── README.md
```

O ficheiro principal da API é:

```text
src/index.ts
```

---

## Ambientes de trabalho

O fluxo definido para o projeto DAM é:

```text
Desenvolvimento e testes locais:
C:\DEV\Flutter\dailytalk-api

Repositório, commit, push e deploy:
C:\GIT\DAM\dailytalk-api
```

A pasta `C:\DEV\Flutter\dailytalk-api` deve ser usada para testar localmente com Wrangler.

A pasta `C:\GIT\DAM\dailytalk-api` deve ser usada para versionar, enviar para o GitHub e publicar em produção.

---

## Instalar dependências

Na pasta da API:

```powershell
cd C:\DEV\Flutter\dailytalk-api

npm install
```

---

## Executar a API localmente

Para desenvolvimento local:

```powershell
cd C:\DEV\Flutter\dailytalk-api

npx wrangler dev --port 8787
```

A API local fica disponível em:

```text
http://127.0.0.1:8787/api
```

Endpoint de teste:

```text
http://127.0.0.1:8787/api/health
```

Também podes testar no PowerShell:

```powershell
Invoke-RestMethod http://127.0.0.1:8787/api/health
```

Resultado esperado:

```text
ok
--
True
```

---

## Integração com a app Flutter local

A app Flutter Web deve ser executada localmente de forma coerente com a API local.

Recomendado:

```powershell
cd C:\DEV\Flutter\dailytalk_mobile

flutter run -d chrome --web-hostname 127.0.0.1 --web-port 5555
```

Neste cenário:

```text
Flutter Web local: http://127.0.0.1:5555
API local:         http://127.0.0.1:8787/api
```

A aplicação Flutter possui configuração dinâmica da API:

- se estiver em `https://dailytalk.pt/web/`, usa `https://dailytalk.pt/api`;
- se estiver em `http://localhost:5555`, usa `http://localhost:8787/api`;
- se estiver em `http://127.0.0.1:5555`, usa `http://127.0.0.1:8787/api`;
- se for usado `DAILYTALK_API_BASE_URL`, esse valor tem prioridade.

---

## Variáveis locais da API

Para testes locais, deve existir um ficheiro:

```text
C:\DEV\Flutter\dailytalk-api\.dev.vars
```

Exemplo:

```env
JWT_SECRET=definir_um_valor_local_seguro
CORS_ORIGIN=http://127.0.0.1:5555
PASSWORD_RESET_DEBUG=true
JWT_EXPIRES_SECONDS=7200
PASSWORD_RESET_FROM_EMAIL=no-reply@dailytalk.pt
PASSWORD_RESET_FROM_NAME=DailyTalk.pt
```

O ficheiro `.dev.vars` é apenas local e **não deve ser enviado para o GitHub**, porque pode conter variáveis locais e segredos.

Confirma que está ignorado no `.gitignore`:

```gitignore
.dev.vars
```

---

## CORS em desenvolvimento

Quando a app Flutter Web local corre em:

```text
http://127.0.0.1:5555
```

a API local deve aceitar essa origem através de:

```env
CORS_ORIGIN=http://127.0.0.1:5555
```

Se a API local arrancar com:

```text
env.CORS_ORIGIN ("https://dailytalk.pt")
```

então o browser pode bloquear pedidos locais com erro de CORS.

O correto em desenvolvimento local é o Wrangler mostrar que está a usar variáveis do `.dev.vars`, por exemplo:

```text
Using secrets defined in .dev.vars
env.CORS_ORIGIN ("(hidden)")
env.JWT_SECRET ("(hidden)")
```

---

## Atenção ao JWT_SECRET

Se durante o login ou registo local surgir erro semelhante a:

```text
Imported HMAC key length (0)
```

significa que o `JWT_SECRET` está vazio ou não foi definido no ambiente local.

Corrigir adicionando ao `.dev.vars`:

```env
JWT_SECRET=definir_um_valor_local_seguro
```

Depois reiniciar o Wrangler:

```powershell
npx wrangler dev --port 8787
```

---

## Endpoints principais

A API disponibiliza os seguintes endpoints principais:

```text
GET  /api/health
POST /api/auth/register
POST /api/auth/login
POST /api/auth/forgot-password
POST /api/auth/reset-password
GET  /api/me
PUT  /api/me/preferences
POST /api/activities/submissions
GET  /api/activities/submissions/mine
```

---

## Autenticação

A API utiliza autenticação baseada em JWT.

Fluxo principal:

1. o utilizador cria conta ou faz login;
2. a API valida as credenciais;
3. a API gera um token JWT;
4. a app guarda o token de forma segura;
5. chamadas autenticadas enviam o token no cabeçalho `Authorization`.

Formato esperado:

```text
Authorization: Bearer <token>
```

---

## Recuperação de palavra-passe

A recuperação de palavra-passe está implementada em modo protótipo/debug.

Em desenvolvimento:

```env
PASSWORD_RESET_DEBUG=true
```

Neste modo, a API gera um código temporário, guarda o respetivo hash na base de dados D1 e devolve o código à app para permitir demonstrar o fluxo.

Em produção, este mecanismo deve ser substituído por envio real de email transacional, por exemplo com:

- Cloudflare Email Sending em plano Workers Paid;
- Resend;
- Brevo;
- SendGrid;
- serviço equivalente.

---

## Base de dados

A API utiliza **Cloudflare D1** para persistência remota.

A base suporta:

- utilizadores;
- preferências de utilizador;
- submissões de atividades;
- tokens de recuperação de palavra-passe.

Em desenvolvimento local, o Wrangler usa o modo local da D1. Por isso, um utilizador criado em produção pode não existir na base local.

Se o login local falhar por utilizador inexistente, cria uma nova conta na app local.

---

## Publicar em produção

O deploy deve ser feito a partir de:

```text
C:\GIT\DAM\dailytalk-api
```

Comandos:

```powershell
cd C:\GIT\DAM\dailytalk-api

npm install

npx wrangler deploy
```

Depois testar:

```text
https://dailytalk.pt/api/health
```

---

## Sincronização DEV → GIT

Depois de validar alterações em:

```text
C:\DEV\Flutter\dailytalk-api
```

copiar apenas os ficheiros necessários para:

```text
C:\GIT\DAM\dailytalk-api
```

Não copiar:

```text
.dev.vars
node_modules/
.wrangler/
```

Exemplo:

```powershell
cd C:\GIT\DAM

robocopy C:\DEV\Flutter\dailytalk-api\src C:\GIT\DAM\dailytalk-api\src /E

Copy-Item C:\DEV\Flutter\dailytalk-api\package.json C:\GIT\DAM\dailytalk-api\package.json -Force
Copy-Item C:\DEV\Flutter\dailytalk-api\package-lock.json C:\GIT\DAM\dailytalk-api\package-lock.json -Force
Copy-Item C:\DEV\Flutter\dailytalk-api\wrangler.jsonc C:\GIT\DAM\dailytalk-api\wrangler.jsonc -Force
Copy-Item C:\DEV\Flutter\dailytalk-api\README.md C:\GIT\DAM\dailytalk-api\README.md -Force
```

Depois:

```powershell
cd C:\GIT\DAM

git status
git add dailytalk-api/src
git add dailytalk-api/package.json
git add dailytalk-api/package-lock.json
git add dailytalk-api/wrangler.jsonc
git add dailytalk-api/README.md

git commit -m "Atualizar API DailyTalk"
git push origin main
```

---

## Testes recomendados

Antes de publicar:

```powershell
cd C:\DEV\Flutter\dailytalk-api

npx wrangler dev --port 8787
```

Testar:

```text
http://127.0.0.1:8787/api/health
```

Depois testar a app local:

```powershell
cd C:\DEV\Flutter\dailytalk_mobile

flutter run -d chrome --web-hostname 127.0.0.1 --web-port 5555
```

---

## Observações

Este backend continua em fase de protótipo funcional. Já suporta autenticação, preferências, submissões e recuperação de palavra-passe em modo debug, mas antes de uso real em produção deve ser reforçado com:

- verificação real de email;
- proteção contra abuso de pedidos;
- limitação de tentativas de login;
- autenticação multifator;
- política formal de password;
- envio real de emails transacionais;
- auditoria e logs de sessão;
- gestão mais fina de permissões por perfil.
