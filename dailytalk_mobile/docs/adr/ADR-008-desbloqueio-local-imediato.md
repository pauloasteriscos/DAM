# ADR-008 — Desbloqueio local e imediato da progressão

- **Estado:** Aceite — parcialmente implementado
- **Data:** 2026-09-01
- **Última revisão:** 2026-09-20

## Contexto

O utilizador deve continuar a evoluir mesmo offline. A conclusão de uma atividade não pode ficar à espera do servidor para libertar a próxima.

O progresso precisa ainda de permanecer isolado por percurso de aprendizagem. Mudar de idioma não deve reutilizar indevidamente a progressão de outro idioma.

## Decisão

A conclusão de uma atividade atualiza primeiro o estado local e executa a regra de desbloqueio no dispositivo. A sincronização posterior replica/merge o progresso entre dispositivos.

O estado de progressão é associado ao `learningPathId`, para que percursos distintos possam manter progressos independentes.

## Motivação

Retirar a rede do caminho crítico da progressão preserva a experiência offline-first, reduz latência percebida e evita que uma falha temporária de conectividade bloqueie o utilizador.

## Consequências

- A lógica de progressão precisa de ser determinística no cliente.
- O progresso local e o estado de sincronização são conceitos separados.
- Outro dispositivo pode avançar por percurso diferente sem perder progresso válido.
- A sincronização não pode bloquear o desbloqueio local.
- A seleção do percurso oficial precisa respeitar `learningLanguageCode`.
- A conclusão persistida precisa ser idempotente e posteriormente sincronizável.

## Estado de implementação

Já existe infraestrutura local de progressão/projeção e o mapa de aprendizagem utiliza estado persistido por `learningPathId`. A Fase 4.7 também introduziu o detalhe de missão e a ligação técnica entre o mapa e runtimes executáveis.

Ainda não está fechado o ciclo completo:

```text
runtime concluído
→ persistir conclusão local
→ recalcular progressão
→ desbloquear imediatamente
→ marcar alteração pendente de sincronização
```

A ligação da conclusão dos runtimes ao mecanismo durável de `completeActivity()` permanece pendente na Fase 4.7C.

Também permanece pendente a Fase 4.7B.2A, que deve resolver:

```text
learningLanguageCode
→ percurso oficial correspondente
```

antes de considerar validada a separação completa do progresso entre idiomas.

## Validação

A decisão será considerada integralmente validada quando um teste end-to-end demonstrar:

```text
atividade concluída offline
→ conclusão persistida no percurso correto
→ próxima atividade desbloqueada localmente
→ reinício da aplicação preserva o estado
→ sincronização posterior não bloqueia a progressão
```
