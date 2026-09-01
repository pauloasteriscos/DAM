# ADR-005 — Idempotência e anti-replay na sincronização

- **Estado:** Aceite — implementado
- **Data:** 2026-09-01

## Contexto

Num sistema offline-first, o cliente pode reenviar operações por perda de resposta, mudança de rede ou retry. O mesmo envio não pode duplicar progresso.

## Decisão

A sincronização usa identificadores estáveis de lote e submissão, sequência por dispositivo e proteção anti-replay. Repetições idênticas são idempotentes; reutilizações incompatíveis são rejeitadas.

## Motivação

Reduzir risco arquitetural, manter o comportamento previsível e tornar a decisão verificável ao longo da evolução do produto.

## Consequências

- batchId identifica um lote lógico.
- clientSubmissionId identifica uma submissão lógica no cliente.
- A sequência por dispositivo impede repetição indevida de operações novas.
- O backend mantém estado suficiente para reconhecer duplicados.

## Validação

Os testes cobrem retry do mesmo batch, batchId com conteúdo diferente, sequence repetida e clientSubmissionId duplicado.
