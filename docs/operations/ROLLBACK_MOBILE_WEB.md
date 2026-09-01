# DailyTalk — Rollback Mobile e Web

- **Data:** 2026-09-01
- **Escopo:** Flutter Android/iOS/Web

## 1. Flutter Web / Cloudflare Pages

Um deployment de produção do Pages pode ser revertido para um deployment de produção anterior que tenha sido construído com sucesso.

Procedimento operacional:

```text
Cloudflare Dashboard
→ Workers & Pages
→ projeto Pages
→ Deployments
→ deployment de produção saudável
→ menu (...)
→ Rollback to this deployment
```

Depois validar:

```text
landing page
/web
login
modo teste
fluxo principal afetado
chamadas para /api
```

Rollback do Pages não reverte API nem D1.

## 2. Android/iOS

Para aplicações instaladas, "rollback" não deve significar instalar silenciosamente um pacote antigo sobre um novo.

A estratégia é:

```text
identificar commit saudável
→ criar novo build a partir desse código
→ incrementar versão/build number
→ publicar como nova versão corretiva
```

No Android, uma versão distribuída normalmente precisa de `versionCode` superior à versão já instalada/publicada.

Portanto:

```text
código funcionalmente anterior
+
versionCode novo
=
release corretiva
```

## 3. Dados locais

Não apagar SQLite como procedimento normal de recuperação.

Uma release corretiva precisa respeitar:

```text
schema SQLite existente
dados do utilizador
fila de sync
clientSubmissionId
estado de progresso
```

Se o problema for provocado por uma migration local:

```text
não instruir uninstall
→ criar migration corretiva
→ testar upgrade real
```

## 4. Feature Flags

Quando a regressão estiver atrás de uma flag:

```text
Flag OFF
→ funcionalidade não aparece
```

Se a flag atual for exclusivamente compile-time, é necessário gerar novo build com a configuração segura.

## 5. Compatibilidade

Antes de publicar uma release corretiva móvel, verificar:

```text
app corrigida ↔ API atual
app corrigida ↔ schema D1 atual
app corrigida ↔ SQLite já migrada
```
