# DailyTalk.pt — Fase 2.2B — atualização remota no Flutter

## Objetivo

Ligar o contrato público criado na Fase 2.2A à réplica SQLite criada na Fase 2.1, sem colocar a rede no caminho crítico da aprendizagem.

O Flutter passa a conseguir consultar o catálogo oficial, selecionar a versão mais recente de um percurso, descarregar os bytes publicados, validar metadata/headers/tamanho/SHA-256, importar o pacote pelo `LearningContentImportService` e ativá-lo pelo `LearningContentCatalogService`.

A leitura durante a aprendizagem continua exclusivamente local através de `LearningContentCatalogService.loadActive`.

## Fluxo

```text
GET /api/content/catalog
        ↓
metadata imutável do percurso
        ↓
comparação monotónica com versão local ativa
        ↓
GET /api/content/packages/:pathId/:packageVersion
        ↓
ambiente + headers + tamanho + SHA-256 sobre bytes
        ↓
UTF-8 canónico
        ↓
LearningContentImportService
        ↓
SQLite learning_content_packages
        ↓
LearningContentCatalogService.activate
        ↓
active_package_id / previous_package_id
```

## Invariantes preservadas

- `packageVersion` nunca é reutilizada localmente com outro hash;
- catálogo remoto atrasado não provoca downgrade;
- download inválido nunca muda o ponteiro ativo;
- falha de rede não remove nem invalida o conteúdo já utilizável offline;
- pacote já importado com o mesmo hash não é descarregado novamente;
- a troca de versão continua transacional e preserva a versão anterior;
- o SHA-256 remoto é verificado sobre os bytes recebidos antes do JSON ser interpretado;
- metadata, headers HTTP e conteúdo validado têm de concordar sobre percurso, schema, versão e hash;
- o `downloadPath` tem de corresponder exatamente ao percurso e à versão publicados.

## Ficheiros

- `lib/data/content/learning_content_remote.dart` — cliente/orquestrador da distribuição oficial;
- `lib/data/content/learning_content_bootstrap.dart` — garante baseline local antes da rede;
- `lib/data/content/content_data.dart` — exporta as novas fronteiras;
- `lib/main.dart` — bootstrap local e refresh remoto pós-arranque sob feature flag;
- `test/data/content/learning_content_remote_test.dart` — gate end-to-end HTTP simulado + SQLite;
- `test/data/content/learning_content_bootstrap_test.dart` — baseline offline idempotente;
- `docs/phase2/PHASE2_INCREMENT_2B.md` — este registo.

## Testes específicos

A bateria 2.2B cobre:

1. download + validação + importação + ativação inicial;
2. idempotência sem novo download da mesma versão;
3. promoção de v2 preservando v1 como anterior;
4. rejeição de bytes com SHA-256 divergente;
5. rejeição de headers incoerentes;
6. rejeição de JSON/schema inválido sem substituir o ativo;
7. rejeição de contrato de catálogo não suportado;
8. proteção contra downgrade quando a API está atrasada;
9. funcionamento offline do conteúdo local após falha de rede;
10. bootstrap local idempotente a partir do pacote embarcado;
11. bootstrap prefere a versão local mais recente e não faz downgrade.

O refresh remoto em runtime é disparado somente quando `DAILYTALK_FEATURE_REMOTE_CONTENT_CATALOG=true`; o baseline local é sempre preparado sem rede.

## Fora do escopo

- UI do mapa dinâmico;
- assets multimédia pesados e respetiva política de cache;
- atividades comunitárias;
- sincronização de progresso;
- publicação/tag/release isolada da 2.2B.

A 2.2A e a 2.2B serão consolidadas e publicadas juntas no fecho da Fase 2.2.
