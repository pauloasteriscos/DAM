# Architecture Decision Records — DailyTalk

Última atualização: 2026-09-01

Este diretório regista decisões arquiteturais que condicionam a evolução do DailyTalk.

## Convenções

- ADRs aceites não são reescritos para alterar a decisão histórica; uma mudança substancial deve criar novo ADR que substitua o anterior.
- Estados usados: `Aceite — implementado` e `Aceite — implementação planeada`.

## Índice

- [ADR-001 — Offline-first e SQLite como fonte local operacional](./ADR-001-offline-first-sqlite-fonte-local.md) — **Aceite — implementado**
- [ADR-002 — Sessão por dispositivo com renovação silenciosa](./ADR-002-sessao-por-dispositivo-refresh-silencioso.md) — **Aceite — implementado**
- [ADR-003 — DPoP para vincular tokens ao dispositivo e à requisição](./ADR-003-dpop-binding-token.md) — **Aceite — implementado**
- [ADR-004 — Sincronização segura com JWS + JWE e AES-256-GCM](./ADR-004-secure-sync-jws-jwe-aes-gcm.md) — **Aceite — implementado**
- [ADR-005 — Idempotência e anti-replay na sincronização](./ADR-005-idempotencia-antireplay-sync.md) — **Aceite — implementado**
- [ADR-006 — D1 com migrations incrementais e baseline imutável](./ADR-006-d1-migrations-incrementais.md) — **Aceite — implementado**
- [ADR-007 — Feature Flags fail-closed para funcionalidades novas](./ADR-007-feature-flags-fail-closed.md) — **Aceite — implementado**
- [ADR-008 — Desbloqueio local e imediato da progressão](./ADR-008-desbloqueio-local-imediato.md) — **Aceite — implementação planeada**
- [ADR-009 — Conteúdo orientado por dados com activityId estável e revisionId imutável](./ADR-009-conteudo-versionado-activity-revision.md) — **Aceite — implementação planeada**
- [ADR-010 — Progression Engine separado da UI](./ADR-010-progression-engine-separado-ui.md) — **Aceite — implementação planeada**
