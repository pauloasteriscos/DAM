# ADR-001 — Offline-first e SQLite como fonte local operacional

- **Estado:** Aceite — implementado
- **Data:** 2026-09-01

## Contexto

O DailyTalk precisa continuar utilizável sem conectividade e não pode colocar a rede no caminho crítico da abertura da aplicação, execução de atividades ou registo inicial do progresso.

## Decisão

A aplicação adota arquitetura offline-first. O SQLite local é a fonte operacional imediata para estado e progresso no dispositivo. Alterações locais são registadas primeiro localmente e sincronizadas posteriormente.

## Motivação

Reduzir risco arquitetural, manter o comportamento previsível e tornar a decisão verificável ao longo da evolução do produto.

## Consequências

- A UI deve responder a partir do estado local sempre que possível.
- O progresso precisa de estado explícito de sincronização.
- Migrações SQLite tornam-se parte obrigatória do ciclo de release.
- Conflitos entre dispositivos precisam de regras determinísticas de merge.

## Validação

Migrações SQLite automatizadas e upgrade Android sem desinstalação foram validados na Fase 0.
