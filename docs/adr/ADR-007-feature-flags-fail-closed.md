# ADR-007 — Feature Flags fail-closed para funcionalidades novas

- **Estado:** Aceite — implementado
- **Data:** 2026-09-01

## Contexto

Novas funcionalidades devem poder entrar no código sem alterar automaticamente o comportamento da versão estável.

## Decisão

Funcionalidades experimentais começam desligadas. A camada inicial é compile-time e usa bool.fromEnvironment com defaultValue false. Dependências entre flags são avaliadas antes de considerar a funcionalidade efetivamente ativa.

## Motivação

Reduzir risco arquitetural, manter o comportamento previsível e tornar a decisão verificável ao longo da evolução do produto.

## Consequências

- Flag ausente ou inválida resulta em funcionalidade desligada.
- Flag ON + dependência ausente continua efetivamente OFF.
- Ativar uma flag não liga funcionalidades independentes por efeito colateral.
- Uma futura configuração remota poderá desligar funcionalidades, mas não deverá ultrapassar o limite autorizado pelo build.

## Validação

Seis testes específicos de Feature Flags e a bateria Flutter completa foram aprovados na Fase 0.
