# ADR-006 — D1 com migrations incrementais e baseline imutável

- **Estado:** Aceite — implementado
- **Data:** 2026-09-01

## Contexto

O schema D1 não deve depender de execução manual de ficheiros de schema nem de memória operacional.

## Decisão

O D1 usa migrations versionadas em migrations/. A 0001_baseline.sql representa o baseline adotado e torna-se imutável após publicação. Mudanças futuras entram em 0002_..., 0003_... e assim sucessivamente.

## Motivação

Reduzir risco arquitetural, manter o comportamento previsível e tornar a decisão verificável ao longo da evolução do produto.

## Consequências

- 0001_baseline.sql não deve ser editada após adoção em produção.
- Toda alteração de schema exige nova migration.
- Migrations devem ser testadas em base vazia e cenário de adoção/upgrade relevante.
- Rollback deve ser planeado antes de alterações destrutivas.

## Validação

A Fase 0 validou base vazia, reaplicação, adoção de base existente e integridade pós-migration.
