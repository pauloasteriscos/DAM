# DailyTalk — Fase 0 — Quality Gate

- **Estado:** Aprovado — automatizado e ainda vigente como baseline de qualidade
- **Data original:** 2026-09-01
- **Última revisão:** 2026-09-20
- **Objetivo:** impedir que um checkpoint, push ou deploy avance quando a base técnica deixa de estar comprovadamente saudável.

## 1. Princípio

O Quality Gate é binário:

```text
todos os critérios obrigatórios passam
→ checkpoint/release pode avançar

qualquer critério obrigatório falha
→ checkpoint/release fica bloqueado
```

Não se corrige um gate "por exceção" apagando testes, alterando expectativas sem justificação ou ignorando erros de integridade.

A Fase 0 definiu o gate. As fases seguintes aumentam a quantidade de testes e de artefactos protegidos, mas não substituem este princípio.

## 2. Gate local antes de commit/push

### API

Executar em `dailytalk-api`:

```powershell
npm audit
npm run test:phase0
```

O `test:phase0` agrega verificações de:

```text
typecheck
→ integração da API
→ segurança
→ migrations
```

Critério obrigatório:

```text
npm audit → 0 vulnerabilidades bloqueantes
typecheck → OK
testes da API → 100% pass
testes de segurança → 100% pass
testes de migrations → 100% pass
```

Baseline histórica da Fase 0 em 2026-09-01:

```text
API integração     19/19
Segurança          22/22
D1 migrations       7/7
Total API          48/48
```

Os números podem crescer; o critério permanente é 100% pass.

### Flutter

Executar em `dailytalk_mobile`:

```powershell
flutter analyze
flutter test -r expanded --concurrency=1
```

Critério obrigatório:

```text
flutter analyze → 0 issues
flutter test → 100% pass
```

Baseline histórica da Fase 0 em 2026-09-01:

```text
Flutter → 25/25
```

Snapshot validado em 2026-09-20:

```text
Flutter 3.47.5
Dart 3.13.4
flutter analyze → 0 issues
flutter test → 340/340
flutter build web --profile → OK
flutter build apk --debug → OK
flutter build apk --release → OK
flutter build windows --debug → OK
```

Os builds multiplataforma acima foram usados para validar a mudança de toolchain; não significam que todos precisem de ser executados em cada commit quando a alteração não afeta essas superfícies.

### Git

Executar na raiz do repositório:

```powershell
git status
git diff --check
git diff --cached --check
```

Critério obrigatório:

```text
sem erro de whitespace
sem ficheiros sensíveis
sem artefactos locais acidentais
stage contém apenas ficheiros previstos
```

## 3. Gate de migrations

### SQLite

Qualquer alteração estrutural exige:

```text
migration incremental
→ teste de base nova
→ teste de upgrade de versão anterior relevante
→ preservação de dados
→ invariantes/índices verificados
```

### D1

Regras obrigatórias:

```text
0001_baseline.sql → imutável
mudança nova → 0002_..., 0003_..., ...
migration → testada localmente
base existente → cenário de adoção/upgrade testado
```

Antes de alteração remota relevante:

```text
obter bookmark Time Travel
→ guardar evidência privada
→ aplicar migration
→ validar migrations list
→ validar contagens/invariantes
→ quick_check/foreign_key_check quando aplicável
```

## 4. Gate de Feature Flags

Funcionalidade experimental nova:

```text
default → OFF
```

Para funcionalidade com dependências:

```text
Flag OFF
→ funcionalidade não aparece

Flag ON + dependências OK
→ funcionalidade aparece

Flag ON + dependência ausente
→ funcionalidade continua OFF
```

Uma flag não deve ativar funcionalidade independente por efeito colateral.

## 5. Gate antes de deploy

Antes de produção:

```text
Quality Gate local → verde
commit conhecido → identificado
main/origin → estado esperado
feature flags → intenção confirmada
migration remota → plano de rollback definido
```

Se houver alteração D1, o rollback precisa estar preparado antes do deploy.

## 6. Gate pós-deploy

Após API/web/schema:

```text
health → OK
autenticação → smoke test OK
rota protegida sem token → rejeitada
fluxo principal afetado → smoke test OK
erros/logs → sem regressão crítica
```

Se o deploy modificar sync:

```text
DPoP → válido
sync seguro → válido
retry idempotente → preservado
```

## 7. CI automatizada

O gate automatizado está em:

```text
.github/workflows/ci-quality-gate.yml
```

Triggers:

```text
push em main
pull request para main
workflow_dispatch
```

O workflow executa jobs independentes para API e Flutter e usa permissões de leitura do conteúdo do repositório.

A versão Flutter fixada na CI em 2026-09-20 é:

```text
Flutter 3.47.5 stable
```

## 8. Bloqueadores automáticos de release

Qualquer um destes eventos bloqueia a release:

- falha de teste;
- `flutter analyze` com issue;
- TypeScript com erro;
- vulnerabilidade bloqueante reportada pelo gate de dependências;
- migration publicada sendo editada;
- perda de dados em teste de upgrade;
- segredo/keystore/env incluído no Git;
- feature experimental ativada sem intenção explícita;
- ausência de estratégia de rollback para alteração destrutiva;
- divergência não explicada entre DEV e GIT.

## 9. Gate consolidado local

Quando utilizado, o script:

```powershell
.\scripts\phase0-quality-gate.ps1
```

deve executar o gate local consolidado de API + Flutter + verificações Git.

Ele não deve fazer deploy, alterar D1 remoto nem executar rollback.

Se o script e o workflow divergirem, o workflow versionado em `.github/workflows/ci-quality-gate.yml` é a referência para o que a CI efetivamente executa.
