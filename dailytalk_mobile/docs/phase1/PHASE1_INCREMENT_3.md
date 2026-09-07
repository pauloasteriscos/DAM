# Fase 1 - Incremento 3: integridade global do percurso

## Objetivo

Impedir que conteúdo orientado por dados, proveniente de SQLite ou da API,
chegue ao motor de progressão com referências quebradas ou dependências
cíclicas. A validação continua em Dart puro e sem dependências externas.

## Entregue

- `LearningPathValidator` para inspeção completa do agregado;
- resultado imutável com todos os problemas encontrados;
- códigos de erro estáveis e localizações lógicas;
- deteção global de `PathElementId` duplicado;
- validação de atividades referenciadas por elementos;
- validação de atividades e competências usadas em pré-requisitos;
- validação das competências declaradas pelas revisões;
- deteção de ciclos entre dependências de atividades;
- integração fail-fast com `DefaultProgressionEngine`;
- sete testes comportamentais adicionais.

## Problemas identificáveis

```text
duplicatePathElementId
missingElementActivity
missingPrerequisiteActivity
missingPrerequisiteCompetency
missingRevisionCompetency
cyclicActivityPrerequisite
```

## Comportamento

`inspect()` devolve todos os problemas estruturais encontrados, permitindo
diagnóstico editorial. `validate()` lança `LearningPathValidationException`
quando o percurso é inválido. O motor chama `validate()` antes de calcular
estados ou recomendações.

## Invariantes

1. Nenhuma referência inexistente é ignorada silenciosamente.
2. Um percurso inválido não produz decisões pedagógicas parciais.
3. A validação não depende da ordem de sincronização nem de conectividade.
4. Os erros possuem códigos estáveis, separados das mensagens de interface.
5. A deteção de ciclos considera dependências aninhadas em grupos ALL/ANY.

## Fora do escopo deste incremento

- serialização JSON dos modelos;
- JSON Schema e compatibilidade entre versões;
- persistência SQLite do catálogo;
- download e assinatura do conteúdo remoto;
- interface editorial para corrigir problemas.

## Validação em DEV

Executar a partir de `C:\DEV\Flutter\dailytalk_mobile`:

```powershell
dart format lib\domain\learning test\domain\learning
flutter analyze
flutter test test\domain\learning
flutter test
```

Resultados esperados após este incremento:

```text
testes do domínio = 31
testes completos = 58
```

## Versão

Este incremento utiliza `1.0.4+5`. O valor visível enviado pela aplicação é
`1.0.4`.
