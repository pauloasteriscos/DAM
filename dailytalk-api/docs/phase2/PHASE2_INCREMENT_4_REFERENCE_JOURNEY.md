# Fase 2.4 — Percurso oficial de referência

## Objetivo

Fechar a Fase 2 com um percurso oficial suficientemente representativo para provar que o modelo de conteúdo, a distribuição remota, a réplica SQLite, a progressão por regras e os assets versionados funcionam em conjunto sem recompilar a aplicação Flutter.

O pacote oficial passa de `packageVersion=2` para `packageVersion=3`, preservando v1 e v2 de forma imutável.

## Percurso v3

Percurso: `student.fr-fr.phase1`

Estrutura:

- 1 jornada;
- 4 etapas;
- 16 atividades;
- 8 competências;
- 4 atividades de vocabulário;
- 4 atividades de diálogo;
- 4 atividades de fala;
- 2 quizzes;
- 1 revisão;
- 1 desafio integrado.

As quatro etapas são:

1. Chegar e apresentar-se;
2. Conhecer a casa;
3. Refeições e rotina;
4. Ganhar autonomia.

## Evolução imutável

`arrival.vocabulary-01` mantém as revisões 01 e 02 exatamente publicadas nas versões anteriores e recebe a nova revisão:

`arrival.vocabulary-01.revision-03`

A identidade lógica da atividade permanece estável e apenas `currentRevisionId` passa a apontar para a revisão 03.

## Percursos alternativos

A preferência do estudante apenas ordena recomendações. Não bloqueia os outros caminhos.

O percurso usa grupos `ANY` e competências para permitir alternativas. No bloco final, por exemplo, o desafio integrado exige domínio de horários e pedido de ajuda, mas a competência de ajuda pode ser obtida por diálogo ou fala. O caminho não escolhido permanece disponível.

## Conteúdo e integridade

Artefacto canónico:

`official_reference_journey_v3.json`

- schemaVersion: 1
- packageVersion externo: 3
- SHA-256: `9fc5142ad80c8e66979c8f3f5f547bb8071c4be09160b03a38cf2374eebb070b`
- tamanho: 25371 bytes

O Worker continua a servir os bytes exatos do pacote e os testes de integração comparam a resposta HTTP com o artefacto canónico versionado no repositório.

## Assets v3

O manifesto v3 publica 8 referências de assets distribuídas por 6 revisões. Dois novos blobs content-addressed são introduzidos e os blobs válidos da v2 são reutilizados.

O catálogo de assets publica metadata de todos os manifestos imutáveis ainda servidos, ordenando a versão mais recente primeiro dentro de cada percurso. Isto permite que um dispositivo cujo pacote ativo ainda seja v2 complete a hidratação dos respetivos assets mesmo depois de a API já anunciar v3, sem fallback silencioso nem perda de compatibilidade histórica.

Manifesto canónico:

`official_asset_manifest_v3.json`

- manifestVersion: 1
- packageVersion: 3
- SHA-256: `bccf2da598c07ec04ddebf66ea0dc665bc7237b5928cefa0082c888a231a7e80`
- tamanho: 3790 bytes

Novos blobs:

- PNG: `84ef8a15743479358e2f17fa5d7ddfac7f10e7e551aa53f08c01731a8257626a` — 340 bytes;
- WAV: `64a289d575381bcc248139fbd48f15549c5ebcab117238200163f0bcee45d813` — 5644 bytes.

Os blobs são fixtures leves de referência para validar o contrato técnico de associação, integridade, cache incremental e funcionamento offline. A produção visual/sonora definitiva não altera este contrato.

## Gate

O gate real demonstra:

`v2 local -> API v3 -> pacote com 16 atividades -> SQLite -> ProgressionEngine -> manifesto v3 -> reutilização/download incremental -> rede encerrada -> leitura local`.

Também verifica o fallback de asset da revisão 02 através do pacote previous depois de a v3 estar ativa.

Script:

`scripts/phase2-reference-journey-gate.ps1`

Teste Flutter real:

`tool/phase2/learning_content_reference_journey_live_api_test.dart`

Resultado esperado:

`Gate Fase 2.4 aprovado: v2 -> v3 -> 16 atividades -> progressão -> assets incrementais -> offline.`

## Versão candidata

- aplicação: `1.0.9+10`
- versão visível: `1.0.9`
- tag futura, apenas após CI verde: `v1.0.9`
