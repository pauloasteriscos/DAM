# DailyTalk — Checklist de Release e Rollback

- **Última revisão:** 2026-09-20

## Baseline técnica verificada

```text
Flutter 3.47.5
Dart 3.13.4
CI: .github/workflows/ci-quality-gate.yml
```

A alteração de toolchain não implica, por si só, nova versão funcional da aplicação. A versão/build da app deve ser alterada quando houver uma release que o exija.

## Antes de commit/push

```text
[ ] git status revisto
[ ] git diff --check limpo
[ ] git diff --cached --check limpo
[ ] stage contém apenas ficheiros previstos
[ ] nenhum segredo/artefacto gerado acidental
[ ] gate da API verde quando a API é afetada
[ ] flutter analyze verde quando Flutter é afetado
[ ] flutter test 100% pass quando Flutter é afetado
```

## Quando mudar Flutter/toolchain

Antes de atualizar a versão fixada na CI:

```text
[ ] flutter doctor sem problema bloqueante
[ ] flutter analyze OK
[ ] flutter test 100% pass
[ ] Web build validado
[ ] Android debug validado
[ ] Android release validado
[ ] Windows build validado quando suportado pelo ambiente
[ ] alterações geradas revistas antes de qualquer git add
```

Depois, atualizar a CI num commit separado e exigir Quality Gate verde.

## Antes de deploy API

```text
[ ] commit conhecido
[ ] Quality Gate verde
[ ] flags confirmadas
[ ] deployment/version anterior identificável
[ ] smoke tests definidos
```

## Antes de migration D1

```text
[ ] migration nova; nenhuma migration publicada editada
[ ] testes locais verdes
[ ] cenário de base existente validado
[ ] bookmark Time Travel guardado
[ ] contagens/invariantes importantes registadas
[ ] compatibilidade Worker/schema revista
```

## Depois de deploy

```text
[ ] health OK
[ ] autenticação OK
[ ] fluxo afetado OK
[ ] logs sem regressão crítica
[ ] sync seguro OK quando afetado
```

## Se houver incidente

```text
[ ] impacto classificado
[ ] flag OFF avaliada
[ ] rollback Worker avaliado
[ ] compatibilidade com D1 verificada
[ ] Time Travel apenas se necessário
[ ] evidências e comandos registados
[ ] novo Quality Gate antes da correção
```

## Referências operacionais

- `ROLLBACK_API.md`
- `ROLLBACK_D1.md`
- `ROLLBACK_MOBILE_WEB.md`
