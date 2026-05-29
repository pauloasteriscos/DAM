# DailyTalk.pt Mobile

Aplicação móvel desenvolvida em Flutter para o projeto **Erasmus DailyTalk.pt**, no âmbito da unidade curricular **DAM - Desenvolvimento de Aplicações Móveis**.

O objetivo da aplicação é apoiar crianças e jovens em mobilidade escolar, normalmente entre os 11 e os 15 anos, na prática de comunicação em situações reais do quotidiano escolar, através de atividades gamificadas como vocabulário, áudio, diálogos, quizzes e desafios.

Esta versão contempla a evolução até à **Sprint 4**, incluindo a estrutura inicial da aplicação, navegação, Home gamificada, base de dados local SQLite, configuração de atividades, submissão de respostas, apresentação de resultados, integração com backend real, autenticação de utilizadores, sincronização entre mobile e Web, publicação em Cloudflare, aplicação progressiva de padrões de software, refinamento visual/UX dos principais fluxos e implementação inicial de atividades gamificadas concretas para vocabulário, quiz, diálogo e revisão.

---

## Estado atual da aplicação

A aplicação já possui:

- projeto Flutter configurado;
- navegação inferior entre páginas principais;
- Home gamificada inspirada em progressão por atividades;
- mapa de atividades com diferentes tipos e formas geométricas;
- ligação dos nós da Home gamificada a ecrãs específicos de atividade;
- ecrã de vocabulário no formato **Combina pares**;
- ecrã de **Quiz** contextualizado com perguntas e alternativas;
- ecrã de **Diálogo** guiado para simulação de conversas;
- ecrã de **Revisão** para reforço de conteúdos já praticados;
- separação entre o fluxo principal de prática e a criação secundária de atividades;
- menu superior com opções como Language, criar atividade, minhas atividades, sincronizar, ajuda e sobre;
- página de configuração linguística com dois idiomas:
  - idioma habitual do aluno;
  - idioma que o aluno pretende aprender;
- utilização automática dos idiomas definidos no perfil nos ecrãs de prática;
- suporte a perfis de utilização:
  - Estudante;
  - Anfitrião;
  - Professor;
- estrutura SQLite local usando sqflite;
- página de configuração e criação de atividade;
- fluxo de submissão de respostas;
- gravação local de atividades, submissões e resultados;
- página de resultados com histórico de pontuações e estado de sincronização;
- estrutura inicial de sincronização de submissões pendentes;
- atualização automática da área de resultados após submissões ou sincronizações;
- integração com backend real em Cloudflare Workers;
- persistência remota em Cloudflare D1;
- autenticação básica com conta de utilizador;
- armazenamento seguro de token na app;
- validação de sessão contra a API;
- preferências associadas ao utilizador autenticado;
- submissões associadas ao utilizador autenticado;
- possibilidade de testar escrita em mobile e leitura na Web, e vice-versa;
- recuperação de palavra-passe em modo protótipo/debug;
- reformulação visual dos ecrãs de entrada, criação de conta, recuperação de palavra-passe, seleção de idioma, configuração de atividade, atividade/desafio, resultados/análises, conta, ajustes e notas privadas;
- aplicação da identidade visual escura/azul do DailyTalk.pt aos novos ecrãs de atividade;
- aplicação inicial dos padrões Strategy, Factory simples, Facade, Command e Observer.

---

## Identidade visual e publicação

Durante a Sprint 3 foi criada e adicionada uma logo inicial para a aplicação, baseada nas letras **DTK**, representando o nome **DailyTalk.pt**.

Na Sprint 4, a identidade visual foi revista para melhorar a perceção inicial do produto nos primeiros segundos de utilização. O ecrã de entrada deixou de ter um aspeto genérico e passou a apresentar uma composição visual própria, com marca DailyTalk.pt, mascote, elementos de fala, livro e rodapé decorativo. Esta alteração teve como objetivo comunicar de forma imediata que a aplicação é um serious game para aprendizagem de idiomas em contexto de mobilidade escolar.

Foram adicionados ou consolidados assets visuais em `assets/branding/`, nomeadamente:

- `dailytalk_login_hero.png`;
- `dailytalk_login_footer.png`;
- `dailytalk_mascot.png`.

A mesma linguagem visual foi depois aplicada progressivamente a outros ecrãs, mantendo ícones neutros nos campos de formulário e reservando o azul para marca, foco e ações principais. Essa coerência visual foi também usada nos ecrãs de prática, nomeadamente vocabulário, quiz, diálogo e revisão, com fundo escuro, cartões arredondados, destaques em azul/ciano, feedback imediato e organização adequada a dispositivos móveis e Web.

O domínio **dailytalk.pt** foi migrado do provedor anterior, Locaweb, para a Cloudflare. Esta alteração foi realizada porque a evolução do protótipo passou a exigir maior agilidade de publicação, suporte a HTTPS, menor latência e melhor controlo sobre a publicação da versão Web e da API.

A versão publicada pode ser testada através de:

- `https://dailytalk.pt`
- `https://dailytalk.pt/web`
- `https://dailytalk.pt/api/health`

No LUMI foi criado um botão **Teste agora**, apontando para a versão Web da aplicação Flutter. Com isso, o fluxo de demonstração ficou mais direto: o utilizador acede à página de apresentação, clica para testar e entra na versão Web do DailyTalk.pt.

---

## Objetivo do projeto

O DailyTalk.pt Mobile será gratuito e pretende disponibilizar uma experiência educativa móvel, interativa e gamificada, permitindo que crianças e jovens pratiquem comunicação em diferentes contextos escolares e interculturais, como:

- sala de aula;
- apresentações escolares;
- conversas informais;
- situações de integração no colégio;
- chegada a uma casa de acolhimento;
- comunicação com anfitriões;
- vocabulário do quotidiano;
- diálogos guiados;
- compreensão oral;
- quizzes de reforço.

A aplicação foi pensada para funcionar com apoio de um backend, mas também com suporte local básico através de SQLite, preparando a app para cenários de conectividade instável.

---

## Público-alvo

O DailyTalk.pt Mobile é orientado para crianças e jovens, normalmente entre os 11 e os 15 anos, em contexto escolar ou de intercâmbio.

O foco da aplicação não é o ensino superior nem o contexto universitário. A aplicação pretende apoiar situações reais que podem ocorrer no quotidiano escolar, em casa de acolhimento, em atividades do colégio ou em interações com colegas, professores e anfitriões.

---

## Configuração linguística

A aplicação não trabalha apenas com um idioma. O aluno define dois idiomas:

- o idioma que utiliza normalmente;
- o idioma que pretende aprender ou praticar.

Por exemplo, um aluno pode usar Português como idioma habitual e escolher Italiano como idioma de aprendizagem.

Esta separação é importante porque os exercícios, diálogos e atividades podem ser preparados considerando a relação entre o idioma conhecido pelo aluno e o idioma que pretende praticar.

A opção aparece como **Language** no menu, por ser uma designação reconhecível internacionalmente mesmo para alunos de diferentes países.

Nos ecrãs de prática foi adotada a seguinte regra:

- interface, instruções, cenários, perguntas e feedback aparecem no idioma habitual do aluno;
- respostas, falas, cartões principais e alternativas aparecem no idioma que o aluno pretende aprender ou praticar.

Desta forma, se o aluno escolher Português como idioma habitual e Italiano como idioma de aprendizagem, o contexto e a pergunta surgem em Português, enquanto as respostas ou frases de prática surgem em Italiano.

---

## Atividades gamificadas implementadas

A aplicação passou a incluir ecrãs próprios para algumas atividades centrais do mapa gamificado. Estes ecrãs foram desenhados para funcionar como protótipos jogáveis, mantendo a identidade visual do DailyTalk.pt e usando os idiomas definidos pelo utilizador no perfil.

### Vocabulário — Combina pares

A atividade de vocabulário apresenta um exercício de associação de pares. O objetivo é ligar palavras ou expressões do DailyTalk.pt no idioma habitual do aluno às respetivas equivalências no idioma que está a aprender.

O conteúdo foi pensado para situações do quotidiano escolar e intercultural, evitando palavras soltas sem relação com o propósito da aplicação.

### Quiz

A atividade de Quiz apresenta perguntas contextualizadas em situações reais, como pedir ajuda na escola, comunicar com colegas, compreender instruções ou responder em contexto de acolhimento.

A pergunta e o cenário são apresentados no idioma habitual do aluno. As alternativas de resposta são apresentadas no idioma a praticar, reforçando a aprendizagem ativa.

### Diálogo

A atividade de Diálogo simula pequenas conversas guiadas, com foco em situações de comunicação prática. O aluno acompanha o contexto no seu idioma habitual e pratica as falas no idioma de aprendizagem.

Esta abordagem prepara o aluno para interações reais com colegas, professores ou anfitriões.

### Revisão

A atividade de Revisão funciona como reforço dos conteúdos trabalhados. Apresenta cartões e exercícios curtos para consolidar vocabulário, frases úteis e expressões frequentes.

O cartão principal surge no idioma a praticar, enquanto o apoio, significado ou feedback aparecem no idioma habitual do aluno.

---

## Perfis de utilização

A Sprint 3 consolidou a orientação da aplicação para perfis diferenciados de utilização.

### Estudante

O perfil **Estudante** é orientado para crianças e jovens que pretendem praticar uma língua em situações reais, como responder a perguntas, pedir informações, compreender horários, falar sobre alimentação ou interagir no contexto escolar.

### Anfitrião

O perfil **Anfitrião** é orientado para pessoas que recebem estudantes em mobilidade escolar. O objetivo é apoiar a preparação de frases de acolhimento, instruções simples, perguntas úteis e comunicação inicial.

Este perfil ganhou destaque porque o DailyTalk.pt não pretende apoiar apenas o aluno visitante, mas também a pessoa que o recebe.

### Professor

O perfil **Professor** é previsto para acompanhamento pedagógico, sugestão de atividades, validação de conteúdos e consulta de dificuldades frequentes.

Nesta versão, o perfil Professor ainda é uma base funcional/prototipada, ficando a sua exploração completa para evolução futura.

---

## Modelo de atividades e participação da comunidade

O DailyTalk.pt Mobile prevê disponibilizar atividades educativas de dois tipos principais: atividades criadas pela equipa da aplicação e atividades criadas pela própria comunidade de utilizadores.

As atividades criadas pela equipa funcionam como conteúdos base, garantindo que o aluno tem sempre acesso a exercícios estruturados, alinhados com os objetivos pedagógicos da aplicação e adequados ao contexto de comunicação escolar e intercultural.

Além disso, o aluno poderá criar as suas próprias atividades com base nas dificuldades que encontra durante a aprendizagem. Por exemplo, se tiver dificuldades em vocabulário, diálogos do quotidiano escolar, compreensão oral ou situações específicas de comunicação, poderá propor uma nova atividade para praticar esse conteúdo.

As atividades criadas pelos alunos poderão ficar disponíveis para a comunidade, mas apenas após uma validação prévia. Esta validação será apoiada por mecanismos de IA e pela equipa mantenedora da aplicação, de forma a garantir que os conteúdos são adequados, seguros, compreensíveis e pedagogicamente úteis.

Depois de aprovadas, as atividades passam a poder ser utilizadas por outros jogadores. A comunidade poderá interagir com essas atividades através de mecanismos de avaliação, como o botão **Gostei**. Quanto mais avaliações positivas uma atividade receber, maior será a sua relevância dentro da aplicação, podendo subir no ranking e passar a ser mais recomendada a outros utilizadores.

O jogador que criou uma atividade bem avaliada será recompensado com pontos. Estes pontos poderão ser usados futuramente numa loja interna da aplicação, para trocar por skins, elementos visuais e outros itens de personalização. Além disso, o criador poderá subir de nível na sua reputação geral como ajudante da comunidade, incentivando a criação de conteúdos úteis e colaborativos.

As atividades também poderão ser rejeitadas pela comunidade. Nestes casos, ficarão numa lista de revisão para análise da equipa mantenedora da aplicação, que poderá decidir reformular, corrigir ou excluir definitivamente a atividade. Desta forma, procura-se equilibrar a liberdade de criação da comunidade com a qualidade, segurança e utilidade pedagógica dos conteúdos disponibilizados.

---

## Backend e sincronização

Na Sprint 3 foi realizada a integração com um backend real, permitindo que a aplicação deixe de funcionar apenas de forma local/mockada.

A arquitetura atual contempla:

- aplicação Flutter mobile/Web;
- API em Cloudflare Workers;
- base de dados remota Cloudflare D1;
- autenticação com JWT;
- armazenamento seguro do token na aplicação;
- sincronização de preferências e submissões;
- utilização de SQLite local para cache, histórico e suporte offline básico.

O backend disponibiliza endpoints para:

- registo de utilizador;
- login;
- consulta da sessão autenticada;
- atualização de preferências;
- envio de submissões de atividades;
- consulta das submissões do utilizador autenticado;
- recuperação de palavra-passe em modo protótipo/debug.

Esta integração permite realizar testes de escrita na aplicação mobile e consulta na Web, ou o inverso, desde que seja utilizada a mesma conta de utilizador.

Exemplo de fluxo suportado:

1. o utilizador faz login no Android;
2. realiza uma atividade;
3. a submissão é enviada para a API;
4. o utilizador abre a versão Web;
5. faz login com a mesma conta;
6. consulta as submissões associadas ao perfil autenticado.

---

## Controlo de utilizador e segurança

Foi criado um modo básico de conta de utilizador para efeitos de teste do protótipo. Para esta implementação foram reaproveitados conceitos já explorados anteriormente no projeto Animalec, nomeadamente:

- criação de utilizador;
- autenticação;
- sessão;
- associação de dados a uma conta;
- validação de acesso a rotas protegidas.

Com esta evolução, a aplicação passou de uma experiência genérica para uma experiência personalizada por perfil de utilizador.

A versão atual inclui:

- registo de conta;
- login;
- validação de password no backend;
- token JWT;
- armazenamento seguro do token no cliente;
- validação da sessão através do endpoint `/api/me`;
- limpeza de sessão inválida;
- preferências associadas ao utilizador;
- submissões associadas ao utilizador autenticado;
- logout;
- recuperação de palavra-passe em modo protótipo/debug.

Este ponto de controlo de utilizador deverá receber atenção especial quando o projeto sair da fase de protótipo, principalmente em questões como:

- autenticação multifator;
- integração com Authenticator;
- verificação de email;
- políticas de password;
- proteção contra abuso de pedidos;
- envio real de emails transacionais;
- auditoria de sessão;
- gestão de permissões por perfil.

---

## Recuperação de palavra-passe

Foi implementado o fluxo **Esqueci a palavra-passe**.

Durante a implementação, verificou-se que o **Cloudflare Email Sending**, necessário para envio programático de emails transacionais a partir de Workers, está disponível apenas no plano **Workers Paid**.

Como o projeto se encontra em fase de protótipo, foi adotada uma solução de debug:

1. a API recebe o pedido de recuperação;
2. gera um código temporário;
3. guarda o hash do código na D1;
4. define uma validade temporária;
5. quando `PASSWORD_RESET_DEBUG=true`, devolve o código à aplicação;
6. a aplicação permite introduzir o código e definir nova palavra-passe.

Esta solução permite demonstrar todo o fluxo de recuperação de palavra-passe, mas não substitui uma recuperação real por email em produção.

Numa versão futura, este fluxo deverá ser substituído por:

- Cloudflare Email Sending com Workers Paid; ou
- serviço externo de email transacional, como Resend, Brevo, SendGrid ou equivalente.

---

## Usabilidade e feedback de testes

Durante os testes da Sprint 3 foram identificados ajustes de usabilidade.

Um dos pontos observados foi a ausência do ícone de visualização da palavra-passe nos ecrãs de login e criação de conta. Para resolver isto, foi implementado um botão com ícone de “olhinho”, permitindo alternar entre mostrar e ocultar a palavra-passe.

Também foram ajustados:

- mensagens de erro de login;
- comportamento de sessão inválida;
- navegação entre login e registo;
- fluxo de recuperação de palavra-passe;
- retorno para o ecrã de login após logout;
- validação de token antes de abrir a navegação principal;
- comportamento de conta quando a sessão não existe.

Na Sprint 4 foi realizado um refinamento visual e de interação nos principais fluxos da aplicação. O objetivo foi tornar a interface mais consistente, reduzir ambiguidades visuais e reforçar a comunicação da proposta de valor.

Foram revistos:

- ecrã de login, com reforço da identidade visual e proposta de valor;
- ecrã de criação de conta, com título mais direto e mascote compacta;
- recuperação e redefinição de palavra-passe;
- seleção de idioma;
- seleção de perfil;
- configuração de atividade;
- tela de atividade/desafio;
- resultados e análises;
- conta do utilizador;
- ajustes;
- notas privadas;
- estrutura visual de páginas internas.

A Home gamificada foi mantida sem alteração estrutural significativa, por já possuir identidade própria e comunicar bem a progressão por atividades.

---

## Padrões de software incorporados

Para melhorar a organização do código e preparar a aplicação para evolução futura, foram incorporados alguns padrões de software de forma progressiva e controlada.

A aplicação destes padrões teve como objetivo reduzir acoplamento, evitar repetição de lógica, melhorar a separação de responsabilidades e facilitar a evolução do protótipo.

### Strategy

Foi aplicado o padrão **Strategy** aos tipos de atividade da aplicação.

Cada tipo de atividade passou a concentrar a sua própria configuração, como nome visível, ícone, cor, forma geométrica, pergunta predefinida, dica de resposta, cenário padrão e dificuldade padrão.

O motivo para aplicar este padrão foi evitar que a lógica de cada tipo de atividade ficasse espalhada por várias telas da aplicação. Assim, quando for necessário adicionar novos tipos de atividade, a alteração será mais simples e localizada.

### Factory simples

Foi incorporada uma **Factory simples** para centralizar a escolha da configuração correta de cada tipo de atividade.

O motivo para esta decisão foi evitar múltiplas verificações condicionais espalhadas pela aplicação. A seleção do tipo de atividade passa a estar concentrada num único ponto, tornando o código mais simples de manter.

### State / Enums

Foram introduzidos estados organizados para representar situações importantes da aplicação, como:

- submissão pendente;
- submissão sincronizada;
- submissão com falha;
- atividade em rascunho;
- atividade em revisão;
- atividade aprovada;
- atividade rejeitada;
- origem da atividade.

O motivo para esta alteração foi evitar o uso excessivo de textos soltos no código. Com estados controlados, reduz-se o risco de erros de escrita e melhora-se a consistência da aplicação.

### Facade

Foi aplicada uma **Facade** para concentrar os principais fluxos da aplicação, como criar atividade, iniciar atividade, submeter resposta, carregar resultados e sincronizar submissões pendentes.

O motivo para usar este padrão foi reduzir o acoplamento das telas com detalhes internos, como abertura da base SQLite, criação de objetos de acesso a dados, chamadas à API, gravação local e lógica de sincronização.

Com isso, as telas passam a chamar uma interface de alto nível, sem precisarem conhecer toda a infraestrutura interna da aplicação.

### Command

Foi aplicado o padrão **Command** na sincronização de submissões pendentes.

O motivo para aplicar este padrão foi encapsular operações de sincronização como ações executáveis. Isto prepara a aplicação para cenários offline-first, nos quais uma submissão pode ser guardada localmente e enviada posteriormente quando houver ligação.

Esta estrutura facilita futuras melhorias, como repetição automática, fila de sincronização, controlo de tentativas e tratamento de falhas.

### Observer

Foi aplicado um mecanismo simples de **Observer** para avisar partes da aplicação quando eventos relevantes acontecem, como submissão de resposta, alteração de resultados ou conclusão de sincronização.

O motivo para usar este padrão foi permitir que a página de resultados seja atualizada automaticamente quando os dados locais mudam, reduzindo a necessidade de ações manuais do utilizador.

---

## Síntese das decisões arquiteturais

Os padrões foram aplicados de forma incremental, com o objetivo de melhorar a manutenção sem tornar o protótipo excessivamente complexo.

A prioridade foi manter o código funcional e compreensível, mas preparado para evolução futura, especialmente nos seguintes pontos:

- novos tipos de atividade;
- atividades criadas pela comunidade;
- resultados e métricas;
- sincronização offline;
- atualização automática da interface;
- integração com backend real;
- autenticação e perfis;
- sincronização entre mobile e Web;
- segurança e validação de sessão.

Desta forma, a aplicação mantém uma estrutura modular, com melhor separação de responsabilidades entre interface, dados, lógica de negócio e fluxos de utilização.

---

## Funcionalidades da Sprint 1

A Sprint 1 teve como objetivo criar a base funcional inicial da aplicação.

Nesta versão foram contemplados os seguintes pontos:

### Estrutura inicial

- criação do projeto Flutter;
- organização inicial de pastas;
- separação entre telas, widgets, modelos, dados, repositórios e serviços;
- configuração de dependências principais.

### Interface e navegação

- Home gamificada com percurso de atividades;
- barra de navegação inferior com:
  - Home;
  - Praticar;
  - Resultados;
  - Análises;
  - Ajustes;
- páginas placeholder para funcionalidades futuras;
- menu superior com três pontos;
- página Language para configuração do idioma habitual do aluno e do idioma que pretende aprender.

### Atividades

A aplicação já contempla diferentes tipos de atividade:

- vocabulário;
- áudio;
- diálogo;
- quiz;
- revisão;
- desafio final.

Cada tipo de atividade possui uma forma geométrica própria no mapa gamificado:

- áudio: círculo;
- vocabulário: quadrado arredondado;
- diálogo: hexágono;
- quiz: losango;
- revisão: pentágono;
- desafio final: estrela.

### Configuração da atividade

A página de criação de atividade permite configurar:

- cenário;
- idioma a praticar;
- dificuldade;
- tipo de atividade.

Ao clicar em **Iniciar atividade**, a aplicação:

1. cria um identificador da atividade;
2. guarda a atividade na base SQLite;
3. chama o fluxo de deploy;
4. recebe uma URL simulada;
5. apresenta a página da atividade iniciada.

---

## Funcionalidades da Sprint 2

A Sprint 2 evoluiu o protótipo para suportar o fluxo de submissão e resultados.

Nesta versão foram acrescentados:

- página **Praticar** com atividade predefinida;
- submissão de resposta através de fluxo mockado;
- preparação para o endpoint de submissão;
- gravação de submissões no SQLite;
- gravação de resultados no SQLite;
- apresentação do histórico em **Meus Resultados**;
- estado de sincronização das submissões;
- estrutura inicial de sincronização de submissões pendentes;
- atualização automática dos resultados através de notificação interna.

O fluxo principal passou a ser:

**Praticar atividade → Submeter resposta → Guardar resultado → Consultar histórico**

Além disso, a criação de atividades foi reposicionada como funcionalidade secundária, acessível pelo menu superior e pelos ajustes, reforçando que o foco principal da aplicação é a prática de atividades já existentes.

---

## Funcionalidades da Sprint 3

A Sprint 3 tinha como previsão a tela de análises, finalização da UI e usabilidade, cobertura de testes unitários/widget e ajustes de performance e segurança.

O objetivo desta sprint foi estabilizar o protótipo antes da fase final, permitindo que a etapa seguinte seja dedicada à correção final, melhoria da experiência de utilização e preparação da entrega.

Durante esta sprint foi implementado mais do que o previsto inicialmente.

### Identidade visual

- criação e integração da logo baseada nas letras **DTK**;
- reforço da identidade visual do DailyTalk.pt.

### Publicação e infraestrutura

- migração do DNS de Locaweb para Cloudflare;
- ativação de acesso HTTPS;
- publicação do domínio `dailytalk.pt`;
- publicação da API em `dailytalk.pt/api`;
- preparação da versão Web em `dailytalk.pt/web`;
- criação de botão **Teste agora** no LUMI apontando para a versão Web Flutter.

### Backend e persistência

- integração real com backend;
- criação de API em Cloudflare Workers;
- criação de persistência remota em Cloudflare D1;
- endpoints de autenticação;
- endpoints de preferências;
- endpoints de submissões;
- sincronização entre mobile e Web.

### Conta de utilizador

- registo de conta;
- login;
- logout;
- validação de sessão contra a API;
- armazenamento seguro de token;
- limpeza de sessão inválida;
- associação de preferências ao utilizador;
- associação de submissões ao utilizador autenticado.

### Usabilidade

- implementação do ícone de visualização de palavra-passe;
- melhoria do fluxo de login;
- melhoria do fluxo de registo;
- melhoria da tela Conta;
- melhoria das mensagens de sessão inválida;
- implementação do fluxo de recuperação de palavra-passe em modo protótipo/debug.

### Segurança

- autenticação com JWT;
- `JWT_SECRET` configurado como secret na Cloudflare;
- hash de password com PBKDF2;
- ajuste de iterações PBKDF2 para compatibilidade com Cloudflare Workers;
- CORS configurado para o domínio do projeto;
- validação de sessão com `/api/me`;
- tokens de recuperação de palavra-passe guardados na D1 apenas como hash;
- expiração de código de recuperação;
- separação entre dados locais e dados sincronizados.

### Testes

Foram executados:

```bash
flutter analyze
flutter test
```

A aplicação ficou sem problemas de análise estática e com os testes automatizados a passar.

A cobertura de testes foi reforçada ao nível dos widgets e do fluxo inicial da aplicação. Fica identificada para a próxima etapa a possibilidade de aumentar a cobertura unitária de componentes específicos, como repositórios, serviços de autenticação, serviços de sincronização e modelos de dados.

### Decisão sobre recuperação de palavra-passe

Durante a implementação da recuperação de palavra-passe, verificou-se que o Cloudflare Email Sending, necessário para envio programático de emails transacionais a partir de Workers, está disponível apenas no plano Workers Paid.

Como alternativa para protótipo/debug, o sistema gera um código temporário, guarda o respetivo hash na D1 e, quando `PASSWORD_RESET_DEBUG=true`, devolve o código à app. Esta solução permite demonstrar o fluxo de recuperação, mas não substitui uma recuperação real por email em produção.

### Resultado da Sprint 3

Considera-se que a Sprint 3 cumpriu o previsto e avançou além do inicialmente planeado. Para além da tela de análises, ajustes de UI/usabilidade, testes e melhorias de segurança, foi criada a base técnica para autenticação, sincronização Web/mobile, persistência em backend, recuperação de palavra-passe em modo protótipo e publicação em Cloudflare.

---

## Funcionalidades da Sprint 4

A Sprint 4 teve como foco principal o refinamento da experiência de utilização, a consistência visual entre ecrãs e a preparação da aplicação para uma apresentação mais madura do protótipo.

O ponto de partida foi a análise do ecrã de entrada a partir da perspetiva dos primeiros segundos de utilização: o utilizador devia conseguir perceber rapidamente o que é o DailyTalk.pt, para que serve e qual a ação principal disponível.

### Identidade visual e primeira impressão

- reformulação do ecrã de login;
- integração de uma composição visual com mascote, livro, balões de fala e marca DailyTalk.pt;
- reforço da proposta de valor: **Serious game para aprendizagem de idiomas**;
- remoção de elementos que pareciam botões, mas não eram interativos;
- destaque das ações **Entrar** e **Criar conta**;
- utilização de rodapé decorativo com ambiente associado à mobilidade escolar.

### Coerência entre fluxos de autenticação

Foram alinhados visualmente os ecrãs ligados à autenticação:

- login;
- criação de conta;
- recuperação de palavra-passe;
- redefinição de palavra-passe;
- conta do utilizador.

O azul passou a ser usado prioritariamente para marca, foco e ação principal, evitando que ícones de campos inativos parecessem elementos selecionados.

### Ajustes em ecrãs internos

Também foram ajustados ecrãs internos para manter uma experiência mais consistente:

- seleção de idioma;
- seleção de perfil;
- configuração de atividade;
- execução de atividade/desafio;
- resultados e análises;
- ajustes;
- notas privadas;
- páginas internas com estrutura genérica.

A Home gamificada foi preservada, por já cumprir bem a função de orientar a progressão do utilizador dentro da aplicação.

### Atividades gamificadas

Foram ainda criados e integrados ecrãs específicos para atividades do percurso gamificado:

- **Vocabulário**, com exercício de associação de pares;
- **Quiz**, com perguntas contextualizadas e alternativas no idioma a praticar;
- **Diálogo**, com simulação guiada de conversa;
- **Revisão**, com cartões de reforço e consolidação.

Estes ecrãs leem os idiomas definidos pelo utilizador no perfil, mantendo a separação entre o idioma de apoio/interface e o idioma de aprendizagem.

### Resultado da Sprint 4

A Sprint 4 consolidou a aplicação como um protótipo mais coerente do ponto de vista visual e de experiência de utilização. A aplicação passou a comunicar melhor a sua identidade, o seu propósito educativo e as ações principais esperadas em cada fluxo. Além disso, o mapa gamificado deixou de funcionar apenas como navegação visual e passou a abrir atividades concretas de prática.

---

## Base de dados local

A aplicação usa SQLite local através do pacote sqflite.

A base local foi pensada para suportar:

- cache de atividades;
- armazenamento de submissões pendentes;
- funcionamento offline básico;
- sincronização posterior;
- histórico de resultados;
- dados analíticos;
- configurações locais da app;
- preferências locais;
- apoio à navegação offline.

As principais áreas de dados previstas são:

- atividades;
- parâmetros de atividades;
- alunos/utilizadores;
- submissões;
- resultados de submissões;
- definições analíticas;
- registos analíticos;
- fila de sincronização;
- configurações da aplicação.

---

## Base de dados remota

A Sprint 3 introduziu persistência remota através de Cloudflare D1.

A base remota suporta:

- utilizadores;
- preferências de utilizador;
- submissões de atividades;
- tokens de recuperação de palavra-passe.

A base remota não substitui totalmente o SQLite local. A estratégia adotada é híbrida:

- SQLite para funcionamento local, cache e apoio offline;
- D1 para persistência remota, autenticação e sincronização entre dispositivos.

---

## Integração com backend

A integração com backend deixou de ser apenas simulada e passou a contar com uma API real em Cloudflare Workers.

Principais endpoints:

```text
GET  /api/health
POST /api/auth/register
POST /api/auth/login
POST /api/auth/forgot-password
POST /api/auth/reset-password
GET  /api/me
PUT  /api/me/preferences
POST /api/activities/submissions
GET  /api/activities/submissions/mine
```

A app pode ser executada em modo mock ou modo real.

### Modo real

```bash
flutter run -d chrome \
  --web-port 5173 \
  --dart-define=DAILYTALK_USE_MOCK_API=false \
  --dart-define=DAILYTALK_API_BASE_URL=https://dailytalk.pt/api
```

### Modo mock

```bash
flutter run -d chrome \
  --dart-define=DAILYTALK_USE_MOCK_API=true
```

---

## Build e execução

### Instalar dependências

```bash
flutter pub get
```

### Análise estática

```bash
flutter analyze
```

### Testes

```bash
flutter test
```

### Execução local simplificada

Para desenvolvimento local, a API pode ser executada em `localhost:8787` e a aplicação Flutter Web em `localhost:5555`.

Numa janela PowerShell, executar a API:

```powershell
cd C:\DEV\Flutter\dailytalk-api
npm run dev
```

Resultado esperado:

```text
http://localhost:8787
```

Noutra janela PowerShell, executar a aplicação Flutter Web:

```powershell
cd C:\DEV\Flutter\dailytalk_mobile
flutter run -d chrome --web-port 5555
```

Resultado esperado:

```text
http://localhost:5555
```

### Executar em Chrome com API real publicada

```bash
flutter run -d chrome \
  --web-port 5173 \
  --dart-define=DAILYTALK_USE_MOCK_API=false \
  --dart-define=DAILYTALK_API_BASE_URL=https://dailytalk.pt/api
```

### Gerar APK Android com API real

```bash
flutter build apk --release \
  --dart-define=DAILYTALK_USE_MOCK_API=false \
  --dart-define=DAILYTALK_API_BASE_URL=https://dailytalk.pt/api
```

### Gerar Web release

```bash
flutter build web --release \
  --base-href /web/ \
  --dart-define=DAILYTALK_USE_MOCK_API=false \
  --dart-define=DAILYTALK_API_BASE_URL=https://dailytalk.pt/api
```

---

## Tecnologias utilizadas

- Flutter;
- Dart;
- SQLite;
- sqflite;
- Material Design;
- Android SDK;
- Cloudflare DNS;
- Cloudflare Workers;
- Cloudflare D1;
- JWT;
- PBKDF2;
- flutter_secure_storage;
- arquitetura em camadas;
- padrões de software aplicados de forma incremental.

---

## Funcionalidades ainda previstas

As próximas etapas do projeto poderão incluir:

- reforço da tela de análises para professores;
- dashboards pedagógicos;
- aumento da cobertura de testes unitários;
- envio real de emails transacionais para recuperação de palavra-passe;
- autenticação multifator;
- verificação de email;
- abertura da atividade em WebView;
- melhoria da sincronização offline-first;
- criação de atividades pela comunidade;
- sistema de likes;
- ranking de atividades;
- sistema de pontos;
- loja de skins e itens;
- reputação do criador de atividades;
- moderação de atividades com apoio de IA;
- internacionalização completa da interface;
- reforço da documentação técnica e de utilização;
- validação final dos ecrãs gamificados em Android e Web;
- reforço das atividades de áudio e desafio final;
- persistência detalhada de progresso por atividade;
- revisão final de acessibilidade visual, contraste e tamanhos de toque.

---

## Estado da Sprint

### Sprint 1

Estado: concluída como base funcional inicial.

Entregas contempladas:

- estrutura Flutter funcional;
- navegação inferior;
- Home gamificada;
- menu superior;
- configuração linguística;
- SQLite local;
- configuração inicial da atividade;
- simulação de deploy;
- exibição da atividade iniciada.

### Sprint 2

Estado: implementada como evolução funcional do fluxo de prática, submissão e resultados.

Entregas contempladas:

- página Praticar;
- submissão mockada;
- gravação local de submissões;
- gravação local de resultados;
- histórico em Meus Resultados;
- estados de sincronização;
- estrutura inicial de sincronização;
- atualização automática dos resultados;
- aplicação dos padrões Strategy, Factory simples, Facade, Command e Observer.

### Sprint 3

Estado: implementada e expandida.

Entregas contempladas:

- tela de análises/resultados;
- finalização e refinamento de UI;
- ajustes de usabilidade;
- criação da logo DTK;
- migração DNS para Cloudflare;
- publicação do domínio com HTTPS;
- botão **Teste agora** no LUMI;
- integração com backend real;
- API em Cloudflare Workers;
- base remota Cloudflare D1;
- conta de utilizador;
- autenticação com JWT;
- armazenamento seguro de token;
- validação de sessão;
- preferências por utilizador;
- submissões associadas ao utilizador;
- sincronização mobile/Web;
- recuperação de palavra-passe em modo protótipo/debug;
- testes com `flutter analyze` e `flutter test`;
- documentação do código e do estado da sprint.

### Sprint 4

Estado: implementada como refinamento visual e de experiência de utilização.

Entregas contempladas:

- redesign do ecrã de login;
- criação/reforço de assets de branding;
- integração de mascote e rodapé decorativo;
- melhoria do ecrã de criação de conta;
- melhoria do fluxo de recuperação e redefinição de palavra-passe;
- melhoria da seleção de idioma;
- melhoria da seleção de perfil;
- melhoria da configuração de atividade;
- melhoria da tela de atividade/desafio;
- melhoria de resultados e análises;
- melhoria da tela Conta;
- melhoria dos Ajustes;
- melhoria das Notas privadas;
- alinhamento visual de páginas internas;
- manutenção da Home gamificada como ecrã principal já consolidado;
- criação de ecrãs próprios para Vocabulário, Quiz, Diálogo e Revisão;
- ligação dos nós da Home gamificada aos novos ecrãs de atividade;
- utilização dos idiomas definidos no perfil nos ecrãs de prática;
- aplicação da identidade visual do DailyTalk.pt às atividades gamificadas.

---

## Observações

Esta versão continua a ser um protótipo funcional, mas já ultrapassa o fluxo local/mockado da Sprint 2.

A aplicação passou a ter backend real, autenticação, persistência remota e sincronização entre plataformas. Ainda assim, algumas funcionalidades continuam em modo de protótipo, principalmente a recuperação de palavra-passe, que nesta fase utiliza código devolvido pela app em modo debug por limitação do plano de envio de email transacional.

A organização em quatro sprints permitiu testar progressivamente as funcionalidades principais. A Sprint 3 foi usada para consolidar autenticação, backend, segurança, testes e infraestrutura. A Sprint 4 foi usada para melhorar a comunicação visual, reforçar a identidade do DailyTalk.pt, tornar os fluxos principais mais consistentes do ponto de vista de usabilidade e transformar parte do mapa gamificado em atividades jogáveis.

A próxima etapa deverá concentrar-se na validação final em Android e Web, reforço dos testes unitários, persistência mais completa do progresso das novas atividades, substituição de mecanismos temporários por serviços definitivos quando a infraestrutura permitir e preparação da entrega final.
