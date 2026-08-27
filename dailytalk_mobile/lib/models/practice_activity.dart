import '../strategies/activity_strategy.dart';
import 'communication_scenario.dart';
import 'user_profile.dart';

/// Representa uma atividade prática predefinida da aplicação.
///
/// Estas atividades são usadas na página "Praticar" e podem variar conforme:
/// - perfil selecionado;
/// - cenário de comunicação;
/// - tipo de atividade;
/// - dificuldade.
class PracticeActivity {
  const PracticeActivity({
    required this.id,
    required this.profile,
    required this.scenario,
    required this.strategy,
    required this.title,
    required this.description,
    required this.question,
    required this.answerHint,
    required this.difficulty,
  });

  final String id;
  final UserProfileType profile;
  final CommunicationScenario scenario;
  final ActivityStrategy strategy;
  final String title;
  final String description;
  final String question;
  final String answerHint;
  final String difficulty;

  /// Identificador técnico usado para guardar a atividade localmente.
  String get remoteActivityId {
    return 'PREDEF-${profile.databaseValue}-${scenario.databaseValue}-${strategy.type}-$id';
  }
}

/// Banco local de atividades práticas predefinidas.
///
/// Nesta fase, as atividades são fixas no código para validar o fluxo.
/// Futuramente poderão vir do backend ou de uma tabela SQLite própria.
class PracticeActivityBank {
  const PracticeActivityBank._();

  static const List<PracticeActivity> all = [
    // ------------------------------------------------------------
    // Atividades para Estudante
    // ------------------------------------------------------------
    PracticeActivity(
      id: 'student-allergies-001',
      profile: UserProfileType.student,
      scenario: CommunicationScenario.allergiesTraining,
      strategy: DialogActivityStrategy(),
      title: 'Responder sobre alergias',
      description:
          'Treina uma resposta simples quando alguém pergunta se tens alergias.',
      question:
          'O anfitrião pergunta: “Tens alergia a alguma coisa?” '
          'Escreve uma resposta simples no idioma que estás a praticar.',
      answerHint: 'Ex.: Não, não tenho alergias.',
      difficulty: 'Inicial',
    ),
    PracticeActivity(
      id: 'student-bathroom-001',
      profile: UserProfileType.student,
      scenario: CommunicationScenario.bathroom,
      strategy: DialogActivityStrategy(),
      title: 'Perguntar pela casa de banho',
      description: 'Treina uma pergunta útil para encontrar a casa de banho.',
      question:
          'Estás numa casa nova e precisas de perguntar onde fica a casa de banho. '
          'Escreve a frase que dirias.',
      answerHint: 'Ex.: Onde fica a casa de banho?',
      difficulty: 'Inicial',
    ),
    PracticeActivity(
      id: 'student-breakfast-001',
      profile: UserProfileType.student,
      scenario: CommunicationScenario.breakfast,
      strategy: QuizActivityStrategy(),
      title: 'Responder sobre pequeno-almoço',
      description:
          'Treina uma resposta sobre aquilo que costumas comer de manhã.',
      question:
          'O anfitrião pergunta: “O que costumas comer ao pequeno-almoço?” '
          'Escreve uma resposta simples.',
      answerHint: 'Ex.: Costumo comer pão e beber leite.',
      difficulty: 'Inicial',
    ),

    // ------------------------------------------------------------
    // Atividades para Anfitrião
    // ------------------------------------------------------------
    PracticeActivity(
      id: 'host-bedroom-001',
      profile: UserProfileType.host,
      scenario: CommunicationScenario.bedroom,
      strategy: DialogActivityStrategy(),
      title: 'Explicar o quarto',
      description:
          'Treina uma frase de acolhimento para mostrar o quarto ao aluno visitante.',
      question:
          'Vais receber um aluno visitante em casa. '
          'Escreve uma frase simples para lhe explicar onde fica o quarto.',
      answerHint: 'Ex.: Este é o teu quarto. Podes deixar a mala aqui.',
      difficulty: 'Inicial',
    ),
    PracticeActivity(
      id: 'host-breakfast-001',
      profile: UserProfileType.host,
      scenario: CommunicationScenario.breakfast,
      strategy: DialogActivityStrategy(),
      title: 'Perguntar sobre pequeno-almoço',
      description:
          'Treina uma pergunta simples sobre preferências de pequeno-almoço.',
      question:
          'Queres saber o que o aluno costuma comer de manhã. '
          'Escreve uma pergunta adequada.',
      answerHint: 'Ex.: O que costumas comer ao pequeno-almoço?',
      difficulty: 'Inicial',
    ),
    PracticeActivity(
      id: 'host-schedule-001',
      profile: UserProfileType.host,
      scenario: CommunicationScenario.schedule,
      strategy: AudioActivityStrategy(),
      title: 'Explicar horários',
      description:
          'Treina uma instrução curta sobre o horário de saída no dia seguinte.',
      question:
          'Tens de explicar ao aluno que amanhã vão sair às 9h. '
          'Escreve a frase que dirias.',
      answerHint: 'Ex.: Amanhã vamos sair às nove horas.',
      difficulty: 'Inicial',
    ),
    PracticeActivity(
      id: 'host-pets-001',
      profile: UserProfileType.host,
      scenario: CommunicationScenario.pets,
      strategy: DialogActivityStrategy(),
      title: 'Avisar sobre animal doméstico',
      description:
          'Treina uma frase simples para explicar como lidar com um animal da casa.',
      question:
          'Há um cão em casa. Escreve uma frase simples para avisar o aluno '
          'de que não deve provocar o animal.',
      answerHint: 'Ex.: O cão é calmo, mas não o provoques.',
      difficulty: 'Média',
    ),
    PracticeActivity(
      id: 'host-house-rules-001',
      profile: UserProfileType.host,
      scenario: CommunicationScenario.houseRules,
      strategy: ReviewActivityStrategy(),
      title: 'Explicar regras da casa',
      description: 'Treina uma frase curta sobre uma regra básica da casa.',
      question:
          'Queres explicar ao aluno onde deve deixar as chaves. '
          'Escreve uma frase simples.',
      answerHint: 'Ex.: As chaves ficam aqui, junto à porta.',
      difficulty: 'Média',
    ),

    // ------------------------------------------------------------
    // Atividades para Professor
    // ------------------------------------------------------------
    PracticeActivity(
      id: 'teacher-classroom-001',
      profile: UserProfileType.teacher,
      scenario: CommunicationScenario.classroom,
      strategy: QuizActivityStrategy(),
      title: 'Dar instrução em sala de aula',
      description:
          'Treina uma instrução curta e clara para uma atividade escolar.',
      question:
          'Estás a orientar uma atividade em sala de aula. '
          'Escreve uma instrução simples para os alunos trabalharem em pares.',
      answerHint: 'Ex.: Leiam a pergunta e respondam em pares.',
      difficulty: 'Inicial',
    ),
  ];

  /// Devolve todas as atividades adequadas ao perfil selecionado.
  static List<PracticeActivity> forProfile(UserProfileType profile) {
    return all.where((activity) => activity.profile == profile).toList();
  }

  /// Devolve a primeira atividade adequada ao perfil.
  ///
  /// Nesta fase, usamos a primeira atividade como atividade principal.
  /// Futuramente poderá haver rotação, recomendação ou personalização.
  static PracticeActivity firstForProfile(UserProfileType profile) {
    final activities = forProfile(profile);

    if (activities.isEmpty) {
      return all.first;
    }

    return activities.first;
  }
}
