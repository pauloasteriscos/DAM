# DailyTalk — Rollback / recuperação do Cloudflare D1

- **Data:** 2026-09-01
- **Escopo:** base D1 de produção
- **Atenção:** Time Travel restore é destrutivo e sobrescreve a base no ponto escolhido.

## Princípio

D1 não deve ser revertido automaticamente só porque o Worker foi revertido.

Ordem de preferência:

```text
1. manter schema compatível
2. corrigir para a frente
3. Feature Flag OFF, quando aplicável
4. rollback do Worker compatível
5. Time Travel somente quando necessário e justificado
```

## Antes de qualquer migration remota relevante

Guardar um bookmark:

```powershell
cd C:\GIT\DAM\dailytalk-api

npx wrangler d1 time-travel info DB `
  --config wrangler.production.jsonc
```

Guardar o bookmark fora do repositório público, juntamente com:

```text
data/hora
commit
migration
contagens importantes
motivo
```

Quando o risco justificar, manter também export da base/schema como evidência operacional.

## Quando considerar Time Travel

Exemplos:

```text
migration destrutiva incorreta
corrupção lógica grave
perda real de dados causada pelo deploy
schema incompatível sem correção segura imediata
```

Não usar Time Travel apenas porque uma query ou endpoint falhou.

## Restaurar para bookmark conhecido

```powershell
npx wrangler d1 time-travel restore DB `
  --bookmark "<BOOKMARK>" `
  --config wrangler.production.jsonc
```

A operação sobrescreve a base e pode cancelar queries/transações em curso.

## Depois do restore

Validar:

```powershell
npx wrangler d1 migrations list DB `
  --config wrangler.production.jsonc `
  --remote
```

E executar verificações apropriadas:

```text
contagem de utilizadores
preferências
submissões
sessões/dispositivos quando aplicável
PRAGMA quick_check
PRAGMA foreign_key_check
```

Depois validar a API contra o schema restaurado.

## Imutabilidade de migrations

Nunca "corrigir" produção editando:

```text
0001_baseline.sql
```

ou qualquer migration já publicada.

Se a base continuar no estado atual e a correção puder ser feita para a frente:

```text
0002 problemática
→ criar 0003 corretiva
```

Se houver Time Travel para antes de uma migration, rever cuidadosamente a tabela de migrations e o estado real antes de reaplicar qualquer ficheiro.

## Registo do incidente

Guardar:

```text
bookmark antes
bookmark após/undo quando fornecido
commit ativo
migration
comandos executados
contagens antes/depois
resultado de integridade
```
