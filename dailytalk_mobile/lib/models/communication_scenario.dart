import 'user_profile.dart';

/// Cenários reais de comunicação usados nas atividades do DailyTalk.pt.
///
/// Os cenários foram pensados para contexto escolar/colegial,
/// com crianças e jovens normalmente entre os 11 e os 15 anos.
enum CommunicationScenario {
  arrivalHome(
    databaseValue: 'arrival_home',
    label: 'Chegada à casa',
    description:
        'Primeiros contactos ao chegar à casa ou ao local de acolhimento.',
    profiles: [
      UserProfileType.student,
      UserProfileType.host,
    ],
  ),
  bedroom(
    databaseValue: 'bedroom',
    label: 'Quarto',
    description:
        'Frases e instruções sobre o quarto, mala, cama e espaço pessoal.',
    profiles: [
      UserProfileType.student,
      UserProfileType.host,
    ],
  ),
  bathroom(
    databaseValue: 'bathroom',
    label: 'Casa de banho',
    description:
        'Perguntas e respostas sobre localização e utilização da casa de banho.',
    profiles: [
      UserProfileType.student,
      UserProfileType.host,
    ],
  ),
  breakfast(
    databaseValue: 'breakfast',
    label: 'Pequeno-almoço',
    description:
        'Comunicação sobre horários, preferências e alimentos do pequeno-almoço.',
    profiles: [
      UserProfileType.student,
      UserProfileType.host,
    ],
  ),
  schedule(
    databaseValue: 'schedule',
    label: 'Horários',
    description:
        'Frases sobre horas de saída, chegada, aulas, refeições e descanso.',
    profiles: [
      UserProfileType.student,
      UserProfileType.host,
    ],
  ),
  foodPreferences(
    databaseValue: 'food_preferences',
    label: 'Preferências alimentares',
    description:
        'Treino linguístico sobre gostos, alimentos preferidos e pedidos simples.',
    profiles: [
      UserProfileType.student,
      UserProfileType.host,
    ],
  ),
  allergiesTraining(
    databaseValue: 'allergies_training',
    label: 'Treino sobre alergias',
    description:
        'Apenas treino linguístico. Não deve guardar alergias reais do utilizador.',
    profiles: [
      UserProfileType.student,
      UserProfileType.host,
    ],
  ),
  houseRules(
    databaseValue: 'house_rules',
    label: 'Regras da casa',
    description:
        'Comunicação sobre chaves, portas, horários, espaços e regras básicas.',
    profiles: [
      UserProfileType.student,
      UserProfileType.host,
    ],
  ),
  pets(
    databaseValue: 'pets',
    label: 'Animais domésticos',
    description:
        'Frases de aviso e cuidado relacionadas com animais da casa.',
    profiles: [
      UserProfileType.student,
      UserProfileType.host,
    ],
  ),
  transport(
    databaseValue: 'transport',
    label: 'Transportes',
    description:
        'Perguntas e instruções sobre deslocações, caminhos e transporte.',
    profiles: [
      UserProfileType.student,
      UserProfileType.host,
    ],
  ),
  school(
    databaseValue: 'school',
    label: 'Escola',
    description:
        'Comunicação relacionada com chegada à escola, colegas, salas e rotina escolar.',
    profiles: [
      UserProfileType.student,
      UserProfileType.host,
      UserProfileType.teacher,
    ],
  ),
  classroom(
    databaseValue: 'classroom',
    label: 'Sala de aula',
    description:
        'Atividades de comunicação em sala de aula e interação com professores.',
    profiles: [
      UserProfileType.student,
      UserProfileType.teacher,
    ],
  ),
  presentation(
    databaseValue: 'presentation',
    label: 'Apresentações',
    description:
        'Treino de frases para apresentações, trabalhos e participação oral.',
    profiles: [
      UserProfileType.student,
      UserProfileType.teacher,
    ],
  ),
  informalConversation(
    databaseValue: 'informal_conversation',
    label: 'Conversa informal',
    description:
        'Diálogos simples com colegas, anfitriões ou outras pessoas do contexto escolar.',
    profiles: [
      UserProfileType.student,
      UserProfileType.host,
      UserProfileType.teacher,
    ],
  );

  const CommunicationScenario({
    required this.databaseValue,
    required this.label,
    required this.description,
    required this.profiles,
  });

  final String databaseValue;
  final String label;
  final String description;

  /// Perfis para os quais este cenário é relevante.
  final List<UserProfileType> profiles;

  /// Verifica se o cenário é adequado para determinado perfil.
  bool supportsProfile(UserProfileType profile) {
    return profiles.contains(profile);
  }

  /// Converte um valor guardado na base de dados para enum.
  ///
  /// Se o valor for inválido ou inexistente, assume "sala de aula" como padrão.
  static CommunicationScenario fromDatabase(String? value) {
    return tryFromDatabase(value) ?? CommunicationScenario.classroom;
  }

  /// Tenta converter um valor guardado na base de dados para enum.
  ///
  /// Retorna null se o valor não for reconhecido.
  static CommunicationScenario? tryFromDatabase(String? value) {
    if (value == null) {
      return null;
    }

    for (final scenario in CommunicationScenario.values) {
      if (scenario.databaseValue == value) {
        return scenario;
      }
    }

    return null;
  }

  /// Lista os cenários adequados a um perfil.
  static List<CommunicationScenario> forProfile(UserProfileType profile) {
    return CommunicationScenario.values
        .where((scenario) => scenario.supportsProfile(profile))
        .toList();
  }
}