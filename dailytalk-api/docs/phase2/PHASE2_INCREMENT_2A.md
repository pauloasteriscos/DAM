# DailyTalk.pt — Fase 2.2A — API de distribuição de conteúdo oficial

## Objetivo

Criar o contrato HTTP mínimo e testável para a distribuição de pacotes oficiais de conteúdo sem recompilar a aplicação Flutter.

Esta subfase não altera o SQLite móvel, não ativa pacotes remotamente no Flutter e não publica ainda a release 2.2. A promoção para Git/produção só ocorre após a consolidação 2.2A + 2.2B.

## Contrato exposto

### `GET /api/content/catalog`

Resposta pública, mas sujeita à declaração de ambiente já exigida pela API (`X-DailyTalk-Environment`).

Formato v1:

```json
{
  "success": true,
  "catalogVersion": 1,
  "packages": [
    {
      "pathId": "student.fr-fr.phase1",
      "schemaVersion": 1,
      "packageVersion": 1,
      "sha256": "6d5bee9037aecaf70773e484076ad646d6b05d7f01bf0f00b8f5a70e798de968",
      "sizeBytes": 7024,
      "contentType": "application/json",
      "downloadPath": "/api/content/packages/student.fr-fr.phase1/1",
      "immutable": true
    }
  ]
}
```

O catálogo devolve apenas a versão mais recente conhecida de cada `pathId`. Versões anteriores continuam acessíveis pelo endpoint versionado enquanto fizerem parte do catálogo interno da API.

### `GET /api/content/packages/:pathId/:packageVersion`

Devolve os bytes exatos do pacote oficial.

Headers relevantes:

- `Content-Type: application/json; charset=utf-8`
- `Cache-Control: public, max-age=31536000, immutable`
- `ETag: "sha256-<hash>"`
- `X-Content-SHA256`
- `X-Content-Package-Version`
- `X-Content-Schema-Version`

O endpoint suporta `If-None-Match` e responde `304` quando o ETag coincide.

## Invariantes

1. `pathId + packageVersion` identifica uma publicação imutável.
2. O hash anunciado no catálogo corresponde aos bytes devolvidos pelo endpoint do pacote.
3. A versão `student.fr-fr.phase1 / packageVersion 1` usa exatamente os mesmos bytes LF já utilizados pela Fase 2.1 no mobile.
4. O pacote v1 tem SHA-256 `6d5bee9037aecaf70773e484076ad646d6b05d7f01bf0f00b8f5a70e798de968` e 7024 bytes.
5. Pacote inexistente responde `404`; identificadores/versões malformados respondem `400`.
6. O conteúdo oficial é público; autenticação de utilizador não é requisito para download.
7. A separação DEV/PRD continua obrigatória pelo header de ambiente já existente.
8. Respostas dinâmicas da API continuam `no-store` por defeito; apenas artefactos de conteúdo explicitamente imutáveis recebem cache longo.

## Implementação

O pacote v1 é incorporado no bundle do Worker como Base64. Esta decisão evita que CRLF/LF do checkout altere os bytes efetivamente servidos. O Worker descodifica para `Uint8Array` e devolve exatamente o payload canónico LF.

A publicação de novos pacotes nesta etapa continua a exigir uma alteração/deploy da API, mas não exige recompilar nem republicar o Flutter. Uma pipeline editorial/D1/R2 para publicação sem deploy da API fica fora do escopo da 2.2A.

## Testes acrescentados

`test/api.integration.test.mjs` passa de 18 para 22 subtestes e acrescenta gates para:

- metadata do catálogo;
- bytes e SHA-256 do pacote;
- headers de integridade e cache;
- ETag/`304 Not Modified`;
- erro explícito para pacote inexistente;
- exposição dos novos endpoints na raiz da API.

## Gate 2.2A

A subfase é aprovada quando, no DEV:

```text
npm run typecheck     -> OK
npm run test:api      -> OK
npm run test:phase0   -> OK
```

E uma chamada ao catálogo seguida do download do pacote comprova:

```text
metadata.sha256 == SHA256(bytes recebidos)
metadata.sizeBytes == tamanho dos bytes recebidos
JSON.id == metadata.pathId
```

## Fora do escopo

- cliente HTTP Flutter;
- deteção automática de versão remota;
- importação remota no SQLite;
- ativação remota/fallback no mobile;
- assets pesados;
- R2;
- endpoint administrativo/editorial de publicação;
- sincronização de progresso.

Esses pontos pertencem à 2.2B ou a incrementos posteriores.


## Nota de consolidação 2.2

A 2.2A foi inicialmente validada com `packageVersion=1`. No gate final da 2.2, a mesma infraestrutura passa a publicar `packageVersion=2` como latest, mantendo a v1 imutável e acessível pelo endpoint versionado. Esta alteração é intencional para demonstrar uma atualização real v1 → v2 sem recompilar o Flutter.
