/// Utilizador autenticado no DailyTalk.pt.
///
/// Este modelo representa apenas os dados seguros que a API pode devolver
/// à aplicação. A password e o hash nunca devem chegar ao Flutter.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.preferences,
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final AuthUserPreferences preferences;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'role': role,
    'preferences': preferences.toJson(),
  };

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? 'student',
      preferences: AuthUserPreferences.fromJson(
        json['preferences'] is Map
            ? Map<String, dynamic>.from(json['preferences'] as Map)
            : const {},
      ),
    );
  }
}

/// Preferências guardadas no perfil remoto do utilizador.
class AuthUserPreferences {
  const AuthUserPreferences({
    required this.appLanguageCode,
    required this.learningLanguageCode,
    required this.selectedProfile,
    required this.difficultyLevel,
  });

  final String appLanguageCode;
  final String learningLanguageCode;
  final String selectedProfile;
  final String difficultyLevel;

  Map<String, dynamic> toJson() => {
    'appLanguageCode': appLanguageCode,
    'learningLanguageCode': learningLanguageCode,
    'selectedProfile': selectedProfile,
    'difficultyLevel': difficultyLevel,
  };

  factory AuthUserPreferences.fromJson(Map<String, dynamic> json) {
    return AuthUserPreferences(
      appLanguageCode: json['appLanguageCode']?.toString() ?? 'pt-PT',
      learningLanguageCode: json['learningLanguageCode']?.toString() ?? 'it-IT',
      selectedProfile: json['selectedProfile']?.toString() ?? 'student',
      difficultyLevel: json['difficultyLevel']?.toString() ?? 'beginner',
    );
  }
}
