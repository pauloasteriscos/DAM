# ADR-010 — Progression Engine separado da UI

- **Estado:** Aceite — parcialmente implementado
- **Data:** 2026-09-01
- **Última revisão:** 2026-09-20

## Contexto

A lógica de desbloqueio, dependências, percursos e estados de progressão não deve ficar espalhada por widgets Flutter nem depender da renderização do mapa.

Alterações na progressão devem refletir-se na interface sem transferir regras de domínio para a camada visual.

## Decisão

A progressão é tratada por componentes de domínio/projeção independentes da UI. A camada de apresentação recebe um modelo já calculado e limita-se a representar estado e encaminhar intenções do utilizador.

A arquitetura conceptual permanece:

```text
estado persistido + conteúdo/regras
            ↓
motor/projeção de progressão
            ↓
view model / controller
            ↓
UI Flutter
```

O mecanismo de propagação de alterações pode evoluir sem mover as regras de progressão para widgets.

## Motivação

Separar regras de domínio da apresentação reduz acoplamento, facilita testes determinísticos e permite que a lógica de progressão evolua independentemente da interface.

## Consequências

- Widgets não decidem diretamente se uma atividade está desbloqueada.
- Regras de dependência e percursos ficam centralizadas fora da UI.
- O cálculo de progressão pode ser testado sem rede e sem renderizar widgets.
- A UI consome projeções/view models e reage ao estado resultante.
- O desbloqueio local não depende da sincronização remota.
- A persistência de conclusão e a seleção do percurso correto continuam responsabilidades explícitas do domínio/aplicação, não da UI.

## Estado de implementação

A separação já está materializada nas camadas de domínio e apresentação do mapa de aprendizagem, incluindo assembler/view model, navegação para detalhe de missão e binding para runtimes de atividade.

Os testes atuais cobrem montagem do mapa, fluxo de missão, recomendação/janelas, navegação e binding dos runtimes.

A decisão ainda não é considerada completamente fechada porque o ciclo durável de conclusão continua pendente na Fase 4.7C e a seleção do percurso oficial por `learningLanguageCode` permanece pendente na Fase 4.7B.2A.

## Validação

A validação final deve comprovar, sem colocar regras nos widgets:

```text
atividade concluída
→ estado local persistido
→ progressão recalculada
→ view model/projeção atualizada
→ UI reflete o novo estado
```

e também:

```text
mudar learningLanguageCode
→ selecionar learningPathId correto
→ carregar progressão independente desse percurso
```
