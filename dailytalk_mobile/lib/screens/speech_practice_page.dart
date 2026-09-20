import 'package:flutter/material.dart';

import '../widgets/learning_language_quick_switcher.dart';

import '../domain/learning/learning_models.dart';

/// Runtime leve para missões de fala do Learning Path.
///
/// Schema v2 recebe os prompts autorados da revisão. Conteúdo legado (schema
/// v1) continua executável através de um pequeno banco compatível, tal como os
/// runtimes legados de vocabulário/diálogo/quiz/revisão.
///
/// Esta versão pratica repetição guiada. A confirmação é manual; reconhecimento
/// automático de voz será uma capacidade separada quando existir ASR real.
final class SpeechPracticePage extends StatefulWidget {
  const SpeechPracticePage({
    super.key,
    this.execution,
    this.contentDefaultLocale = 'pt-PT',
  });

  final SpeechActivityExecution? execution;
  final String contentDefaultLocale;

  @override
  State<SpeechPracticePage> createState() => _SpeechPracticePageState();
}

final class _SpeechPracticePageState extends State<SpeechPracticePage> {
  int _index = 0;
  bool _finished = false;

  List<String> _prompts(BuildContext context) {
    final execution = widget.execution;
    if (execution == null) {
      return const <String>[
        'Bonjour !',
        'Je m’appelle Paulo.',
        'Merci beaucoup.',
      ];
    }

    final locale = Localizations.localeOf(context).toLanguageTag();
    return <String>[
      for (final prompt in execution.prompts)
        prompt.text.resolve(
          locale,
          fallbackLocale: widget.contentDefaultLocale,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final prompts = _prompts(context);
    final palette = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F3FD),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF071C25),
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: const Text(
          'DailyTalk.pt',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: const <Widget>[LearningLanguageQuickSwitcher()],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
              children: <Widget>[
                if (!_finished) ...<Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAE2FD),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(
                          Icons.mic_rounded,
                          color: Color(0xFF8258E8),
                          size: 27,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Fala',
                              style: palette.textTheme.labelLarge?.copyWith(
                                color: const Color(0xFF8258E8),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'Pratica em voz alta',
                              style: palette.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            minHeight: 8,
                            value: (_index + 1) / prompts.length,
                            backgroundColor: const Color(0xFFE4DDF8),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF8258E8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${_index + 1}/${prompts.length}',
                        style: const TextStyle(
                          color: Color(0xFF6A5A93),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    key: const ValueKey<String>('speech-prompt-card'),
                    padding: const EdgeInsets.fromLTRB(22, 28, 22, 26),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: const Color(0xFFD8CBF8)),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          blurRadius: 24,
                          offset: Offset(0, 10),
                          color: Color(0x14000000),
                        ),
                      ],
                    ),
                    child: Column(
                      children: <Widget>[
                        const CircleAvatar(
                          radius: 34,
                          backgroundColor: Color(0xFFEAE2FD),
                          child: Icon(
                            Icons.record_voice_over_rounded,
                            color: Color(0xFF8258E8),
                            size: 34,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Repete esta frase em voz alta',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF60717A),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          prompts[_index],
                          key: const ValueKey<String>('speech-current-prompt'),
                          textAlign: TextAlign.center,
                          style: palette.textTheme.headlineSmall?.copyWith(
                            color: const Color(0xFF1F2933),
                            fontWeight: FontWeight.w900,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    key: const ValueKey<String>('speech-confirm-repeat'),
                    onPressed: () {
                      if (_index < prompts.length - 1) {
                        setState(() {
                          _index++;
                        });
                        return;
                      }

                      setState(() {
                        _finished = true;
                      });
                    },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      backgroundColor: const Color(0xFF8258E8),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    icon: const Icon(Icons.check_rounded),
                    label: Text(
                      _index == prompts.length - 1
                          ? 'Terminar prática'
                          : 'Já repeti',
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Repete ao teu ritmo. A conclusão da missão será ligada ao progresso local numa etapa seguinte.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: Color(0xFF71858E),
                    ),
                  ),
                ] else ...<Widget>[
                  const SizedBox(height: 54),
                  const CircleAvatar(
                    radius: 46,
                    backgroundColor: Color(0xFFEAE2FD),
                    child: Icon(
                      Icons.check_rounded,
                      color: Color(0xFF8258E8),
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Prática terminada',
                    textAlign: TextAlign.center,
                    style: palette.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Repetiste todas as frases desta prática.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF60717A), fontSize: 16),
                  ),
                  const SizedBox(height: 26),
                  FilledButton.icon(
                    key: const ValueKey<String>('speech-back-to-mission'),
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      backgroundColor: const Color(0xFF8258E8),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text(
                      'Voltar à missão',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
