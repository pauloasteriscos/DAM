/// Perfis principais da aplicação DailyTalk.pt.
///
/// Estes perfis serão usados para adaptar:
/// - cenários apresentados;
/// - atividades sugeridas;
/// - linguagem dos desafios;
/// - resultados e análises futuras.
enum UserProfileType {
  student(
    databaseValue: 'student',
    label: 'Estudante',
    description:
        'Aluno que pratica comunicação em situações reais do quotidiano escolar.',
  ),
  host(
    databaseValue: 'host',
    label: 'Anfitrião',
    description:
        'Pessoa que se prepara para receber e comunicar melhor com o aluno visitante.',
  ),
  teacher(
    databaseValue: 'teacher',
    label: 'Professor',
    description:
        'Perfil pedagógico previsto para acompanhamento, validação e análise.',
  );

  const UserProfileType({
    required this.databaseValue,
    required this.label,
    required this.description,
  });

  final String databaseValue;
  final String label;
  final String description;

  /// Converte um valor guardado na base de dados para enum.
  ///
  /// Se o valor for inválido ou inexistente, assume Estudante como padrão.
  static UserProfileType fromDatabase(String? value) {
    return tryFromDatabase(value) ?? UserProfileType.student;
  }

  /// Tenta converter um valor guardado na base de dados para enum.
  ///
  /// Retorna null se o valor não for reconhecido.
  static UserProfileType? tryFromDatabase(String? value) {
    if (value == null) {
      return null;
    }

    for (final profile in UserProfileType.values) {
      if (profile.databaseValue == value) {
        return profile;
      }
    }

    return null;
  }
}
