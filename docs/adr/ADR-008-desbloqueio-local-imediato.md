# ADR-008 — Desbloqueio local e imediato da progressão

- **Estado:** Aceite — implementação planeada
- **Data:** 2026-09-01

## Contexto

O utilizador deve continuar a evoluir mesmo offline. A conclusão de uma atividade não pode ficar à espera do servidor para libertar a próxima.

## Decisão

A conclusão de uma atividade atualiza imediatamente o estado local e executa a regra de desbloqueio no dispositivo. A sincronização posterior replica/merge o progresso entre dispositivos.

## Motivação

Reduzir risco arquitetural, manter o comportamento previsível e tornar a decisão verificável ao longo da evolução do produto.

## Consequências

- A lógica de progressão precisa de ser determinística no cliente.
- O progresso local e o estado de sync são conceitos separados.
- Outro dispositivo poderá avançar por percurso diferente sem perder progresso válido.
- A sincronização não pode bloquear o desbloqueio local.

## Validação

Será validado com testes do tipo: atividade concluída offline → próxima atividade desbloqueada localmente.
