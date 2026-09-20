# ADR-009 — Conteúdo orientado por dados com activityId estável e revisionId imutável

- **Estado:** Aceite — parcialmente implementado
- **Data:** 2026-09-01
- **Última revisão:** 2026-09-20

## Contexto

O conteúdo deve poder ser atualizado, distribuído e sincronizado sem quebrar referências de progresso já existentes.

A aplicação evoluiu para um modelo em que o mapa e os runtimes consomem conteúdo estruturado, em vez de dependerem apenas de definições fixas na UI.

## Decisão

Cada atividade possui identidade lógica estável (`activityId`) e versões de conteúdo identificadas por `revisionId`. Uma revisão publicada é tratada como imutável; uma alteração relevante cria nova revisão.

O conteúdo oficial deve ser validado antes de se tornar ativo e a aplicação deve conseguir preservar uma versão local válida quando uma nova versão não puder ser aceite.

## Motivação

Identidade estável e revisão imutável permitem evoluir conteúdo sem reescrever retroativamente aquilo que o utilizador executou, mantendo rastreabilidade de progresso e compatibilidade com sincronização.

## Consequências

- Progresso referencia uma atividade lógica sem perder o contexto da revisão executada.
- Conteúdo pode ganhar nova revisão sem editar retroativamente a anterior.
- O catálogo/réplica local precisa compreender versão, validade e ativação.
- Conteúdo inválido não deve substituir a última versão local válida.
- Atividades criadas pela comunidade deverão usar o mesmo modelo de identidade/versionamento quando essa funcionalidade for implementada.

## Estado de implementação

A camada local de conteúdo já possui modelo, codec e validação para o contrato atual, incluindo conteúdo oficial V2 utilizado pelos testes de integração do runtime.

A Fase 4.7A concluiu a ligação técnica entre o conteúdo estruturado e a execução das atividades. O artefacto oficial V2 e os testes de binding/runtime demonstram que o conteúdo já é consumido pela camada de aprendizagem.

Esta decisão não declara concluídas funcionalidades futuras de publicação/curadoria comunitária. Essas funcionalidades permanecem fora do escopo atual.

## Validação

O contrato local deve continuar protegido por testes de:

```text
decode/encode do conteúdo
→ validação estrutural
→ identidade/revisão coerentes
→ conteúdo oficial válido
→ binding do conteúdo ao runtime correto
```

Mudanças futuras no pipeline de distribuição/ativação devem preservar a última versão válida e acrescentar testes de upgrade/rollback quando alterarem o formato persistido.
