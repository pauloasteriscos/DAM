# Fase 1 - Incremento 1: domínio e contratos

## Objetivo

Fixar a linguagem central do novo núcleo de aprendizagem antes de integrar
persistência, rede ou interface. Todo o código deste incremento é Dart puro.

## Entregue

- identificadores tipados e estáveis;
- `LearningPath`, `Journey`, `Stage`, `PathElement`, `Activity`,
  `ActivityRevision` e `Competency`;
- `activityId` estável e `revisionId` imutável;
- quatro estados pedagógicos separados dos estados de sincronização;
- origem e visibilidade do conteúdo;
- preferência de prática não exclusiva;
- regras compostas de pré-requisitos `ALL` e `ANY`;
- factos monotónicos de atividades concluídas e competências demonstradas;
- contrato de entrada e saída do `ProgressionEngine`;
- testes unitários do domínio e do contrato;
- teste de coerência entre a versão do `pubspec.yaml` e `AppConfig`.

## Invariantes

1. O domínio não importa Flutter, SQLite, HTTP, Controller ou ChangeNotifier.
2. Uma conclusão válida é representada como facto monotónico.
3. Estado pedagógico e estado de sincronização são dimensões diferentes.
4. A recomendação de um caminho não bloqueia caminhos alternativos.
5. Grupos `ALL` e `ANY` vazios são inválidos.
6. Uma atividade contém identidade estável e revisões imutáveis.
7. Coleções expostas pelo domínio são imutáveis.

## Fora do escopo deste incremento

- serialização e JSON Schema;
- validação global de ciclos e referências entre agregados;
- implementação definitiva do `ProgressionEngine`;
- migrations ou repositórios SQLite;
- catálogo remoto e contratos HTTP;
- sincronização multidispositivo;
- mapa Flutter dinâmico.

## Validação em DEV

Executar a partir de `C:\DEV\Flutter\dailytalk_mobile`:

```powershell
dart format lib\domain\learning test\domain\learning test\app_version_test.dart
flutter analyze
flutter test test\domain\learning test\app_version_test.dart
flutter test
```

## Versão

Este incremento utiliza `1.0.2+3`. Em alterações futuras, atualizar sempre a
versão do `pubspec.yaml` e o valor predefinido de `AppConfig.appVersion`.
