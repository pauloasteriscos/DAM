# DailyTalk — Rollback da API / Cloudflare Worker

- **Data:** 2026-09-01
- **Escopo:** `dailytalk-api`
- **Objetivo:** restaurar rapidamente uma versão conhecida e saudável do Worker sem alterar automaticamente o D1.

## Quando usar

```text
deploy API novo
→ regressão crítica confirmada
→ feature flag não resolve
→ rollback do Worker
```

Se o problema estiver apenas numa funcionalidade protegida por Feature Flag, preferir primeiro desligar a funcionalidade quando existir mecanismo operacional seguro para isso.

## 1. Identificar deployment/version saudável

Na pasta da API:

```powershell
cd C:\GIT\DAM\dailytalk-api

npx wrangler deployments status --config wrangler.production.jsonc
npx wrangler deployments list --config wrangler.production.jsonc
npx wrangler versions list --config wrangler.production.jsonc
```

Registar:

```text
commit Git conhecido
version ID do Worker
deployment atual
deployment alvo
hora da decisão
motivo
```

## 2. Rollback

Para voltar explicitamente a um `VERSION_ID` conhecido:

```powershell
npx wrangler rollback <VERSION_ID> `
  --config wrangler.production.jsonc
```

Se for realmente pretendido voltar à versão imediatamente anterior, Wrangler permite omitir o `VERSION_ID`, mas em produção é preferível identificar explicitamente o alvo antes da ação.

## 3. Validar imediatamente

```text
/api/health → 200
CORS esperado → correto
rota protegida sem token → rejeitada
login/refresh afetados → smoke test
secure sync afetado → smoke test
logs → sem erro crítico
```

## 4. Relação com D1

Rollback do Worker **não implica rollback automático da base D1**.

Se uma migration nova já tiver sido aplicada, verificar compatibilidade:

```text
Worker antigo + schema novo → compatível?
```

Se for compatível, manter D1.

Se não for compatível:

```text
não improvisar DROP/ALTER manual
→ seguir procedimento ROLLBACK_D1.md
```

## 5. Depois do incidente

Criar correção a partir do Git, passar novamente pelo Quality Gate e publicar um novo deployment.

Não fazer desenvolvimento permanente diretamente no estado de rollback remoto.
