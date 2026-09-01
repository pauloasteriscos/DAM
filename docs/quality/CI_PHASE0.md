# DailyTalk — Fase 0 — CI automatizada

- **Estado:** Preparada para validação no GitHub Actions
- **Data:** 2026-09-01

## Objetivo

Transformar os gates manuais consolidados na Fase 0 em verificações automáticas no GitHub.

## Workflow

Ficheiro:

```text
.github/workflows/phase0-ci.yml
```

Triggers:

```text
push em main
pull request para main
execução manual (workflow_dispatch)
```

O workflow não faz deploy e não possui permissões de escrita.

## Job API

```text
checkout
→ Node.js 24
→ npm ci
→ bloquear alteração da 0001_baseline.sql publicada
→ npm audit
→ npm run test:phase0
```

Critério:

```text
typecheck = OK
API integração = 100%
segurança = 100%
D1 migrations = 100%
npm audit = 0 vulnerabilidades
```

## Job Flutter

```text
checkout
→ Flutter 3.41.7 stable
→ flutter pub get
→ flutter analyze
→ flutter test
```

Critério:

```text
flutter analyze = 0 issues
flutter test = 100%
```

## Segurança do workflow

O workflow declara:

```yaml
permissions:
  contents: read
```

Não recebe secrets de produção, não executa Wrangler remoto e não faz deploy.

## iOS

A antiga CI específica de simulador iOS é removida.

A implementação iOS real será tratada como pipeline próprio de build/release para dispositivo e distribuição, com assinatura, provisioning e credenciais Apple adequadas. Esse pipeline não faz parte deste gate genérico da Fase 0.

## Critério de conclusão da Fase 0

A CI é considerada validada quando uma execução real no GitHub mostrar:

```text
API — Phase 0      = success
Flutter — Phase 0  = success
```

e o workflow terminar com estado geral verde.
