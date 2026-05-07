# DailyTalk.pt Mobile

Aplicação móvel desenvolvida em Flutter para o projeto **Erasmus DailyTalk.pt**, no âmbito da unidade curricular **DAM - Desenvolvimento de Aplicações Móveis**.

O objetivo da aplicação é apoiar alunos em mobilidade Erasmus+ na prática de comunicação em situações reais do quotidiano escolar, através de atividades gamificadas como vocabulário, áudio, diálogos, quizzes e desafios.

Esta versão contempla a evolução até à **Sprint 2**, incluindo a estrutura inicial da aplicação, navegação, Home gamificada, base de dados local SQLite, configuração de atividades, submissão de respostas, apresentação de resultados e aplicação inicial de padrões de software para melhorar a organização e manutenção do código.

---

## Estado atual da aplicação

A aplicação já possui:

- projeto Flutter configurado;
- navegação inferior entre páginas principais;
- Home gamificada inspirada em progressão por atividades;
- mapa de atividades com diferentes tipos e formas geométricas;
- separação entre o fluxo principal de prática e a criação secundária de atividades;
- menu superior com opções como Language, criar atividade, minhas atividades, sincronizar, ajuda e sobre;
- página de configuração linguística com dois idiomas:
  - idioma habitual do aluno;
  - idioma que o aluno pretende aprender;
- estrutura SQLite local usando sqflite;
- página de configuração e criação de atividade;
- simulação de integração com o endpoint /deploy;
- fluxo de submissão de respostas com simulação do endpoint /submit;
- gravação local de atividades, submissões e resultados;
- página de resultados com histórico de pontuações e estado de sincronização;
- estrutura inicial de sincronização de submissões pendentes;
- atualização automática da área de resultados após submissões ou sincronizações;
- aplicação inicial dos padrões Strategy, Factory simples, Facade, Command e Observer.

---

## Objetivo do projeto

O DailyTalk.pt Mobile será gratuito e pretende disponibilizar uma experiência educativa móvel, interativa e gamificada, permitindo que os alunos pratiquem comunicação em diferentes contextos, como:

- sala de aula;
- apresentações;
- conversas informais;
- situações de integração escolar;
- vocabulário do quotidiano;
- diálogos guiados;
- compreensão oral;
- quizzes de reforço.

A aplicação foi pensada para funcionar com apoio de um backend existente, mas também com suporte local básico através de SQLite, preparando a app para cenários de conectividade instável.

---

## Configuração linguística

A aplicação não trabalha apenas com um idioma. O aluno define dois idiomas:

- o idioma que utiliza normalmente;
- o idioma que pretende aprender ou praticar.

Por exemplo, um aluno pode usar Português como idioma habitual e escolher Italiano como idioma de aprendizagem.

Esta separação é importante porque os exercícios, diálogos e atividades podem ser preparados considerando a relação entre o idioma conhecido pelo aluno e o idioma que pretende praticar.

A opção aparece como **Language** no menu, por ser uma designação reconhecível internacionalmente mesmo para alunos de diferentes países.

---

## Modelo de atividades e participação da comunidade

O DailyTalk.pt Mobile prevê disponibilizar atividades educativas de dois tipos principais: atividades criadas pela equipa da aplicação e atividades criadas pela própria comunidade de utilizadores.

As atividades criadas pela equipa funcionam como conteúdos base, garantindo que o aluno tem sempre acesso a exercícios estruturados, alinhados com os objetivos pedagógicos da aplicação e adequados ao contexto de comunicação em ambiente Erasmus+.

Além disso, o aluno poderá criar as suas próprias atividades com base nas dificuldades que encontra durante a aprendizagem. Por exemplo, se tiver dificuldades em vocabulário, diálogos do quotidiano escolar, compreensão oral ou situações específicas de comunicação, poderá propor uma nova atividade para praticar esse conteúdo.

As atividades criadas pelos alunos poderão ficar disponíveis para a comunidade, mas apenas após uma validação prévia. Esta validação será apoiada por mecanismos de IA e pela equipa mantenedora da aplicação, de forma a garantir que os conteúdos são adequados, seguros, compreensíveis e pedagogicamente úteis.

Depois de aprovadas, as atividades passam a poder ser utilizadas por outros jogadores. A comunidade poderá interagir com essas atividades através de mecanismos de avaliação, como o botão **Gostei**. Quanto mais avaliações positivas uma atividade receber, maior será a sua relevância dentro da aplicação, podendo subir no ranking e passar a ser mais recomendada a outros utilizadores.

O jogador que criou uma atividade bem avaliada será recompensado com pontos. Estes pontos poderão ser usados futuramente numa loja interna da aplicação, para trocar por skins, elementos visuais e outros itens de personalização. Além disso, o criador poderá subir de nível na sua reputação geral como ajudante da comunidade, incentivando a criação de conteúdos úteis e colaborativos.

As atividades também poderão ser rejeitadas pela comunidade. Nestes casos, ficarão numa lista de revisão para análise da equipa mantenedora da aplicação, que poderá decidir reformular, corrigir ou excluir definitivamente a atividade. Desta forma, procura-se equilibrar a liberdade de criação da comunidade com a qualidade, segurança e utilidade pedagógica dos conteúdos disponibilizados.

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
- integração futura com backend real.

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
- preparação para o endpoint /submit;
- gravação de submissões no SQLite;
- gravação de resultados no SQLite;
- apresentação do histórico em **Meus Resultados**;
- estado de sincronização das submissões;
- estrutura inicial de sincronização de submissões pendentes;
- atualização automática dos resultados através de notificação interna.

O fluxo principal passou a ser:

Praticar atividade → Submeter resposta → Guardar resultado → Consultar histórico

Além disso, a criação de atividades foi reposicionada como funcionalidade secundária, acessível pelo menu superior e pelos ajustes, reforçando que o foco principal da aplicação é a prática de atividades já existentes.

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
- configurações locais da app.

As principais áreas de dados previstas são:

- atividades;
- parâmetros de atividades;
- alunos;
- submissões;
- resultados de submissões;
- definições analíticas;
- registos analíticos;
- fila de sincronização;
- configurações da aplicação.

---

## Integração com backend

Nesta fase, a integração com o backend está preparada de forma simulada.

A aplicação já prevê os seguintes fluxos:

- deploy de atividade;
- submissão de resposta;
- sincronização de submissões pendentes;
- carregamento de resultados locais.

A integração real com o backend poderá ser ativada futuramente, mantendo a mesma organização geral dos fluxos.

---

## Tecnologias utilizadas

- Flutter;
- SQLite;
- sqflite;
- Material Design;
- Android SDK;
- arquitetura em camadas;
- padrões de software aplicados de forma incremental.

---

---

## Orientação prevista para a Sprint 3

A Sprint 3 deverá focar-se na evolução da aplicação para suportar perfis diferenciados de utilização.

A aplicação deverá passar a considerar três perfis principais:

- **Estudante**: utiliza a aplicação para praticar a língua escolhida em situações reais, como responder a perguntas, pedir informações, compreender horários, falar sobre alimentação ou interagir no contexto academico.
- **Anfitrião**: utiliza a aplicação para se preparar para receber estudantes Erasmus, treinando frases de acolhimento, instruções simples, perguntas úteis e comunicação inicial.
- **Professor**: perfil pedagógico previsto para acompanhar progresso, sugerir atividades, validar conteúdos e consultar dificuldades frequentes.

O foco prioritário da Sprint 3 será o perfil **Anfitrião**, por representar uma dimensão importante do projeto: preparar não só o estudante Erasmus, mas também a pessoa que o recebe.

A aplicação deverá organizar as atividades por cenários reais de comunicação, evitando questionários longos e privilegiando desafios curtos, práticos e contextualizados.

Também deverá ser mantida a regra de privacidade definida no projeto: dados sensíveis, como alergias, restrições alimentares reais ou informações pessoais, não devem ser enviados ao servidor. Esses conteúdos podem aparecer como exemplos de treino linguístico, mas não devem ser tratados como dados reais do utilizador.

Caso exista uma funcionalidade futura de notas privadas, estas deverão ficar apenas no dispositivo, sem sincronização e com aviso claro para o utilizador.

## Funcionalidades ainda previstas

As próximas etapas do projeto poderão incluir:

- integração real com o backend DailyTalk.pt;
- abertura da atividade em WebView;
- envio real de respostas para o backend;
- página real de resultados;
- página real de análises para professores;
- sincronização real de submissões pendentes;
- criação de atividades pela comunidade;
- sistema de likes;
- ranking de atividades;
- sistema de pontos;
- loja de skins e itens;
- reputação do criador de atividades;
- moderação de atividades com apoio de IA;
- autenticação de alunos e professores;
- internacionalização completa da interface.

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
- aplicação dos padrões Strategy, Factory simples, Facade, Command e Observer.

### Sprint 3

### Sprint 3

Previsto:

- implementação do suporte a perfis de utilização:
  - Estudante;
  - Anfitrião;
  - Professor;
- criação de atividades específicas por perfil;
- estruturação de cenários reais de comunicação, como:
  - chegada à casa;
  - quarto;
  - casa de banho;
  - pequeno-almoço;
  - horários;
  - regras da casa;
  - alimentação;
  - transportes;
  - universidade;
- desenvolvimento do perfil Anfitrião como perfil real da aplicação, e não apenas como texto explicativo;
- adaptação da página Praticar para apresentar atividades conforme o perfil selecionado;
- preparação de atividades para o anfitrião treinar frases de acolhimento, instruções simples e perguntas úteis;
- preparação de atividades para o estudante treinar respostas e perguntas em situações reais;
- melhoria da lógica de personalização com base no desempenho do utilizador;
- reforço da separação entre dados pedagógicos e dados sensíveis;
- criação ou preparação de notas privadas locais, sem sincronização com servidor;
- evolução da estrutura SQLite para suportar perfis, cenários, atividades por perfil, analytics e notas locais;
- refinamento da experiência de utilização;
- testes adicionais;
- documentação final;
- integração mais próxima com backend real.

---

## Observações

Esta versão ainda é um protótipo funcional inicial. Algumas funcionalidades estão implementadas de forma mockada para validar o fluxo da Sprint 2 sem depender da disponibilidade do backend real.

O objetivo desta fase é garantir uma estrutura base funcional, modular e preparada para evolução, mantendo o foco principal na prática de atividades e na experiência gamificada do aluno.