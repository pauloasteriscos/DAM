import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/audio_speed_control_style.dart';
import '../state/audio_speed_preferences_controller.dart';
import 'audio_speed_preferences_page.dart';

/// Área única para preferências visuais e de interação do DailyTalk.pt.
///
/// A estrutura foi criada para receber novas preferências de apresentação
/// (como aparência claro/escuro) sem espalhar opções específicas pela página
/// principal de Ajustes.
final class PersonalizationPage extends StatefulWidget {
  const PersonalizationPage({super.key, this.audioController});

  final AudioSpeedPreferencesController? audioController;

  @override
  State<PersonalizationPage> createState() => _PersonalizationPageState();
}

final class _PersonalizationPageState extends State<PersonalizationPage> {
  late final AudioSpeedPreferencesController _audioController;

  @override
  void initState() {
    super.initState();
    _audioController =
        widget.audioController ?? AudioSpeedPreferencesController.instance;
    _audioController.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF061823),
      appBar: AppBar(
        backgroundColor: const Color(0xFF061823),
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: const AppText(
          'Personalização',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _buildIntroCard(),
                  const SizedBox(height: 22),
                  _buildSectionTitle('Áudio'),
                  AnimatedBuilder(
                    animation: _audioController,
                    builder: (context, _) {
                      return _PreferenceCard(
                        key: const ValueKey<String>(
                          'personalization-audio-speed-style',
                        ),
                        icon: Icons.graphic_eq_rounded,
                        title: 'Estilo da velocidade do áudio',
                        description:
                            'Escolher como o controlo de velocidade aparece nas atividades.',
                        value: _styleLabel(_audioController.style),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (context) => AudioSpeedPreferencesPage(
                                controller: _audioController,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIntroCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0B2532),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFF35C8FF).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: const Color(0xFF35C8FF).withValues(alpha: 0.26),
              ),
            ),
            child: const Icon(
              Icons.tune_rounded,
              color: Color(0xFF35C8FF),
              size: 27,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const AppText(
                  'Personaliza a tua experiência',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                AppText(
                  'Estas preferências alteram apenas a apresentação e a interação da aplicação.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.70),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: AppText(
        title,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.74),
          fontSize: 14,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  static String _styleLabel(AudioSpeedControlStyle style) {
    return switch (style) {
      AudioSpeedControlStyle.buttons => 'Botões',
      AudioSpeedControlStyle.slider => 'Linha',
      AudioSpeedControlStyle.compact => 'Compacto',
    };
  }
}

final class _PreferenceCard extends StatelessWidget {
  const _PreferenceCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF071D2A).withValues(alpha: 0.82),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.14),
              width: 1.2,
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF35C8FF).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF35C8FF).withValues(alpha: 0.26),
                  ),
                ),
                child: Icon(icon, color: const Color(0xFF35C8FF), size: 29),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    AppText(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    AppText(
                      description,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.68),
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      value,
                      style: const TextStyle(
                        color: Color(0xFF35C8FF),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.white.withValues(alpha: 0.46),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
