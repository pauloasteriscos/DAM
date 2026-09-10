# Fase 2.4 — Percurso oficial de referência

## Objetivo

Validar no cliente Flutter o primeiro percurso oficial de referência da Fase 2, consumido integralmente pelo contrato `LearningPath` já existente, sem introduzir conteúdo de percurso no código da interface.

## Pacote oficial v3

O percurso `student.fr-fr.phase1` passa a ter 16 atividades distribuídas por quatro etapas:

1. Chegar e apresentar-se;
2. Conhecer a casa;
3. Refeições e rotina;
4. Ganhar autonomia.

A distribuição cobre os seis tipos suportados pelo domínio: `vocabulary`, `dialogue`, `speech`, `quiz`, `review` e `integratedChallenge`.

## Regras pedagógicas

A Fase 2.4 valida explicitamente que:

- vocabulário, diálogo e fala podem coexistir;
- a preferência do utilizador muda apenas a ordem de recomendação;
- grupos `ANY` permitem caminhos alternativos;
- competências obrigatórias impedem atalhos que comprometam a progressão;
- um ramo não escolhido continua disponível;
- o desafio integrado só fica disponível depois das competências mínimas definidas no percurso.

## Revisões

`arrival.vocabulary-01` mantém as revisões 01 e 02 e passa a apontar para `arrival.vocabulary-01.revision-03`.

Isto comprova a edição/publicação de uma atividade já conhecida sem alterar o seu `activityId` nem reescrever o histórico.

## Testes

Teste de domínio:

`test/domain/learning/reference_journey_test.dart`

O teste valida o pacote canónico, a cobertura de tipos, o histórico de revisões e cenários de progressão alternativos.

Teste real API/SQLite/offline:

`tool/phase2/learning_content_reference_journey_live_api_test.dart`

O gate parte de v2, atualiza para v3 sem recompilar Flutter, persiste em SQLite, executa o `DefaultProgressionEngine`, atualiza assets incrementalmente e confirma leitura offline.

## Limite arquitetural

Esta fase fecha o percurso oficial de referência no modelo de conteúdo e na infraestrutura de distribuição/persistência. O novo mapa visual que irá consumir dinamicamente este percurso pertence à Fase 4; a progressão persistida e sincronizada entre dispositivos pertence à Fase 3.

## Versão candidata

- `1.0.9+10`
- tag futura: `v1.0.9`
