import 'package:flutter/material.dart';

import '../data/dao/app_settings_dao.dart';
import '../data/database/app_database.dart';
import '../models/user_profile.dart';

import '../state/app_event_notifier.dart';

/// Página de seleção do perfil de utilização.
///
/// O perfil será usado futuramente para adaptar:
/// - cenários apresentados;
/// - atividades sugeridas;
/// - tipo de treino;
/// - resultados;
/// - análises pedagógicas.
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

  /// Guarda o perfil selecionado no SQLite.
  Future<void> _saveSelectedProfile() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final db = await AppDatabase.instance.database;
      final settingsDao = AppSettingsDao(db);

      await settingsDao.setSelectedProfile(_selectedProfile);
      AppEventNotifier.instance.notifyProfileChanged();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Perfil guardado: ${_selectedProfile.label}')),
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
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B22),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B22),
        foregroundColor: Colors.white,
        title: const Text('Perfil'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    _buildIntroCard(),
                    const SizedBox(height: 18),

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

                    const SizedBox(height: 10),

                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveSelectedProfile,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check),
                        label: Text(
                          _isSaving ? 'A guardar...' : 'Guardar perfil',
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  /// Cartão introdutório da página.
  Widget _buildIntroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF14252D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.person_pin_circle,
            color: Colors.lightBlueAccent,
            size: 54,
          ),
          SizedBox(height: 12),
          Text(
            'Escolhe o teu perfil',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'O perfil será usado para adaptar os cenários e atividades ao papel do utilizador no contexto escolar.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
        ],
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
        color: Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent),
      ),
      child: Text(
        _errorMessage!,
        style: const TextStyle(color: Colors.redAccent),
      ),
    );
  }

  /// Ícone visual associado ao perfil.
  IconData _iconForProfile(UserProfileType profile) {
    switch (profile) {
      case UserProfileType.student:
        return Icons.school;
      case UserProfileType.host:
        return Icons.home;
      case UserProfileType.teacher:
        return Icons.co_present;
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

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? Colors.lightBlueAccent : Colors.white12;
    final backgroundColor = selected
        ? Colors.lightBlue.withValues(alpha: 0.16)
        : const Color(0xFF14252D);

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.lightBlueAccent, size: 38),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      profile.description,
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? Colors.lightBlueAccent : Colors.white38,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
