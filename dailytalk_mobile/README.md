# DailyTalk.pt Mobile

Aplicação móvel desenvolvida em Flutter para o projeto **Erasmus DailyTalk.pt**, no âmbito da unidade curricular **DAM - Desenvolvimento de Aplicações Móveis**.

O objetivo da aplicação é apoiar alunos em mobilidade Erasmus+ na prática de comunicação em situações reais do quotidiano escolar, através de atividades gamificadas como vocabulário, áudio, diálogos, quizzes e desafios.

Esta versão corresponde ao início da **Sprint 1**, com foco na estrutura inicial da aplicação, navegação, Home gamificada, base de dados local SQLite e configuração inicial de atividades.

---

## Estado atual da aplicação

A aplicação já possui:

- projeto Flutter configurado;
- navegação inferior entre páginas principais;
- Home gamificada inspirada em progressão por atividades;
- tipos de atividade com formas geométricas diferentes;
- menu superior com opções como idioma, sincronização, ajuda e sobre;
- página de seleção de idioma;
- estrutura SQLite local usando `sqflite`;
- página inicial de configuração de atividade;
- simulação de integração com o endpoint `/deploy`;
- gravação local da atividade criada;
- página de exibição da URL da atividade iniciada.

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

## Modelo de atividades e participação da comunidade

O DailyTalk.pt Mobile prevê disponibilizar atividades educativas de dois tipos principais: atividades criadas pelos desenvolvedores da aplicação e atividades criadas pela própria comunidade de utilizadores.

As atividades criadas pelos desenvolvedores funcionam como conteúdos base, garantindo que o aluno tem sempre acesso a exercícios estruturados, alinhados com os objetivos pedagógicos da aplicação e adequados ao contexto de comunicação em ambiente Erasmus+.

Além disso, o aluno poderá criar as suas próprias atividades com base nas dificuldades que encontra durante a aprendizagem. Por exemplo, se tiver dificuldades em vocabulário, diálogos do quotidiano escolar, compreensão oral ou situações específicas de comunicação, poderá propor uma nova atividade para praticar esse conteúdo.

As atividades criadas pelos alunos poderão ficar disponíveis para a comunidade, mas apenas após uma validação prévia. Esta validação será apoiada por mecanismos de IA e pela equipa mantenedora da aplicação, de forma a garantir que os conteúdos são adequados, seguros, compreensíveis e pedagogicamente úteis.

Depois de aprovadas, as atividades passam a poder ser utilizadas por outros jogadores. A comunidade poderá interagir com essas atividades através de mecanismos de avaliação, como o botão **"Gostei"**. Quanto mais avaliações positivas uma atividade receber, maior será a sua relevância dentro da aplicação, podendo subir no ranking e passar a ser mais recomendada a outros utilizadores.

O jogador que criou uma atividade bem avaliada será recompensado com pontos. Estes pontos poderão ser usados futuramente numa loja interna da aplicação, para trocar por skins, elementos visuais e outros itens de personalização. Além disso, o criador poderá subir de nível na sua reputação geral como ajudante da comunidade, incentivando a criação de conteúdos úteis e colaborativos.

As atividades também poderão ser rejeitadas pela comunidade. Nestes casos, ficarão numa lista de revisão para análise da equipa mantenedora da aplicação, que poderá decidir reformular, corrigir ou excluir definitivamente a atividade. Desta forma, procura-se equilibrar a liberdade de criação da comunidade com a qualidade, segurança e utilidade pedagógica dos conteúdos disponibilizados.

---

## Funcionalidades da Sprint 1

A Sprint 1 tem como objetivo criar a base funcional inicial da aplicação.

Nesta versão foram contemplados os seguintes pontos:

### Estrutura inicial

- Criação do projeto Flutter.
- Organização inicial de pastas.
- Separação entre telas, widgets, modelos, dados, repositórios e serviços.
- Configuração de dependências principais.

### Interface e navegação

- Home gamificada com percurso de atividades.
- Barra de navegação inferior com:
  - Home;
  - Atividade;
  - Resultados;
  - Análises;
  - Ajustes.
- Páginas placeholder para funcionalidades futuras.
- Menu superior com três pontos.
- Página de seleção de idioma.

### Atividades

- Tipos diferentes de atividade:
  - vocabulário;
  - áudio;
  - diálogo;
  - quiz;
  - revisão;
  - desafio final.
- Cada tipo de atividade possui forma geométrica própria:
  - áudio: círculo;
  - vocabulário: quadrado arredondado;
  - diálogo: hexágono;
  - quiz: losango;
  - revisão: pentágono;
  - desafio final: estrela.

### Configuração da atividade

A página de atividade já permite configurar:

- cenário;
- idioma;
- dificuldade;
- tipo de atividade.

Ao clicar em **Iniciar atividade**, a app:

1. cria um identificador local da atividade;
2. guarda a atividade na base SQLite;
3. chama o serviço de deploy;
4. recebe uma URL simulada;
5. apresenta a página da atividade iniciada.

### Integração inicial com backend

Nesta fase, a integração com o backend está preparada através do serviço:

```text
lib/data/api/dailytalk_api_service.dart