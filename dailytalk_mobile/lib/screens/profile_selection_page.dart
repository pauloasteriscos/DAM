import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

import '../data/dao/app_settings_dao.dart';
import '../data/database/app_database.dart';
import '../data/repositories/auth_repository.dart';
import '../models/user_profile.dart';
import '../state/app_event_notifier.dart';
import '../state/app_session_controller.dart';

/// Página de seleção do perfil de utilização.
///
/// O perfil adapta cenários, atividades sugeridas, tipo de treino,
/// resultados e análises pedagógicas ao papel do utilizador.
class ProfileSelectionPage extends StatefulWidget {
  const ProfileSelectionPage({super.key});

  @override
  State<ProfileSelectionPage> createState() => _ProfileSelectionPageState();
}

class _ProfileSelectionPageState extends State<ProfileSelectionPage> {
  UserProfileType _selectedProfile = UserProfileType.student;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  static const Color _backgroundColor = Color(0xFF061823);
  static const Color _cardColor = Color(0xFF071D2A);
  static const Color _accentColor = Color(0xFF35C8FF);

  @override
  void initState() {
    super.initState();
    _loadSelectedProfile();
  }

  /// Carrega o perfil atualmente guardado no SQLite.
  Future<void> _loadSelectedProfile() async {
    try {
      final db = await AppDatabase.instance.database;
      final settingsDao = AppSettingsDao(db);

      final selectedProfile = await settingsDao.getSelectedProfile();

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedProfile = selectedProfile;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  /// Guarda o perfil selecionado no SQLite e tenta sincronizar no backend.
  Future<void> _saveSelectedProfile() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final session = AppSessionScope.read(context);

    try {
      final db = await AppDatabase.instance.database;
      final settingsDao = AppSettingsDao(db);

      await settingsDao.setSelectedProfile(_selectedProfile);

      if (session.isAuthenticated) {
        await AuthRepository().updatePreferences(
          selectedProfile: _selectedProfile.databaseValue,
        );
      }

      AppEventNotifier.instance.notifyProfileChanged();

      if (!mounted) {
        return;
      }

      final message = session.isAuthenticated
          ? context.tr(
              'Perfil guardado: {profile}',
              parameters: <String, Object?>{
                'profile': context.tr(_selectedProfile.label),
              },
            )
          : context.tr(
              'Perfil guardado neste dispositivo. Entra para sincronizar.',
            );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: AppText(message)),
      );

      Navigator.pop(context);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = AppSessionScope.watch(context);
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
          'Perfil',
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
                opacity: isCompact ? 0.44 : 0.56,
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

          SafeArea(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: _accentColor),
                  )
                : Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        22,
                        isCompact ? 10 : 18,
                        22,
                        isCompact ? 40 : 54,
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

                              for (final profile in UserProfileType.values) ...[
                                _ProfileOptionCard(
                                  profile: profile,
                                  selected: profile == _selectedProfile,
                                  icon: _iconForProfile(profile),
                                  onTap: () {
                                    setState(() {
                                      _selectedProfile = profile;
                                    });
                                  },
                                ),
                                const SizedBox(height: 12),
                              ],

                              if (_errorMessage != null) _buildErrorBox(),

                              SizedBox(height: isCompact ? 8 : 12),

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

  /// Cartão introdutório da página.
  Widget _buildIntroCard({required bool isCompact}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isCompact ? 16 : 18),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _buildProfileBadge(isCompact: isCompact),

          const SizedBox(height: 12),

          const AppText(
            'Escolhe o teu perfil',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),

          const SizedBox(height: 8),

          AppText(
            'O DailyTalk.pt adapta os cenários e atividades ao teu papel no contexto escolar.',
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
              'Modo teste: o perfil pode ser ajustado localmente, mas só será sincronizado depois de entrares na conta.',
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

  Widget _buildProfileBadge({required bool isCompact}) {
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
          Icons.person_pin_circle_outlined,
          color: _accentColor,
          size: 40,
        ),
      ),
    );
  }

  /// Caixa visual para apresentar erros de leitura ou gravação.
  Widget _buildErrorBox() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4, bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.redAccent.withValues(alpha: 0.85),
        ),
      ),
      child: AppText(
        _errorMessage!,
        style: const TextStyle(
          color: Colors.redAccent,
          fontWeight: FontWeight.w600,
        ),
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
          onPressed: _isSaving ? null : _saveSelectedProfile,
          icon: _isSaving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check, size: 25),
          label: AppText(
            _isSaving ? 'A guardar...' : 'Guardar perfil',
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

  /// Ícone visual associado ao perfil.
  IconData _iconForProfile(UserProfileType profile) {
    switch (profile) {
      case UserProfileType.student:
        return Icons.school_outlined;
      case UserProfileType.host:
        return Icons.home_outlined;
      case UserProfileType.teacher:
        return Icons.co_present_outlined;
    }
  }
}

/// Cartão de seleção de perfil.
class _ProfileOptionCard extends StatelessWidget {
  const _ProfileOptionCard({
    required this.profile,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  final UserProfileType profile;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  static const Color _cardColor = Color(0xFF071D2A);
  static const Color _accentColor = Color(0xFF35C8FF);

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? _accentColor.withValues(alpha: 0.92)
        : Colors.white.withValues(alpha: 0.14);
    final backgroundColor = selected
        ? _accentColor.withValues(alpha: 0.14)
        : _cardColor.withValues(alpha: 0.82);

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: borderColor,
              width: selected ? 1.8 : 1.2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: selected
                      ? _accentColor.withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(
                    color: selected
                        ? _accentColor.withValues(alpha: 0.44)
                        : Colors.white.withValues(alpha: 0.10),
                  ),
                ),
                child: Icon(
                  icon,
                  color: selected
                      ? _accentColor
                      : Colors.white.withValues(alpha: 0.74),
                  size: 30,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      profile.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    AppText(
                      profile.description,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.70),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected
                    ? _accentColor
                    : Colors.white.withValues(alpha: 0.38),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
