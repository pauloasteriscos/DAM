import 'dart:async';

import 'package:flutter/material.dart';

import '../models/audio_speed_control_style.dart';
import '../state/audio_speed_preferences_controller.dart';
import '../widgets/audio_speed_selector.dart';

final class AudioSpeedPreferencesPage extends StatefulWidget {
  const AudioSpeedPreferencesPage({super.key, this.controller});

  final AudioSpeedPreferencesController? controller;

  @override
  State<AudioSpeedPreferencesPage> createState() =>
      _AudioSpeedPreferencesPageState();
}

final class _AudioSpeedPreferencesPageState
    extends State<AudioSpeedPreferencesPage> {
  static const List<double> _previewSpeeds = <double>[0.5, 0.75, 1, 1.25, 1.5];

  late final AudioSpeedPreferencesController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? AudioSpeedPreferencesController.instance;
    unawaited(_controller.ensureLoaded());
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
        title: const Text(
          'Estilo da velocidade do áudio',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _buildIntroCard(),
                      const SizedBox(height: 16),
                      for (final style in AudioSpeedControlStyle.values) ...[
                        _StyleOptionCard(
                          style: style,
                          selected: style == _controller.style,
                          onTap: () => unawaited(_controller.setStyle(style)),
                        ),
                        if (style != AudioSpeedControlStyle.values.last)
                          const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(Icons.tune_rounded, color: Color(0xFF35C8FF), size: 24),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Escolhe como queres controlar a velocidade',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'A escolha muda apenas o estilo do controlo. As cinco velocidades e '
            'a lógica da atividade continuam exatamente iguais.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'A preferência é guardada neste dispositivo.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.54),
              fontSize: 12.5,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

final class _StyleOptionCard extends StatelessWidget {
  const _StyleOptionCard({
    required this.style,
    required this.selected,
    required this.onTap,
  });

  final AudioSpeedControlStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? const Color(0xFF35C8FF)
        : Colors.white.withValues(alpha: 0.12);

    return Material(
      color: const Color(0xFF0B2532),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        key: ValueKey<String>('audio-style-${style.storageValue}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor, width: selected ? 1.8 : 1.1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _titleFor(style),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _descriptionFor(style),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.66),
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: selected
                        ? const Color(0xFF35C8FF)
                        : Colors.white.withValues(alpha: 0.36),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              IgnorePointer(
                child: AudioSpeedSelector(
                  style: style,
                  speeds: _AudioSpeedPreferencesPageState._previewSpeeds,
                  selectedSpeed: 1,
                  onSelected: (_) {},
                  title: style == AudioSpeedControlStyle.compact
                      ? null
                      : 'Velocidade do áudio',
                  keyPrefix: 'audio-style-preview-${style.storageValue}',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _titleFor(AudioSpeedControlStyle style) {
    return switch (style) {
      AudioSpeedControlStyle.buttons => 'Botões',
      AudioSpeedControlStyle.slider => 'Linha',
      AudioSpeedControlStyle.compact => 'Compacto',
    };
  }

  static String _descriptionFor(AudioSpeedControlStyle style) {
    return switch (style) {
      AudioSpeedControlStyle.buttons =>
        'Cinco opções visíveis com destaque claro da velocidade ativa.',
      AudioSpeedControlStyle.slider =>
        'Uma linha com cinco posições para uma escolha mais fluida.',
      AudioSpeedControlStyle.compact =>
        'Barra reduzida que deixa mais espaço disponível para os cartões.',
    };
  }
}
