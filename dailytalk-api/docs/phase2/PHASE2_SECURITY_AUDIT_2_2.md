# DailyTalk.pt — Fase 2.2 — registo de npm audit

Data de consolidação: 2026-09-09.

## Resultado

- `npm audit --omit=dev`: **0 vulnerabilidades**.
- `npm audit`: **3 vulnerabilidades high**, todas na cadeia de desenvolvimento/toolchain `wrangler -> miniflare -> sharp`.
- versões observadas no lockfile da base da Fase 2.2: `wrangler 4.127.1`, `miniflare 5.20260828.0-alpha`, `sharp 0.35.2`.
- o `npm audit` propõe `npm audit fix --force`, que alteraria `wrangler` para `4.15.2` e é explicitamente classificado pelo npm como breaking change.

## Decisão

Não executar `npm audit fix --force` nesta release. O runtime de produção não contém vulnerabilidades reportadas por `npm audit --omit=dev`; a ocorrência restante pertence ao toolchain de desenvolvimento/execução local do Worker.

A exceção não é tratada como resolução definitiva: deve permanecer rastreada e ser reavaliada quando a cadeia Wrangler/Miniflare/Sharp disponibilizar uma atualização compatível com a configuração atual. Qualquer alteração futura de Wrangler continua sujeita a `typecheck`, `test:api`, `test:security`, `test:migrations` e ao Quality Gate.

## Regra operacional

- não aceitar automaticamente `--force`;
- não reduzir a versão de Wrangler apenas para satisfazer o audit;
- manter `npm audit --omit=dev` em zero antes de publicação;
- reavaliar vulnerabilidades de devDependencies em cada atualização de toolchain.
