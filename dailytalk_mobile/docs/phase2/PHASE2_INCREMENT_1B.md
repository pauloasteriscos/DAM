# Fase 2.1B — Importação e integridade do pacote oficial

## Objetivo

Adicionar a fronteira de importação entre um pacote de conteúdo já recebido e a
réplica SQLite criada na Fase 2.1A, sem introduzir ainda ativação, fallback,
rede ou sincronização.

## Estado de entrada

- Fase 1 concluída (`v1.0.5`).
- Fase 2.1A aprovada no DEV.
- SQLite schema v4 com `learning_content_packages` e
  `learning_content_catalog`.
- `LearningContentCodec` e `LearningPathValidator` da Fase 1 permanecem a
  fonte de verdade para interpretação e validação estrutural do domínio.

## Escopo implementado

1. `LearningContentPackageRepository`
   - leitura por `learning_path_id + package_version`;
   - listagem das versões persistidas de um percurso;
   - persistência transacional apenas depois da validação;
   - reimportação idempotente do mesmo hash;
   - rejeição de reutilização da mesma versão com outro hash.

2. `LearningContentImportService`
   - exige `packageVersion >= 1`;
   - valida o formato do SHA-256 esperado;
   - calcula SHA-256 sobre os bytes UTF-8 exatos do JSON recebido;
   - rejeita divergência de hash antes de tocar no SQLite;
   - interpreta o JSON com `LearningContentCodec`;
   - reutiliza a validação global do Learning Path da Fase 1;
   - preserva a imutabilidade de `RevisionId` entre pacotes já importados;
   - confirma integridade do payload SQLite numa reimportação idempotente.

3. Testes dedicados
   - pacote oficial v1 e SHA-256 conhecido;
   - idempotência;
   - packageVersion inválida;
   - hash esperado inválido;
   - hash divergente;
   - pacote estruturalmente inválido;
   - conflito de packageVersion;
   - imutabilidade de RevisionId;
   - nova revisão válida numa versão seguinte.

## Fora de escopo

A Fase 2.1B deliberadamente **não**:

- escreve em `learning_content_catalog`;
- ativa pacotes;
- mantém `active_package_id`/`previous_package_id`;
- executa rollback/fallback;
- faz download por API;
- executa lógica no arranque da app;
- altera UI;
- altera versão da aplicação;
- implementa sincronização.

Essas responsabilidades permanecem para a Fase 2.1C e incrementos seguintes.

## Gate da Fase 2.1B

O incremento é aprovado quando:

- `flutter analyze` não reporta problemas;
- os testes da Fase 2.1A continuam verdes;
- os testes de `learning_content_import_test.dart` passam;
- a bateria completa não apresenta regressões;
- um pacote válido é persistido apenas após SHA-256 + codec + validação;
- reimportar o mesmo pacote não cria duplicados;
- pacote/hash inválido não altera o SQLite;
- uma revisão publicada não pode ser modificada mantendo o mesmo RevisionId;
- nenhuma linha é criada em `learning_content_catalog`.

## Próximo incremento

**Fase 2.1C — ativação atómica e fallback para a última versão válida.**
