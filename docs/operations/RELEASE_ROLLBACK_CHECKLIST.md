# DailyTalk — Checklist de Release e Rollback

## Antes de commit/push

```text
[ ] git status revisto
[ ] git diff --check limpo
[ ] git diff --cached --check limpo
[ ] nenhum segredo/artefacto acidental
[ ] API gate verde
[ ] Flutter gate verde
```

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
