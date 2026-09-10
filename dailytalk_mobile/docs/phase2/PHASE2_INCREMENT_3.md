# Fase 2.3 — Assets oficiais orientados por dados

## Objetivo

A Fase 2.3 acrescenta distribuição, integridade, cache e resolução offline de
assets multimédia associados a revisões imutáveis do conteúdo oficial, sem
alterar o schema v1 do `LearningPath`.

A rede continua fora do caminho crítico da aprendizagem. O JSON do percurso
continua a ser a autoridade sobre atividades/revisões; o manifesto de assets é
um artefacto separado e imutável, associado a `(learningPathId, packageVersion)`.

## Contrato

A API publica:

- `GET /api/content/assets/catalog`
- `GET /api/content/assets/manifests/:pathId/:packageVersion`
- `GET /api/content/assets/blobs/:sha256`

Os blobs usam endereçamento por conteúdo (`SHA-256`) e cache HTTP imutável.
O manifesto associa `assetId`, `revisionId`, `role`, MIME type, SHA-256,
tamanho, URL e obrigatoriedade.

Manifesto oficial de referência:

- percurso: `student.fr-fr.phase1`
- packageVersion: `2`
- manifestVersion: `1`
- tamanho: `1029` bytes
- SHA-256: `d9ac2ce729a71cbacab669bb971c9511e340e0f7a140299ad80d5faee540aac9`

Assets de referência:

- imagem PNG: `572fb1b093c9214088f83edb705859b65c531d36e33f4d8df16596c1b614858a` (179 bytes)
- áudio WAV: `9dc3f6c0a6c0b8b7ecbad30db415c10cff8e504db988145ad74afd0e927c9b4c` (4044 bytes)

Os dois assets pertencem a `arrival.vocabulary-01.revision-02`.

## SQLite v5

A migração v4 -> v5 é aditiva e cria:

- `learning_content_asset_manifests`
- `learning_content_asset_entries`
- `learning_content_asset_cache`

Os bytes são guardados como BLOB content-addressed por SHA-256. Esta opção
mantém a implementação imediatamente multiplataforma (Android/iOS/desktop/Web
com a infraestrutura SQLite atual) e evita introduzir uma segunda persistência
de ficheiros antes de existir necessidade real. O contrato permite trocar a
implementação binária por armazenamento externo no futuro.

## Integridade e segurança

Antes de persistir/usar um asset remoto, o cliente valida:

1. ambiente da resposta;
2. contrato e versão do catálogo;
3. associação do manifesto ao pacote ativo;
4. UTF-8 e SHA-256 do manifesto;
5. existência de cada `revisionId` no pacote de aprendizagem validado;
6. allowlist de MIME types;
7. URL content-addressed exata;
8. headers, tamanho e SHA-256 de cada blob.

O manifesto só é publicado localmente depois de todos os assets obrigatórios
estarem íntegros. Um erro de rede ou blob adulterado não troca o manifesto
válido e não sobrescreve bytes até a nova cópia passar pela validação.

## Cache incremental e retenção

Uma segunda atualização reutiliza blobs locais cujo tamanho, MIME type e
SHA-256 continuam válidos. Não ocorre novo download desses blobs.

A limpeza protege todos os pacotes `active` e `previous` presentes no catálogo
local. Manifestos de versões mais antigas e blobs que deixaram de ser
referenciados podem ser removidos. Os pacotes JSON históricos não são apagados.

## Fallback offline

`resolveAsset()` não acede à rede. Primeiro tenta o pacote ativo. Se o asset
não estiver disponível/íntegro, pode procurar no pacote `previous`, mas apenas
para a mesma combinação `revisionId + role`. Isso impede usar multimédia de uma
revisão semanticamente diferente como fallback silencioso.

## Feature flag

Novo build flag:

`DAILYTALK_FEATURE_REMOTE_CONTENT_ASSETS`

A flag falha fechada: assets remotos só ficam efetivamente ativos quando
`DAILYTALK_FEATURE_REMOTE_CONTENT_CATALOG` também estiver ativo.

## Gate da Fase 2.3

O gate real deve demonstrar:

`content v1 -> content v2 -> manifesto -> imagem/áudio -> SQLite -> segunda
atualização sem redownload -> cliente HTTP fechado -> leitura local íntegra`.

Script:

`scripts/phase2-assets-gate.ps1`

Teste real:

`tool/phase2/learning_content_asset_live_api_test.dart`

Resultado esperado:

`Gate Fase 2.3 aprovado: manifest -> assets -> cache incremental -> leitura offline.`

## Versão candidata

- aplicação: `1.0.8+9`
- versão visível: `1.0.8`
- tag futura, somente após CI verde: `v1.0.8`

## Fora do escopo

A Fase 2.3 não implementa player de áudio, widgets finais de imagem, CDN/R2,
conteúdo pedagógico completo nem o novo mapa visual. A ligação visual de assets
a ~12–18 atividades reais pertence à Fase 2.4.
