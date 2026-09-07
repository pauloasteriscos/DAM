# Fase 2 — Incremento 1: catálogo oficial operacional em SQLite

## Objetivo

Fechar o primeiro incremento da Fase 2 tornando o pacote de conteúdo oficial da
Fase 1 persistível, verificável e ativável localmente, sem colocar a rede no
caminho crítico da aprendizagem.

Este incremento consolida as subfases 2.1A, 2.1B e 2.1C.

## Resultado consolidado

### 2.1A — Fundação SQLite

- schema local elevado de v3 para v4;
- `learning_content_packages` para armazenar pacotes imutáveis;
- `learning_content_catalog` para manter os ponteiros do catálogo local;
- índices, constraints e chaves estrangeiras;
- criação nova em v4 e upgrades v1→v4, v2→v4 e v3→v4;
- preservação das estruturas e dados existentes;
- `PRAGMA foreign_keys = ON` e `PRAGMA integrity_check = ok` cobertos por testes.

### 2.1B — Importação e integridade

- importação de pacotes JSON usando os contratos da Fase 1;
- validação de `packageVersion`;
- verificação SHA-256 sobre os bytes exatos recebidos;
- `LearningContentCodec` e validação global antes da persistência;
- importação idempotente do mesmo pacote;
- rejeição de conteúdo incompatível, hash divergente e mutação de revisão já
  publicada.

### 2.1C — Ativação atómica e fallback

- ativação apenas de pacotes previamente importados e revalidados;
- troca transacional entre pacote ativo e anterior;
- preservação do último pacote válido;
- leitura do pacote ativo com verificação de integridade;
- fallback automático para o pacote anterior quando o ativo deixa de ser
  utilizável;
- falha explícita e sem alteração dos ponteiros quando ativo e anterior são
  ambos inválidos.

## Invariantes preservadas

1. `activityId` continua a identificar a atividade estável.
2. `revisionId` identifica conteúdo imutável.
3. Um pacote inválido não é parcialmente aceite.
4. A rede não é necessária para ler o conteúdo já ativado.
5. O estado pedagógico não é persistido dentro do pacote; continua calculado
   pelo `ProgressionEngine`.
6. O conteúdo anterior válido não é destruído ao ativar uma nova versão.
7. As tabelas históricas da aplicação continuam preservadas.

## Guardrail de finais de linha

O SHA-256 do pacote é calculado sobre os bytes exatos. Durante a validação da
2.1B foi demonstrado que uma alteração apenas de finais de linha modifica o hash
do JSON oficial. Para eliminar variações de checkout entre plataformas, a raiz
do repositório passa a definir em `.gitattributes`:

```text
dailytalk_mobile/assets/content/*.json text eol=lf
```

O pacote canónico `phase1_example_path.v1.json` utilizado neste incremento possui
SHA-256:

```text
6d5bee9037aecaf70773e484076ad646d6b05d7f01bf0f00b8f5a70e798de968

O hash acima corresponde ao ficheiro canónico em UTF-8 com finais de linha LF, conforme `.gitattributes`.
```

## Evidência antes da consolidação final

Após a conclusão da 2.1C no DEV:

- `flutter analyze`: sem problemas;
- migrations: 7 testes aprovados;
- importação/integridade: 9 testes aprovados;
- ativação/fallback: 10 testes aprovados;
- domínio Learning Path: 42 testes aprovados;
- bateria completa: 89 testes aprovados.

## Versão candidata

A consolidação do Incremento 2.1 utiliza:

```text
1.0.6+7
```

O valor visível e enviado pela aplicação passa a ser:

```text
1.0.6
```

A versão só deve ser publicada e marcada com `v1.0.6` depois da bateria final de
qualidade e da confirmação do CI.

## Gate final do Incremento 2.1

Antes de commit/tag, executar em DEV:

```powershell
flutter clean
flutter pub get
dart format lib\data\content lib\data\database\app_database.dart lib\config\app_config.dart `
  test\data\content test\database_migration_test.dart
flutter analyze
flutter test test\database_migration_test.dart
flutter test test\data\content\learning_content_import_test.dart
flutter test test\data\content\learning_content_catalog_test.dart
flutter test test\domain\learning
flutter test test\app_version_test.dart
flutter test
```

O gate é aprovado somente se toda a bateria permanecer verde.

## Fora do escopo

Este incremento ainda não implementa:

- catálogo remoto/API de distribuição;
- download automático de novas versões;
- assinatura criptográfica do pacote remoto;
- sincronização de progresso;
- outbox de progresso;
- convergência multidispositivo.

Esses itens pertencem aos próximos incrementos da Fase 2 e à Fase 3.
