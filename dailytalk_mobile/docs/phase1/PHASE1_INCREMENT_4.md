# Fase 1 - Incremento 4: conteúdo versionado e orientado por dados

## Objetivo

Permitir que o núcleo de aprendizagem carregue percursos completos a partir de
JSON, sem construir atividades no código da interface. O pacote é interpretado
em Dart puro, validado antes do uso e pode ser armazenado futuramente em SQLite
ou recebido pela API sem alterar o motor de progressão.

## Entregue

- `LearningContentCodec` com leitura e escrita JSON;
- suporte explícito ao schema de conteúdo versão 1;
- JSON Schema Draft 2020-12 para validação editorial e na futura API;
- rejeição segura de versões ainda não suportadas;
- validação de campos obrigatórios, tipos e enums;
- interpretação integral de jornadas, etapas, elementos, atividades, revisões,
  competências e pré-requisitos;
- integração automática com `LearningPathValidator` após a interpretação;
- códigos estáveis para erros de pacote;
- pacote exemplo com duas etapas e três caminhos paralelos: vocabulário,
  diálogo e fala;
- regras `ALL` e `ANY` representadas no próprio conteúdo;
- teste de round-trip JSON → domínio → JSON → domínio;
- testes que demonstram desbloqueio local imediato a partir do pacote.

## Códigos de erro do pacote

```text
invalidJson
invalidRoot
missingField
unexpectedField
invalidFieldType
invalidEnumValue
unsupportedSchemaVersion
invalidContent
invalidLearningPath
```

## Contrato da versão 1

O campo `schemaVersion` pertence à raiz e deve possuir o valor inteiro `1`.
Enums são serializados pelos nomes estáveis definidos no domínio. Textos
localizados usam objetos cujas chaves são locales e cujos valores são textos.

Pré-requisitos usam uma união discriminada pelo campo `type`:

```json
{"type": "activityCompleted", "activityId": "arrival.vocabulary-01"}
{"type": "competencyAchieved", "competencyId": "arrival.greeting-basics"}
{"type": "group", "operator": "all", "rules": []}
```

O último exemplo ilustra apenas a forma. Grupos vazios continuam proibidos
pelas invariantes do domínio.

## Invariantes

1. Um pacote incompatível nunca é interpretado parcialmente.
2. O JSON não define estados pedagógicos; estes continuam calculados pelo motor.
3. `activityId` permanece estável e `revisionId` identifica conteúdo imutável.
4. A preferência de prática ordena recomendações, sem excluir caminhos.
5. O conteúdo é validado globalmente antes de produzir decisões pedagógicas.
6. O codec não depende de Flutter, SQLite, HTTP ou estado da interface.

## Fora do escopo deste incremento

- persistência SQLite do catálogo;
- download, assinatura e ativação de pacotes remotos;
- migração automática entre versões de schema;
- conteúdo completo de produção;
- mapa Flutter dinâmico.

## Validação em DEV

Executar a partir de `C:\DEV\Flutter\dailytalk_mobile`:

```powershell
dart format lib\domain\learning test\domain\learning
flutter analyze
flutter test test\domain\learning
flutter test
```

## Versão

Este incremento utiliza `1.0.5+6`. O valor visível enviado pela aplicação é
`1.0.5`.
