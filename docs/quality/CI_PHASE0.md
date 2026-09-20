# DailyTalk — Fase 0 — CI automatizada

- **Estado:** Validada e ativa no GitHub Actions
- **Data original:** 2026-09-01
- **Última revisão:** 2026-09-20

## Objetivo

Automatizar os gates de qualidade definidos na Fase 0 e manter essas verificações como proteção contínua das fases seguintes.

A designação "Fase 0" permanece no documento por origem histórica. O workflow atual não está limitado à Fase 0: ele continua a proteger a `main` enquanto o projeto evolui.

## Workflow atual

Ficheiro:

```text
.github/workflows/ci-quality-gate.yml
```

Nome:

```text
CI - Quality Gate
```

Triggers:

```text
push em main
pull request para main
execução manual (workflow_dispatch)
```

O workflow não faz deploy e declara permissões de leitura do conteúdo do repositório.

## Job API

Nome atual:

```text
API - Typecheck, Security & Tests
```

Fluxo principal:

```text
checkout
→ Node.js 24
→ npm ci
→ proteger 0001_baseline.sql publicada
→ npm audit
→ npm run test:phase0
```

Critério:

```text
typecheck = OK
testes API = 100%
segurança = 100%
D1 migrations = 100%
audit de dependências = sem vulnerabilidade bloqueante
```

A proteção da `0001_baseline.sql` impede que a baseline D1 já publicada seja alterada por um push/PR comparável; alterações de schema devem usar nova migration numerada.

## Job Flutter

Nome atual:

```text
Flutter - Analyze & Tests
```

Fluxo principal:

```text
checkout
→ Flutter 3.47.5 stable
→ flutter pub get
→ flutter analyze
→ flutter test -r expanded --concurrency=1
```

Critério:

```text
flutter analyze = 0 issues
flutter test = 100% pass
```

Snapshot local associado à atualização da toolchain em 2026-09-20:

```text
Flutter 3.47.5
Dart 3.13.4
Flutter tests = 340/340
Web profile build = OK
Android debug build = OK
Android release build = OK
Windows debug build = OK
```

Os builds de Web/Android/Windows foram validação local da mudança de toolchain e não fazem parte, neste momento, do job Flutter genérico da CI.

## Evidência da atualização para Flutter 3.47.5

Commit que alinhou o workflow:

```text
1d42fcf78ef51831d947da2e9c8522d6298e395c
ci: alinhar Flutter do Quality Gate com 3.47.5
```

Execução observada no GitHub Actions:

```text
Workflow: CI - Quality Gate
Run ID: 35484642932
Resultado: success
```

## Segurança do workflow

O workflow declara:

```yaml
permissions:
  contents: read
```

Não recebe secrets de produção, não executa Wrangler remoto e não faz deploy.

## iOS

A CI genérica não pretende substituir um pipeline real de build/release iOS.

Um pipeline iOS para dispositivo/distribuição deverá tratar separadamente assinatura, provisioning e credenciais Apple adequadas.

## Critério permanente

A CI está validada quando os jobs obrigatórios terminam com sucesso.

Os números absolutos de testes podem crescer ao longo do projeto. O contrato que permanece é:

```text
análise estática limpa
+
testes obrigatórios 100% pass
+
proteções de segurança/migrations preservadas
=
Quality Gate verde
```
