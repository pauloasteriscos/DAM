# DailyTalk.pt — Fase 2.2 — distribuição e atualização do conteúdo oficial

## Estado

Incremento consolidado 2.2A + 2.2B. Versão candidata da aplicação: **1.0.7+8**.

## Objetivo demonstrável

Alterar/publicar conteúdo oficial sem recompilar o Flutter e manter o percurso utilizável localmente depois da atualização.

```text
Flutter com packageVersion 1
        ↓
GET /api/content/catalog
        ↓
API anuncia packageVersion 2
        ↓
download de /api/content/packages/student.fr-fr.phase1/2
        ↓
headers + tamanho + SHA-256 + UTF-8
        ↓
LearningContentImportService
        ↓
SQLite learning_content_packages
        ↓
ativação transacional
        ↓
active = v2 / previous = v1
        ↓
leitura posterior somente da SQLite
```

## Pacote v2 de gate

O pacote `student.fr-fr.phase1` mantém todos os IDs e revisões publicadas na v1 e acrescenta uma nova revisão imutável para `arrival.vocabulary-01`:

- revisão anterior: `arrival.vocabulary-01.revision-01`;
- nova revisão: `arrival.vocabulary-01.revision-02`;
- `currentRevisionId` passa para `revision-02`;
- título PT-PT: `Palavras de acolhimento — edição revista`.

A API mantém a v1 disponível pelo endpoint imutável e o catálogo passa a anunciar apenas a versão mais recente para o percurso.

Metadados v2:

- schemaVersion: `1`;
- packageVersion: `2`;
- sizeBytes: `8043`;
- SHA-256: `c9f22e0fac4585aa90bb161ac609a3055e3f2fd11d0b16c3537b4c4068d77e0c`.

## Gates

### API

- `npm run typecheck`;
- `npm run test:api`;
- `npm run test:phase0`;
- catálogo anuncia v2;
- bytes de v2 correspondem ao hash publicado;
- v1 continua disponível e imutável;
- ETag/304 e cache imutável preservados.

### Flutter

- `flutter analyze`;
- testes 2.1 preservados;
- testes 2.2B preservados;
- suite completa;
- versão `1.0.7+8`.

### Gate cruzado real

Executar `scripts/phase2-distribution-gate.ps1`. O script inicia o Worker DEV na porta 8787 e executa `tool/phase2/learning_content_live_api_test.dart`, comprovando em processo real:

1. SQLite começa com v1 ativa;
2. Flutter consulta a API real;
3. API anuncia e entrega v2;
4. Flutter valida e importa v2;
5. v2 torna-se ativa e v1 passa a `previous`;
6. o cliente HTTP é fechado;
7. v2 continua carregável pela SQLite.

## Segurança das dependências Node

Na consolidação de 2026-09-09:

- `npm audit --omit=dev`: 0 vulnerabilidades;
- `npm audit`: 3 high apenas na cadeia de desenvolvimento `wrangler -> miniflare -> sharp`;
- `npm audit fix --force` não é aplicado porque propõe uma alteração breaking de Wrangler.

O detalhe e a decisão estão em `dailytalk-api/docs/phase2/PHASE2_SECURITY_AUDIT_2_2.md`.

## Feature flag

O refresh remoto permanece fail-closed e só é executado no arranque quando o build define:

`DAILYTALK_FEATURE_REMOTE_CONTENT_CATALOG=true`

O baseline local não depende dessa flag nem da rede. Para a publicação que pretenda disponibilizar esta capacidade, o build deve definir explicitamente a flag; não se altera o default para `true`.

## Fora do escopo

- política/cache de assets multimédia pesados;
- mapa dinâmico/UI de progressão;
- percurso oficial completo com 12–18 atividades;
- atividades comunitárias;
- sincronização de progresso.
