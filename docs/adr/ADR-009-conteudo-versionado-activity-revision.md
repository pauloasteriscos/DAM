# ADR-009 — Conteúdo orientado por dados com activityId estável e revisionId imutável

- **Estado:** Aceite — implementação planeada
- **Data:** 2026-09-01

## Contexto

O conteúdo deve poder ser atualizado, distribuído e sincronizado sem quebrar referências de progresso já existentes.

## Decisão

Cada atividade terá identidade lógica estável (activityId) e versões de conteúdo identificadas por revisionId. Uma revisão publicada é tratada como imutável; nova alteração relevante cria nova revisão.

## Motivação

Reduzir risco arquitetural, manter o comportamento previsível e tornar a decisão verificável ao longo da evolução do produto.

## Consequências

- Progresso referencia uma atividade lógica sem perder contexto da revisão executada.
- Conteúdo pode ganhar nova revisão sem editar retroativamente a anterior.
- O catálogo remoto e a réplica SQLite devem compreender versão e validade do conteúdo.
- Atividades da comunidade deverão usar o mesmo modelo de identidade/versionamento.

## Validação

Será validado quando o modelo de domínio e o pipeline D1 → SQLite forem implementados.
