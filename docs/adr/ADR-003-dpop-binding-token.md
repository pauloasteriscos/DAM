# ADR-003 — DPoP para vincular tokens ao dispositivo e à requisição

- **Estado:** Aceite — implementado
- **Data:** 2026-09-01

## Contexto

Um access token roubado não deve ser suficiente para reutilizar uma sessão válida em outro cliente.

## Decisão

Rotas protegidas da sessão vinculada usam DPoP. A prova inclui método HTTP, URL, identificador único, timestamp e vínculo ao access token quando aplicável.

## Motivação

Reduzir risco arquitetural, manter o comportamento previsível e tornar a decisão verificável ao longo da evolução do produto.

## Consequências

- O cliente mantém uma chave de assinatura por dispositivo.
- O servidor valida assinatura, htm, htu, jti, iat e ath quando aplicável.
- Replays de jti são rejeitados.
- Fluxos de refresh e revogação respeitam o binding do dispositivo.

## Validação

Os testes cobrem ausência de DPoP, replay, htm/htu/ath incorretos e assinatura por chave diferente.
