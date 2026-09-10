# Fase 2.3 — Distribuição de assets oficiais

A API passa a publicar um catálogo de manifestos, manifestos imutáveis por
versão de pacote e blobs content-addressed por SHA-256.

## Endpoints

- `GET /api/content/assets/catalog`
- `GET /api/content/assets/manifests/:pathId/:packageVersion`
- `GET /api/content/assets/blobs/:sha256`

Manifestos e blobs usam `ETag: "sha256-..."` e
`Cache-Control: public, max-age=31536000, immutable`.

O catálogo permanece dinâmico e `no-store`.

## Referência v2

Manifesto:

- SHA-256: `d9ac2ce729a71cbacab669bb971c9511e340e0f7a140299ad80d5faee540aac9`
- tamanho: `1029` bytes

Imagem PNG:

- SHA-256: `572fb1b093c9214088f83edb705859b65c531d36e33f4d8df16596c1b614858a`
- tamanho: `179` bytes

Áudio WAV:

- SHA-256: `9dc3f6c0a6c0b8b7ecbad30db415c10cff8e504db988145ad74afd0e927c9b4c`
- tamanho: `4044` bytes

Os bytes de referência são incorporados em Base64 no Worker para manter
reprodutibilidade e independência de normalização de fim de linha. Esta é uma
implementação de distribuição pequena e determinística; o contrato
content-addressed não impede migrar blobs para R2/CDN quando o volume justificar.

## Política

Pacotes, manifestos e blobs publicados são imutáveis. Uma alteração de asset
gera novo SHA-256 e deve ser referenciada por um novo manifesto/pacote conforme
a evolução do conteúdo.

A API não faz fallback silencioso para hashes ou versões inexistentes.
