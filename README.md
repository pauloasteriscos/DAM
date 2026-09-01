# DailyTalk.pt

**Engenharia informática aplicada a um problema real de mobilidade escolar.**

DailyTalk.pt é uma plataforma educativa criada para ajudar crianças e jovens em mobilidade Erasmus+ a comunicar melhor em situações do dia a dia: chegada, acolhimento, refeições, rotina, instruções, cultura e interação com famílias e colegas.

O projeto é também uma demonstração prática de como conhecimentos adquiridos ao longo do **Mestrado em Engenharia Informática e Tecnologia Web (MEIW), em associação entre a Universidade Aberta (UAb) e a Universidade de Trás-os-Montes e Alto Douro (UTAD)** podem ser combinados para transformar uma necessidade real numa solução progressivamente mais completa, segura, robusta e preparada para produção.

> Os conteúdos e as aprendizagens foram vastos, mas foram selecionados criteriosamente e aplicados apenas quando faziam sentido para o problema. O objetivo nunca foi implementar tecnologia por implementar. Cada decisão técnica existe para resolver um problema concreto de forma sólida e robusta: aprender melhor, funcionar offline, responder rapidamente, proteger sessões, evitar perda de progresso, permitir evolução segura e manter o sistema compreensível e sustentável.

---

## Uma solução construída por conhecimento acumulado

O DailyTalk evoluiu ao longo de diferentes unidades curriculares, cada uma contribuindo com conhecimentos específicos e acrescentando uma nova camada ao mesmo projeto.

| Área / Unidade Curricular | Contributo para o DailyTalk |
|---|---|
| **DSD - Desenvolvimento de Jogos Digitais** | Transformação de uma dificuldade real de comunicação em conceito de Serious Game, com aprendizagem por atividades e motivação através de mecânicas de jogo. |
| **PWA - Programação Web Avançada** | Primeiro protótipo Web, consolidação da presença online e aquisição do domínio **DailyTalk.pt**. |
| **APS - Arquitetura e Padrões de Software** | Evolução para uma arquitetura mais organizada, separação de responsabilidades, aplicação de padrões e registo de decisões arquiteturais. |
| **DAM - Desenvolvimento de Aplicações Móveis** | Transformação da solução em aplicação Flutter multiplataforma, integração mobile/Web, persistência local e evolução da experiência em dispositivos móveis. |
| **IPC / UX - Interação Pessoa-Computador** | Refinamento da experiência de utilização, acessibilidade, feedback, clareza visual, interação e desenho centrado no utilizador. |
| **Segurança, redes e sistemas** | Proteção de sessões e sincronização, gestão de chaves, proteção contra replay, confidencialidade, integridade e autenticação forte. |
| **Cloud e sistemas distribuídos** | Cloudflare Workers, D1, deployment, separação de ambientes, observabilidade, migrações e operação remota. |
| **Planeamento e arquitetura de sistemas** | Decisões de evolução, documentação técnica, rastreabilidade, qualidade, rollback e preparação para crescimento sustentável. |

O resultado é um projeto em que **produto, arquitetura, segurança, dados, UX, cloud e qualidade não são áreas isoladas**. São partes de uma mesma solução.

---

## O problema que queremos resolver

Aprender vocabulário não é suficiente quando o utilizador precisa de comunicar numa situação real.

O DailyTalk procura reduzir essa distância entre “estudar uma língua” e **conseguir usá-la quando é necessário**.

A plataforma foi pensada para situações como:

- chegar a uma nova casa;
- apresentar-se;
- compreender regras e rotinas;
- participar numa refeição;
- pedir ajuda;
- interpretar instruções;
- lidar com pequenas diferenças culturais;
- ganhar confiança antes e durante a mobilidade.

A tecnologia serve esse objetivo. Por isso a aplicação foi desenhada para continuar útil mesmo quando a ligação à Internet é lenta, instável ou inexistente.

---

## Engenharia orientada a produção

A arquitetura base do projeto consolidou uma baseline técnica estável e verificável.

A arquitetura atual combina:

```text
Flutter mobile/Web
        +
SQLite offline-first
        +
Cloudflare Workers
        +
Cloudflare D1
        +
CI / Quality Gate
        +
segurança de sessão e sincronização
```

### Offline-first

O progresso deve continuar a funcionar localmente.

```text
utilizador executa atividade
        ↓
estado é persistido localmente
        ↓
desbloqueio ocorre imediatamente
        ↓
sincronização acontece fora do caminho crítico
```

A rede não deve decidir se o utilizador pode continuar a aprender.

### Segurança em profundidade

A sincronização segura utiliza múltiplas camadas complementares:

```text
TLS
+ DPoP
+ JWS
+ JWE
+ ECDH-ES / X25519
+ AES-256-GCM
+ anti-replay
+ idempotência
```

O objetivo é responder a riscos reais através de uma arquitetura de segurança em profundidade. A solução combina criptografia assimétrica para estabelecimento de chaves e assinaturas com criptografia simétrica autenticada para proteger os dados com elevado desempenho, complementada por DPoP, mecanismos anti-replay e controlo de idempotência:

```text
roubo de token
→ binding da sessão ao dispositivo

replay de pedidos
→ jti / sequence / controlo anti-replay

alteração do conteúdo
→ assinatura e autenticação

interceção do payload
→ cifragem autenticada

reenvio de operações
→ idempotência
```

Essa disciplina de engenharia é transferível para outros domínios em que **confiança, integridade, rastreabilidade e proteção de dados** são requisitos centrais, incluindo setores financeiros, governamentais e empresariais.

---

## Qualidade verificável

O projeto possui um Quality Gate permanente no GitHub Actions, implementado desde o início da preparação da base para produção e que será progressivamente reforçado à medida que o projeto evoluir:

```text
CI - Quality Gate
├── API - Typecheck, Security & Tests
└── Flutter - Analyze & Tests
```

Baseline validada no encerramento da Fase 0:

```text
API integração     19/19
Segurança          22/22
D1 migrations       7/7
API total          48/48

Flutter tests      25/25
flutter analyze    0 issues
npm audit          0 vulnerabilidades
```

A CI não faz deploy e não recebe secrets de produção. O objetivo é validar código antes de permitir que novas funcionalidades se tornem parte da baseline.

---

## Dados e evolução sem perda de progresso

A aplicação usa SQLite localmente e Cloudflare D1 remotamente.

As alterações de schema são controladas por migrations incrementais.

```text
0001_baseline.sql
```

já foi publicada e é tratada como **imutável**.

Qualquer evolução futura deve ser feita por novas migrations:

```text
0002_...
0003_...
...
```

Esse cuidado reduz o risco de atualizações destrutivas e ajuda a preservar dados de utilizadores existentes.

---

## Novas funcionalidades entram protegidas

Funcionalidades em evolução são introduzidas através de Feature Flags fail-closed.

```text
REMOTE_CONTENT_CATALOG
PROGRESSION_ENGINE_V2
DYNAMIC_LEARNING_MAP
COMMUNITY_ACTIVITIES
```

Isso permite desenvolver e validar componentes novos sem expor automaticamente funcionalidades incompletas.

---

## Arquitetura documentada

As decisões importantes são registadas em ADRs - Architecture Decision Records:

```text
docs/adr/
```

Entre as decisões já formalizadas estão:

- offline-first e SQLite como fonte local operacional;
- sessão persistente por dispositivo;
- DPoP;
- sincronização segura JWS/JWE;
- idempotência e proteção anti-replay;
- migrations D1 incrementais;
- Feature Flags fail-closed;
- desbloqueio local imediato;
- `activityId` estável e `revisionId` imutável;
- Progression Engine separado da interface.

---

## Próxima evolução: núcleo de aprendizagem

Com a fundação técnica estabilizada, o próximo foco é a evolução do sistema pedagógico.

```text
Modelo de domínio
        ↓
Schema de conteúdo e progresso
        ↓
Progression Engine em Dart puro
        ↓
Desbloqueio local imediato
        ↓
Conteúdo orientado por dados
        ↓
Percursos alternativos
        ↓
Mapa de aprendizagem dinâmico
        ↓
Sincronização multi-dispositivo
        ↓
Atividades criadas pela comunidade
```

O objetivo é permitir percursos diferentes — por exemplo, maior foco em vocabulário, diálogo ou fala — sem comprometer a progressão global do aluno.

---

## Estrutura do repositório

```text
DAM/
├── .github/
│   └── workflows/
│       └── ci-quality-gate.yml
├── dailytalk-api/
├── dailytalk_mobile/
├── docs/
│   ├── adr/
│   ├── operations/
│   └── quality/
├── scripts/
└── README.md
```

### `dailytalk_mobile`

Aplicação Flutter mobile/Web, SQLite local, experiência offline-first e interface de aprendizagem.

### `dailytalk-api`

Cloudflare Workers + Hono + D1, autenticação, sessões, persistência e sincronização segura.

### `docs/adr`

Decisões arquiteturais.

### `docs/quality`

Quality Gate e CI.

### `docs/operations`

Procedimentos de release e rollback.

---

## O que este projeto pretende demonstrar

DailyTalk.pt é uma aplicação educativa, mas o valor técnico do projeto vai além do seu domínio funcional.

Ele procura demonstrar, de forma prática, competências em:

```text
engenharia de software
arquitetura
mobile
Web
offline-first
bases de dados
cloud
segurança aplicada
criptografia
UX
testes
CI
migrations
rollback
documentação
evolução incremental
```

Mais importante: procura mostrar **como essas competências podem trabalhar juntas para resolver um problema real**.

Esse é também um dos maiores valores de um percurso avançado em Engenharia Informática: não apenas conhecer tecnologias isoladas, mas saber escolher, combinar, justificar e operar soluções adequadas ao problema.

---

O projeto continua em evolução.
