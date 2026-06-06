import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

import '../data/dao/app_settings_dao.dart';
import '../data/database/app_database.dart';
import '../data/repositories/auth_repository.dart';
import '../state/app_locale_controller.dart';
import '../state/app_session_controller.dart';

/// Página de configuração dos idiomas do DailyTalk.pt.
///
/// Esta tela mantém o título "Language" no topo para facilitar o regresso
/// ao idioma da aplicação, mesmo quando o utilizador escolhe outro idioma
/// por engano.
///
/// O utilizador escolhe:
/// - o idioma que normalmente utiliza na aplicação;
/// - o idioma que quer aprender/praticar nas atividades.
class LanguageSelectionPage extends StatefulWidget {
  const LanguageSelectionPage({super.key});

  @override
  State<LanguageSelectionPage> createState() => _LanguageSelectionPageState();
}

class _LanguageSelectionPageState extends State<LanguageSelectionPage> {
  String _nativeLanguageCode = 'pt-PT';
  String _targetLanguageCode = 'it-IT';
  bool _isLoading = true;
  bool _isSaving = false;

  static const Color _backgroundColor = Color(0xFF061823);
  static const Color _cardColor = Color(0xFF071D2A);
  static const Color _accentColor = Color(0xFF35C8FF);

  final List<LanguageOption> _languages = const [
    LanguageOption(
      code: 'pt-PT',
      name: 'Português',
      description: 'Português de Portugal',
      flag: '🇵🇹',
    ),
    LanguageOption(
      code: 'en-US',
      name: 'English',
      description: 'English - United States',
      flag: '🇺🇸',
    ),
    LanguageOption(
      code: 'es-ES',
      name: 'Español',
      description: 'Spanish - Spain',
      flag: '🇪🇸',
    ),
    LanguageOption(
      code: 'fr-FR',
      name: 'Français',
      description: 'French - France',
      flag: '🇫🇷',
    ),
    LanguageOption(
      code: 'it-IT',
      name: 'Italiano',
      description: 'Italian - Italy',
      flag: '🇮🇹',
    ),
    LanguageOption(
      code: 'de-DE',
      name: 'Deutsch',
      description: 'German - Germany',
      flag: '🇩🇪',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadSavedLanguages();
  }

  Future<void> _loadSavedLanguages() async {
    final db = await AppDatabase.instance.database;
    final settingsDao = AppSettingsDao(db);

    // Primeiro lê a cache local para manter a aplicação funcional mesmo sem rede.
    var nativeLanguageCode = await settingsDao.getNativeLanguageCode();
    var targetLanguageCode = await settingsDao.getTargetLanguageCode();

    try {
      // Depois tenta obter o perfil remoto. Isto resolve o caso em que os
      // idiomas foram alterados noutro dispositivo, por exemplo no Android,
      // e a versão Web ainda tem uma cache local antiga.
      final currentUser = AppSessionController.instance.isAuthenticated
          ? await AuthRepository().getCurrentUser()
          : null;

      if (currentUser != null) {
        nativeLanguageCode = _normalizeLanguageCode(
          currentUser.preferences.appLanguageCode,
          fallbackCode: nativeLanguageCode,
        );
        targetLanguageCode = _normalizeLanguageCode(
          currentUser.preferences.learningLanguageCode,
          fallbackCode: targetLanguageCode,
        );

        // Atualiza a cache local para que as próximas aberturas da página
        // apresentem os mesmos idiomas que aparecem em Conta.
        await settingsDao.setLanguagePair(
          nativeLanguageCode: nativeLanguageCode,
          targetLanguageCode: targetLanguageCode,
        );
      }
    } catch (_) {
      // Se a sessão ou a API não estiverem disponíveis, mantém a cache local.
      // Isto evita bloquear o ecrã Language em modo offline ou durante testes.
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _nativeLanguageCode = nativeLanguageCode;
      _targetLanguageCode = targetLanguageCode;
      _isLoading = false;
    });
  }

  Future<void> _saveLanguages() async {
    if (_nativeLanguageCode == _targetLanguageCode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText(
            'Escolhe dois idiomas diferentes.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final session = AppSessionScope.read(context);
    final localeController = AppLocaleScope.read(context);

    try {
      final db = await AppDatabase.instance.database;
      final settingsDao = AppSettingsDao(db);

      await settingsDao.setLanguagePair(
        nativeLanguageCode: _nativeLanguageCode,
        targetLanguageCode: _targetLanguageCode,
      );

      // Atualiza imediatamente toda a interface. O título "Language" é a
      // única exceção e permanece em inglês para facilitar a recuperação.
      await localeController.setLanguageCode(_nativeLanguageCode);

      if (!mounted) {
        return;
      }

      if (!session.isAuthenticated) {
        if (!mounted) {
          return;
        }

        final nativeLanguage = _languageByCode(_nativeLanguageCode);
        final targetLanguage = _languageByCode(_targetLanguageCode);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: AppText(
              context.tr(
                'Guardado neste dispositivo: {source} → {target}. Entra para sincronizar.',
                parameters: <String, Object?>{
                  'source': nativeLanguage.name,
                  'target': targetLanguage.name,
                },
              ),
            ),
          ),
        );

        Navigator.pop(context);
        return;
      }

      /// Tenta sincronizar as preferências com o perfil remoto apenas quando
      /// existe sessão autenticada. Em modo teste, a preferência fica local.
      final updatedUser = await AuthRepository().updatePreferences(
        appLanguageCode: _nativeLanguageCode,
        learningLanguageCode: _targetLanguageCode,
      );

      final savedNativeLanguageCode = _normalizeLanguageCode(
        updatedUser.preferences.appLanguageCode,
        fallbackCode: _nativeLanguageCode,
      );
      final savedTargetLanguageCode = _normalizeLanguageCode(
        updatedUser.preferences.learningLanguageCode,
        fallbackCode: _targetLanguageCode,
      );

      // Garante que a cache local fica igual ao valor efetivamente devolvido
      // pela API, evitando divergência entre Conta e Language.
      await settingsDao.setLanguagePair(
        nativeLanguageCode: savedNativeLanguageCode,
        targetLanguageCode: savedTargetLanguageCode,
      );

      await localeController.setLanguageCode(savedNativeLanguageCode);

      if (!mounted) {
        return;
      }

      setState(() {
        _nativeLanguageCode = savedNativeLanguageCode;
        _targetLanguageCode = savedTargetLanguageCode;
      });

      final nativeLanguage = _languageByCode(savedNativeLanguageCode);
      final targetLanguage = _languageByCode(savedTargetLanguageCode);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AppText(
            context.tr(
              'Guardado: {source} → {target}',
              parameters: <String, Object?>{
                'source': nativeLanguage.name,
                'target': targetLanguage.name,
              },
            ),
          ),
        ),
      );

      Navigator.pop(context);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: AppText('Erro ao guardar idiomas: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _normalizeLanguageCode(
    String? code, {
    required String fallbackCode,
  }) {
    final hasLanguage = _languages.any((language) => language.code == code);

    if (hasLanguage) {
      return code!;
    }

    return fallbackCode;
  }

  LanguageOption _languageByCode(String code) {
    return _languages.firstWhere(
      (language) => language.code == code,
      orElse: () => _languages.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = AppSessionScope.watch(context);
    final nativeLanguage = _languageByCode(_nativeLanguageCode);
    final targetLanguage = _languageByCode(_targetLanguageCode);

    final screenHeight = MediaQuery.sizeOf(context).height;
    final isCompact = screenHeight < 760;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: const AppText(
          'Language',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.25,
                  colors: [
                    Color(0xFF103653),
                    Color(0xFF061823),
                    Color(0xFF041019),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: isCompact ? 160 : 205,
            child: IgnorePointer(
              child: Opacity(
                opacity: isCompact ? 0.46 : 0.58,
                child: Image.asset(
                  'assets/branding/dailytalk_login_footer.png',
                  fit: BoxFit.fitWidth,
                  alignment: Alignment.bottomCenter,
                  errorBuilder: (context, error, stackTrace) {
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ),

          _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: _accentColor,
                  ),
                )
              : SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        22,
                        isCompact ? 10 : 18,
                        22,
                        isCompact ? 38 : 52,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 460),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildIntroCard(isCompact: isCompact),

                              if (!session.isAuthenticated) ...[
                                const SizedBox(height: 12),
                                _buildLocalOnlyInfoCard(),
                              ],

                              SizedBox(height: isCompact ? 14 : 18),

                              _buildLanguageSelector(
                                title: 'Idioma da aplicação',
                                description:
                                    'Escolhe o idioma que usas normalmente. Este idioma pode ser usado para menus, mensagens e feedback.',
                                selectedCode: _nativeLanguageCode,
                                selectedLanguage: nativeLanguage,
                                onChanged: (value) {
                                  if (value == null) {
                                    return;
                                  }

                                  setState(() {
                                    _nativeLanguageCode = value;
                                  });
                                },
                              ),

                              SizedBox(height: isCompact ? 14 : 18),

                              _buildLanguageSelector(
                                title: 'Idioma a praticar',
                                description:
                                    'Escolhe o idioma que queres treinar em diálogos, áudios, quizzes e desafios.',
                                selectedCode: _targetLanguageCode,
                                selectedLanguage: targetLanguage,
                                onChanged: (value) {
                                  if (value == null) {
                                    return;
                                  }

                                  setState(() {
                                    _targetLanguageCode = value;
                                  });
                                },
                              ),

                              SizedBox(height: isCompact ? 16 : 20),

                              _buildLearningPathCard(
                                nativeLanguage: nativeLanguage,
                                targetLanguage: targetLanguage,
                              ),

                              SizedBox(height: isCompact ? 20 : 26),

                              _buildPrimaryButton(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildIntroCard({required bool isCompact}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isCompact ? 16 : 18),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _buildLanguageBadge(isCompact: isCompact),

          const SizedBox(height: 12),

          const AppText(
            'Escolhe os teus idiomas',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),

          const SizedBox(height: 8),

          AppText(
            'O DailyTalk.pt adapta as atividades ao idioma que já conheces e ao idioma que queres praticar.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.74),
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocalOnlyInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _accentColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _accentColor.withValues(alpha: 0.38),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: _accentColor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: AppText(
              'Modo teste: os idiomas podem ser alterados, mas ficam apenas neste dispositivo até entrares na conta.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 13.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageBadge({required bool isCompact}) {
    final badgeSize = isCompact ? 70.0 : 82.0;

    return Container(
      width: badgeSize,
      height: badgeSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF52D8FF),
            Color(0xFF168CFF),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: _accentColor.withValues(alpha: 0.26),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(5),
        decoration: const BoxDecoration(
          color: Color(0xFF092333),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.translate,
          color: _accentColor,
          size: 40,
        ),
      ),
    );
  }

  Widget _buildLanguageSelector({
    required String title,
    required String description,
    required String selectedCode,
    required LanguageOption selectedLanguage,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: AppText(
                  selectedLanguage.flag,
                  style: const TextStyle(fontSize: 28),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    AppText(
                      selectedLanguage.description,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.58),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          AppText(
            description,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.70),
              fontSize: 14,
              height: 1.35,
            ),
          ),

          const SizedBox(height: 14),

          DropdownButtonFormField<String>(
            initialValue: selectedCode,
            dropdownColor: const Color(0xFF102A38),
            iconEnabledColor: Colors.white.withValues(alpha: 0.74),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
            decoration: _dropdownDecoration(),
            items: _languages.map((language) {
              return DropdownMenuItem<String>(
                value: language.code,
                child: AppText('${language.flag}  ${language.name}'),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildLearningPathCard({
    required LanguageOption nativeLanguage,
    required LanguageOption targetLanguage,
  }) {
    final hasSameLanguage = nativeLanguage.code == targetLanguage.code;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: hasSameLanguage
            ? Colors.orange.withValues(alpha: 0.12)
            : _accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: hasSameLanguage
              ? Colors.orangeAccent.withValues(alpha: 0.56)
              : _accentColor.withValues(alpha: 0.48),
        ),
      ),
      child: Column(
        children: [
          AppText(
            hasSameLanguage ? 'Atenção' : 'Percurso de aprendizagem',
            style: TextStyle(
              color: hasSameLanguage ? Colors.orangeAccent : _accentColor,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 13),

          AppText(
            '${nativeLanguage.flag} ${nativeLanguage.name}  →  '
            '${targetLanguage.flag} ${targetLanguage.name}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 10),

          AppText(
            hasSameLanguage
                ? 'Escolhe idiomas diferentes para que as atividades tenham um objetivo de aprendizagem claro.'
                : 'As atividades serão preparadas com base no idioma que conheces e no idioma que queres praticar.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 14,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton() {
    return SizedBox(
      height: 60,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: _isSaving
              ? LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.22),
                    Colors.white.withValues(alpha: 0.14),
                  ],
                )
              : const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFF49D7FF),
                    Color(0xFF168CFF),
                  ],
                ),
          boxShadow: _isSaving
              ? []
              : [
                  BoxShadow(
                    color: const Color(0xFF168CFF).withValues(alpha: 0.34),
                    blurRadius: 22,
                    offset: const Offset(0, 9),
                  ),
                ],
        ),
        child: ElevatedButton.icon(
          onPressed: _isSaving ? null : _saveLanguages,
          icon: _isSaving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : const Icon(
                  Icons.check,
                  size: 25,
                ),
          label: AppText(
            _isSaving ? 'A guardar...' : 'Guardar idiomas',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          style: ElevatedButton.styleFrom(
            elevation: 0,
            shadowColor: Colors.transparent,
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white70,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: _cardColor.withValues(alpha: 0.82),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.14),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.18),
          blurRadius: 18,
          offset: const Offset(0, 9),
        ),
      ],
    );
  }

  InputDecoration _dropdownDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: _backgroundColor.withValues(alpha: 0.76),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: 0.20),
          width: 1.25,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: _accentColor,
          width: 1.8,
        ),
      ),
    );
  }
}

/// Representa uma opção de idioma disponível na aplicação.
class LanguageOption {
  const LanguageOption({
    required this.code,
    required this.name,
    required this.description,
    required this.flag,
  });

  final String code;
  final String name;
  final String description;
  final String flag;
}