# LC-001 — Contrato de Localização e Separação de Idiomas

## Estado

Fundação v1.

## Papéis de localização

Todo texto visível pertence obrigatoriamente a um de três papéis:

1. **APP** — menus, botões, navegação, labels, estados, mensagens, erros e restante chrome da aplicação. Resolve por `appLanguageCode`.
2. **SCAFFOLDING** — instruções, dicas, explicações, feedback, ajuda e descrições pedagógicas que permitem compreender a tarefa. Resolve por `appLanguageCode`.
3. **TARGET** — palavras, frases, falas, respostas e demais conteúdo que o utilizador deve aprender, reconhecer ou produzir na língua-alvo. Resolve por `learningLanguageCode`.

Exemplo: `appLanguageCode=pt-PT` e `learningLanguageCode=de-DE`. A missão pode chamar-se **Begrüßungswörter** (TARGET), enquanto a instrução é **Associe cada expressão ao significado.** (SCAFFOLDING) e o botão é **Continuar** (APP).

## Invariantes

1. APP é resolvido exclusivamente por `appLanguageCode`.
2. SCAFFOLDING é resolvido exclusivamente por `appLanguageCode`.
3. TARGET é resolvido exclusivamente por `learningLanguageCode`.
4. Nenhum widget pode decidir ad hoc que locale usar; a política é centralizada por `LocalizationRole`.
5. Texto visível de interface não pode ser usado como identificador de tradução; a UI usa chaves semânticas estáveis (`common.continue`, `learningMap.nextMission`, etc.).
6. SQLite é a fonte persistente local dos bundles de UI, mas não participa no hot path de renderização: o locale ativo é carregado em memória e cada lookup é O(1).
7. Alterar `appLanguageCode` não altera `learningLanguageCode` e vice-versa.
8. Um bundle incompleto não pode ser ativado.
9. Cada `(locale, bundle_version)` é imutável.
10. A ativação é atómica e preserva `previous_bundle_version` como last-known-good para rollback.
11. O único fallback técnico permitido para UI/SCAFFOLDING é `en-US`; português nunca é fallback implícito para uma UI configurada noutro idioma.
12. Conteúdo TARGET oficial incompleto para o idioma-alvo é rejeitado pelo contrato de conteúdo, em vez de ser silenciosamente apresentado no idioma da interface.

## Política de campos pedagógicos

Campos equivalentes a `instructions`, `hint`, `prompt`, `scenarioDescription`, explicações e feedback são SCAFFOLDING, salvo contrato de schema explícito em contrário. Títulos de jornada/etapa/missão, vocabulário-alvo, falas do interlocutor, respostas linguísticas e frases a pronunciar são TARGET.

Cada novo tipo de runtime deve declarar a função de localização dos seus campos antes de ser considerado compatível com LC-001.

## Pipeline de runtime

`API/D1 -> bundle versionado -> SQLite -> carga bulk do locale ativo -> Map<String,String> em memória -> widget`

Mudanças normais de ecrã fazem zero queries de tradução. A base é lida quando o locale/bundle é carregado ou atualizado.

## Tabelas locais

- `ui_translation_bundles`
- `ui_translations`
- `ui_translation_catalog`

## Migração

A fundação LC-001.1 cria apenas infraestrutura. A aplicação atual continua funcional enquanto os ecrãs são migrados por incrementos para chaves semânticas. O mecanismo legado só pode ser removido quando o Quality Gate provar cobertura integral dos textos APP e SCAFFOLDING e a correta separação do TARGET.
