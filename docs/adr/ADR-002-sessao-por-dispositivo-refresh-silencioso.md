# ADR-002 — Sessão por dispositivo com renovação silenciosa

- **Estado:** Aceite — implementado
- **Data:** 2026-09-01

## Contexto

Sessões que expiram de forma visível degradam a experiência móvel, mas tokens longos aumentam a janela de exposição em caso de comprometimento.

## Decisão

Cada dispositivo mantém uma sessão própria. Access tokens são de curta duração e podem ser renovados silenciosamente por refresh token vinculado ao dispositivo.

## Motivação

Reduzir risco arquitetural, manter o comportamento previsível e tornar a decisão verificável ao longo da evolução do produto.

## Consequências

- O backend mantém identidade de dispositivo e estado de sessão.
- Refresh deve exigir prova válida do dispositivo.
- Revogar um dispositivo invalida os tokens associados.
- A aplicação deve renovar a sessão sem interromper a atividade do utilizador.

## Validação

A bateria de segurança cobre criação de sessão vinculada, refresh válido e revogação de dispositivo.
