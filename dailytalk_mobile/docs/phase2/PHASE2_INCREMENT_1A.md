# Fase 2.1A — Fundação SQLite do catálogo oficial

## Objetivo

Criar exclusivamente a fundação persistente do catálogo oficial no SQLite,
sem importar conteúdo, sem ativar pacotes e sem introduzir rede. Este incremento
prepara a base local para as subfases 2.1B (importação e integridade) e 2.1C
(ativação atómica e fallback).

## Alterações deste incremento

- evolução aditiva do SQLite de `v3` para `v4`;
- nova tabela `learning_content_packages`;
- nova tabela `learning_content_catalog`;
- índices do catálogo local;
- constraints de versão, hash e coerência dos ponteiros;
- chaves estrangeiras compostas que impedem um `learning_path_id` de apontar
  para um pacote de outro percurso;
- criação das mesmas estruturas numa instalação nova;
- testes explícitos de upgrade `v1 -> v4`, `v2 -> v4` e `v3 -> v4`;
- preservação das tabelas e dados históricos durante o upgrade;
- verificação de `PRAGMA foreign_keys` e `PRAGMA integrity_check`.

## Modelo persistente preparado

### `learning_content_packages`

```text
id
learning_path_id
package_version
schema_version
content_hash
payload_json
source
imported_at
```

A combinação `(learning_path_id, package_version)` é única. Nesta subfase a
tabela é apenas infraestrutura: nenhum importer/repository novo escreve nela.

### `learning_content_catalog`

```text
learning_path_id
active_package_id
previous_package_id
activated_at
```

Os campos de ativação são definidos agora para estabilizar o schema, mas a
semântica de troca atómica e fallback só será implementada e validada na Fase
2.1C.

## Fora do escopo

Este incremento deliberadamente **não** inclui:

- leitura/importação do JSON produzido na Fase 1;
- cálculo ou validação de SHA-256 em Dart;
- repository de conteúdo;
- bootstrap/seed do pacote oficial;
- ativação de pacote;
- fallback para pacote anterior;
- API/D1 para distribuição;
- alterações no Progression Engine;
- alterações na sincronização de progresso.

## Gate da Fase 2.1A

A subfase fica aprovada quando for demonstrado que:

1. uma base nova é criada como SQLite v4 com as novas tabelas e índices;
2. bases históricas v1, v2 e v3 migram para v4;
3. atividades, submissões, resultados, analytics, fila de sincronização e notas
   locais existentes continuam preservados;
4. as chaves estrangeiras estão ativas;
5. as constraints do catálogo rejeitam relações inválidas;
6. `PRAGMA integrity_check` devolve `ok`.

## Validação em DEV

Executar a partir de `C:\DEV\Flutter\dailytalk_mobile`:

```powershell
flutter clean
flutter pub get

dart format lib\data\database\app_database.dart `
  test\database_migration_test.dart

flutter analyze
flutter test test\database_migration_test.dart
flutter test
```

Não criar commit, tag ou versão de release antes de este gate ficar verde.

## Continuação

Após aprovação:

- **Fase 2.1B** — importação e integridade do pacote oficial;
- **Fase 2.1C** — ativação atómica e fallback;
- só depois considerar o Incremento 2.1 completo.
