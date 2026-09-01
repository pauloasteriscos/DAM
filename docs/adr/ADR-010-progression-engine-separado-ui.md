# ADR-010 — Progression Engine separado da UI

- **Estado:** Aceite — implementação planeada
- **Data:** 2026-09-01

## Contexto

A lógica de desbloqueio, dependências, percursos e estados de progressão não deve ficar espalhada por widgets Flutter nem depender da renderização do mapa.

Além disso, alterações na progressão devem refletir-se imediatamente na interface sem criar acoplamento direto entre o motor de domínio e os widgets.

## Decisão

A progressão será implementada num componente de domínio independente e testável, preferencialmente em Dart puro.

O Progression Engine receberá o estado de progresso, o grafo de atividades e as respetivas regras, calculando o estado efetivo de cada atividade sem depender da UI Flutter.

A propagação das alterações para a interface utilizará o padrão Observer através de uma camada de controller/state.

O Progression Engine não dependerá diretamente de widgets, `BuildContext`, `ChangeNotifier` ou outros elementos específicos da camada de apresentação.

A arquitetura seguirá, conceptualmente:

```text
Progression Engine
        ↓
Controller / State
        ↓
Observer
        ↓
UI Flutter
```

## Motivação

Separar regras de domínio da apresentação reduz acoplamento, facilita testes determinísticos e permite que a lógica de progressão evolua independentemente da interface.

O padrão Observer permite que a UI reaja imediatamente quando o estado de progressão muda, sem obrigar o Progression Engine a conhecer quem apresenta ou consome esse estado.

## Consequências

- Widgets não decidem diretamente se uma atividade está desbloqueada.
- O Progression Engine recebe progresso + grafo/regras e devolve o estado efetivo.
- Regras ALL/ANY e percursos alternativos ficam centralizados no motor.
- O Progression Engine pode ser testado sem inicializar Flutter UI ou rede.
- O Progression Engine não depende de `BuildContext` ou widgets.
- Uma camada de controller/state publica ou observa alterações produzidas pelo motor.
- A UI reage automaticamente quando o estado efetivo de progressão muda.
- O mecanismo de observação pode ser substituído sem alterar as regras do domínio.
- Uma atividade concluída offline pode provocar imediatamente novo cálculo de progressão e atualização da interface.
- A sincronização remota permanece fora do caminho crítico do desbloqueio local.

## Validação

A decisão será validada separando os testes em dois níveis:

```text
Atividade concluída offline
→ próxima atividade desbloqueia localmente
```

```text
Estado mudou
→ Observer notifica
→ UI atualiza
```

```text
Nenhuma mudança de estado
→ UI não precisa reagir
```

Os testes unitários do Progression Engine deverão funcionar sem widgets Flutter, rede ou D1.
