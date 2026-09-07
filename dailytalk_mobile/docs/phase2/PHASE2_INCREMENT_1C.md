# Fase 2.1C — Ativação atómica e fallback local

## Objetivo

Completar o catálogo operacional iniciado nas Fases 2.1A/2.1B: um pacote já
importado só se torna conteúdo oficial ativo depois de nova verificação da cópia
SQLite e de uma troca transacional dos ponteiros do catálogo. Se a cópia ativa
ficar inválida, a última versão anterior válida é promovida automaticamente.

## Estado de entrada

- Fase 1 concluída (`v1.0.5`).
- Fase 2.1A aprovada: SQLite v4 e catálogo local.
- Fase 2.1B aprovada: importação, SHA-256, codec, validação e imutabilidade.
- Nenhuma dependência de rede no caminho crítico.

## Escopo implementado

1. `LearningContentCatalogRepository`
   - leitura do catálogo por `learning_path_id`;
   - primeira ativação com `previous_package_id = NULL`;
   - troca atómica `active <- novo` e `previous <- ativo anterior`;
   - reativação idempotente do pacote já ativo;
   - recuperação transacional para o `previous_package_id` apenas quando o
     catálogo ainda corresponde ao estado previamente validado.

2. `LearningContentCatalogService`
   - exige que o pacote já esteja importado;
   - verifica novamente SHA-256, codec e coerência dos metadados SQLite antes
     da ativação;
   - lê o pacote ativo sem rede;
   - se o ativo estiver corrompido/inválido, valida a versão anterior;
   - promove atomicamente a versão anterior válida;
   - mantém o pacote falhado armazenado para diagnóstico, sem o reutilizar como
     fallback automático;
   - falha explicitamente quando não existe fallback válido.

3. Integridade adicional
   - `LearningContentPackageRepository.findPackageById` restringe a pesquisa ao
     mesmo `learning_path_id`;
   - `validateStoredPackage` deteta corrupção do payload e incoerência entre o
     conteúdo descodificado e os metadados persistidos.

## Fora de escopo

A Fase 2.1C não:

- faz download/API de pacotes;
- consulta servidor para decidir o conteúdo ativo;
- integra bootstrap automático no arranque da app;
- altera UI;
- altera versão da aplicação;
- implementa outbox ou sincronização de progresso.

## Gate da Fase 2.1C

O incremento é aprovado quando:

- `flutter analyze` não reporta problemas;
- os testes 2.1A e 2.1B continuam verdes;
- primeira ativação produz `active` sem `previous`;
- ativar a versão seguinte preserva o antigo ativo como `previous`;
- reativação é idempotente;
- pacote inexistente/corrompido não substitui o ativo válido;
- leitura normal usa o ativo validado;
- corrupção do ativo promove automaticamente o `previous` válido;
- ativo sem fallback válido falha explicitamente;
- ativo e anterior inválidos não alteram os ponteiros existentes;
- a bateria completa não apresenta regressões.

## Resultado esperado da Fase 2.1 consolidada

Após aprovação de A+B+C, o dispositivo possui uma réplica SQLite operacional
com catálogo, importação íntegra, ativação atómica e preservação da última
versão válida. A rede continua fora do caminho crítico da aprendizagem.
