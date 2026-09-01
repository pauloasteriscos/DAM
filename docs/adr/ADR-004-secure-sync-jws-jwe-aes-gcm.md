# ADR-004 — Sincronização segura com JWS + JWE e AES-256-GCM

- **Estado:** Aceite — implementado
- **Data:** 2026-09-01

## Contexto

TLS protege o transporte, mas o projeto exige uma segunda camada explícita para o payload de sincronização, com autenticidade, integridade e confidencialidade.

## Decisão

O secure sync usa payload assinado e cifrado. A camada combina JWS e JWE, com AES-256-GCM para cifragem autenticada.

## Motivação

Reduzir risco arquitetural, manter o comportamento previsível e tornar a decisão verificável ao longo da evolução do produto.

## Consequências

- O servidor expõe somente material público necessário ao cliente.
- Payload adulterado deve falhar antes de ser aceite.
- Gestão e rotação de chaves tornam-se requisito operacional.
- A observabilidade deve evitar registar plaintext sensível ou material secreto.

## Validação

A Fase 0 valida JWS/JWE, adulteração do JWE e resposta cifrada/assinada.
