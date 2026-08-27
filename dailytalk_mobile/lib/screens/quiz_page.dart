import 'dart:math';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

import '../data/dao/app_settings_dao.dart';
import '../data/database/app_database.dart';
import '../data/repositories/auth_repository.dart';

/// Ecrã de quiz contextualizado do DailyTalk.pt.
///
/// A pergunta e a explicação usam o idioma da aplicação.
/// As respostas usam o idioma que o utilizador quer praticar.
class QuizPage extends StatefulWidget {
  const QuizPage({
    super.key,
    this.userLanguageCode = 'pt-PT',
    this.learningLanguageCode = 'it-IT',
  });

  /// Idioma da aplicação/utilizador.
  final String userLanguageCode;

  /// Idioma que o utilizador quer praticar.
  final String learningLanguageCode;

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  static const Color _backgroundColor = Color(0xFF0D1B22);
  static const Color _cardColor = Color(0xFF071D2A);
  static const Color _panelColor = Color(0xFF10232D);
  static const Color _accentColor = Color(0xFF35C8FF);
  static const Color _primaryBlue = Color(0xFF168CFF);
  static const Color _successColor = Color(0xFF45E08F);
  static const Color _warningColor = Color(0xFFFFC857);
  static const Color _errorColor = Color(0xFFFF5C7A);

  late String _userLanguageCode;
  late String _learningLanguageCode;

  late List<_QuizQuestion> _questions;
  late List<_QuizAnswer> _currentAnswers;

  bool _isLoadingLanguages = true;
  int _currentIndex = 0;
  int _score = 0;
  int _streak = 0;
  int _lives = 3;
  bool _hasAnswered = false;
  String? _selectedAnswerId;

  _QuizQuestion get _currentQuestion => _questions[_currentIndex];

  bool get _isLastQuestion => _currentIndex == _questions.length - 1;

  bool get _isFinished => _currentIndex >= _questions.length;

  @override
  void initState() {
    super.initState();

    // Estes valores só servem como fallback técnico.
    // A ronda real só é preparada depois de ler o perfil/cache local.
    _userLanguageCode = _normaliseLanguageCode(widget.userLanguageCode);
    _learningLanguageCode = _normaliseLanguageCode(widget.learningLanguageCode);

    if (_userLanguageCode == _learningLanguageCode) {
      _learningLanguageCode = _fallbackLearningLanguage(_userLanguageCode);
    }

    Future<void>.microtask(_loadLanguagesFromSettings);
  }

  /// Lê os idiomas da mesma fonte usada pelo ecrã Language.
  ///
  /// Regra do quiz:
  /// - pergunta/cenário/prompt: idioma da aplicação/utilizador;
  /// - alternativas/respostas: idioma que o utilizador quer praticar.
  Future<void> _loadLanguagesFromSettings() async {
    var nextUserLanguage = _userLanguageCode;
    var nextLearningLanguage = _learningLanguageCode;

    try {
      final db = await AppDatabase.instance.database;
      final settingsDao = AppSettingsDao(db);

      // 1) Lê primeiro a cache local, que é atualizada pelo ecrã Language.
      nextUserLanguage = await settingsDao.getNativeLanguageCode();
      nextLearningLanguage = await settingsDao.getTargetLanguageCode();

      try {
        // 2) Depois tenta confirmar com o perfil autenticado.
        // Se a API/sessão não estiver disponível, a cache local continua válida.
        final currentUser = await AuthRepository().getCurrentUser();

        if (currentUser != null) {
          nextUserLanguage = _normaliseLanguageCode(
            currentUser.preferences.appLanguageCode,
            fallbackCode: nextUserLanguage,
          );
          nextLearningLanguage = _normaliseLanguageCode(
            currentUser.preferences.learningLanguageCode,
            fallbackCode: nextLearningLanguage,
          );

          await settingsDao.setLanguagePair(
            nativeLanguageCode: nextUserLanguage,
            targetLanguageCode: nextLearningLanguage,
          );
        }
      } catch (_) {
        // Mantém a cache local quando o perfil remoto não estiver disponível.
      }
    } catch (_) {
      // Se a base local ainda não estiver pronta, usa os valores do construtor.
    }

    nextUserLanguage = _normaliseLanguageCode(
      nextUserLanguage,
      fallbackCode: _userLanguageCode,
    );
    nextLearningLanguage = _normaliseLanguageCode(
      nextLearningLanguage,
      fallbackCode: _learningLanguageCode,
    );

    if (nextUserLanguage == nextLearningLanguage) {
      nextLearningLanguage = _fallbackLearningLanguage(nextUserLanguage);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _userLanguageCode = nextUserLanguage;
      _learningLanguageCode = nextLearningLanguage;
      _prepareQuiz(resetScore: true);
      _isLoadingLanguages = false;
    });
  }

  /// Cria a ronda de perguntas e prepara as respostas da primeira pergunta.
  void _prepareQuiz({required bool resetScore}) {
    _questions = _quizBank.toList()..shuffle(Random());
    _questions = _questions.take(5).toList();

    _currentIndex = 0;
    _selectedAnswerId = null;
    _hasAnswered = false;
    _currentAnswers = _buildAnswersFor(_questions.first);

    if (resetScore) {
      _score = 0;
      _streak = 0;
      _lives = 3;
    }
  }

  /// Constrói e baralha as respostas da pergunta atual.
  List<_QuizAnswer> _buildAnswersFor(_QuizQuestion question) {
    final answers = <_QuizAnswer>[
      _QuizAnswer(
        id: question.correctAnswer.id,
        text: question.correctAnswer.textFor(
          _translationKey(_learningLanguageCode),
        ),
        isCorrect: true,
      ),
      ...question.distractors.map(
        (answer) => _QuizAnswer(
          id: answer.id,
          text: answer.textFor(_translationKey(_learningLanguageCode)),
          isCorrect: false,
        ),
      ),
    ]..shuffle(Random());

    return answers;
  }

  /// Seleciona uma alternativa.
  void _selectAnswer(_QuizAnswer answer) {
    if (_hasAnswered) {
      return;
    }

    setState(() {
      _selectedAnswerId = answer.id;
    });
  }

  /// Confirma a resposta selecionada e atualiza pontuação/vidas.
  void _confirmAnswer() {
    if (_selectedAnswerId == null || _hasAnswered) {
      return;
    }

    final selectedAnswer = _currentAnswers.firstWhere(
      (answer) => answer.id == _selectedAnswerId,
    );

    setState(() {
      _hasAnswered = true;

      if (selectedAnswer.isCorrect) {
        _streak++;
        _score += 40 + (_streak * 10);
      } else {
        _streak = 0;
        _lives = max(0, _lives - 1);
      }
    });
  }

  /// Avança para a próxima pergunta ou reinicia no fim.
  void _nextQuestion() {
    if (!_hasAnswered) {
      return;
    }

    if (_isLastQuestion) {
      setState(() {
        _currentIndex = _questions.length;
      });
      return;
    }

    setState(() {
      _currentIndex++;
      _selectedAnswerId = null;
      _hasAnswered = false;
      _currentAnswers = _buildAnswersFor(_currentQuestion);
    });
  }

  /// Reinicia uma nova ronda do quiz.
  void _restartQuiz() {
    setState(() {
      _prepareQuiz(resetScore: true);
    });
  }

  /// Ação provisória para o botão de áudio.
  void _playAudioPlaceholder() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: AppText(_ui('audioSoon'))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Color(0xFF061823), Color(0xFF0D1B22)],
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                child: Column(
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 18),
                    if (_isLoadingLanguages)
                      _buildLoadingCard()
                    else if (_isFinished)
                      _buildFinishedCard()
                    else ...[
                      _buildProgressCard(),
                      const SizedBox(height: 16),
                      _buildQuestionCard(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Cabeçalho com botão de voltar e marca DailyTalk.pt.
  Widget _buildHeader() {
    return Row(
      children: [
        Material(
          color: _panelColor,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _accentColor.withValues(alpha: 0.35)),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: const Color(0xFF06345C),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _accentColor.withValues(alpha: 0.70),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: _accentColor.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.menu_book, color: Colors.amber, size: 32),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: AppText(
            'DailyTalk.pt',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
        ),
      ],
    );
  }

  /// Cartão temporário enquanto os idiomas do perfil são carregados.
  Widget _buildLoadingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(
        color: _panelColor.withValues(alpha: 0.88),
        borderColor: _accentColor.withValues(alpha: 0.22),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.6,
              valueColor: AlwaysStoppedAnimation<Color>(_accentColor),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: AppText(
              _ui('loadingLanguages'),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.28,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Cartão de progresso da ronda.
  Widget _buildProgressCard() {
    final progress = (_currentIndex + 1) / _questions.length;
    final percent = (progress * 100).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(
        color: _panelColor.withValues(alpha: 0.88),
        borderColor: _accentColor.withValues(alpha: 0.22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AppText(
                  '${_ui('question')} ${_currentIndex + 1} ${_ui('of')} ${_questions.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              AppText(
                '$percent%',
                style: const TextStyle(
                  color: _accentColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation<Color>(_accentColor),
            ),
          ),
        ],
      ),
    );
  }

  /// Cartão principal com cenário, pergunta, respostas e ações.
  Widget _buildQuestionCard() {
    final question = _currentQuestion;
    final nativeKey = _translationKey(_userLanguageCode);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(
        color: _cardColor.withValues(alpha: 0.95),
        borderColor: _accentColor.withValues(alpha: 0.60),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildQuestionTopRow(question),
          const SizedBox(height: 18),
          _buildScenario(question, nativeKey),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withValues(alpha: 0.14)),
          const SizedBox(height: 14),
          _buildPrompt(question, nativeKey),
          const SizedBox(height: 14),
          ...List.generate(_currentAnswers.length, (index) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == _currentAnswers.length - 1 ? 0 : 10,
              ),
              child: _buildAnswerButton(_currentAnswers[index], index),
            );
          }),
          const SizedBox(height: 14),
          _buildFeedbackBox(),
          const SizedBox(height: 14),
          _buildStatusRow(),
          const SizedBox(height: 16),
          _buildPrimaryButton(),
        ],
      ),
    );
  }

  Widget _buildQuestionTopRow(_QuizQuestion question) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: _accentColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(question.icon, color: _accentColor, size: 26),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                question.category.textFor(_translationKey(_userLanguageCode)),
                style: const TextStyle(
                  color: _accentColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              AppText(
                _ui('contextLabel'),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.66),
                  fontSize: 14,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: _playAudioPlaceholder,
          icon: const Icon(Icons.play_arrow, size: 22),
          label: AppText(_ui('listen')),
          style: TextButton.styleFrom(
            foregroundColor: _accentColor,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
        ),
      ],
    );
  }

  Widget _buildScenario(_QuizQuestion question, String nativeKey) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;

        final scenarioText = AppText(
          question.scenario.textFor(nativeKey),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        );

        final visual = Container(
          width: compact ? double.infinity : 172,
          height: compact ? 108 : 130,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _accentColor.withValues(alpha: 0.18),
                _primaryBlue.withValues(alpha: 0.08),
              ],
            ),
            border: Border.all(color: _accentColor.withValues(alpha: 0.22)),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -14,
                bottom: -18,
                child: Icon(
                  question.icon,
                  size: 110,
                  color: _accentColor.withValues(alpha: 0.14),
                ),
              ),
              Center(
                child: Icon(
                  question.visualIcon,
                  size: compact ? 54 : 64,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [scenarioText, const SizedBox(height: 12), visual],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: scenarioText),
            const SizedBox(width: 16),
            visual,
          ],
        );
      },
    );
  }

  Widget _buildPrompt(_QuizQuestion question, String nativeKey) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _accentColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(Icons.quiz_outlined, color: _accentColor, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AppText(
            question.prompt.textFor(nativeKey),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w900,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnswerButton(_QuizAnswer answer, int index) {
    final isSelected = _selectedAnswerId == answer.id;
    final showCorrect = _hasAnswered && answer.isCorrect;
    final showWrong = _hasAnswered && isSelected && !answer.isCorrect;

    Color borderColor = _accentColor.withValues(alpha: 0.45);
    Color backgroundColor = _panelColor.withValues(alpha: 0.68);
    Color badgeColor = _accentColor;
    IconData? trailingIcon;
    Color trailingColor = _accentColor;

    if (isSelected && !_hasAnswered) {
      borderColor = _accentColor;
      backgroundColor = _accentColor.withValues(alpha: 0.12);
    }

    if (showCorrect) {
      borderColor = _successColor;
      backgroundColor = _successColor.withValues(alpha: 0.12);
      badgeColor = _successColor;
      trailingIcon = Icons.check_circle;
      trailingColor = _successColor;
    }

    if (showWrong) {
      borderColor = _errorColor;
      backgroundColor = _errorColor.withValues(alpha: 0.12);
      badgeColor = _errorColor;
      trailingIcon = Icons.cancel;
      trailingColor = _errorColor;
    }

    final letter = String.fromCharCode(65 + index);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selectAnswer(answer),
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          constraints: const BoxConstraints(minHeight: 66),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: borderColor,
              width: isSelected || showCorrect || showWrong ? 2 : 1.2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: badgeColor.withValues(alpha: 0.10),
                  border: Border.all(color: badgeColor, width: 1.6),
                ),
                child: AppText(
                  letter,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: AppText(
                  answer.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ),
              if (trailingIcon != null) ...[
                const SizedBox(width: 10),
                Icon(trailingIcon, color: trailingColor, size: 24),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeedbackBox() {
    if (!_hasAnswered) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: _softBoxDecoration(),
        child: AppText(
          _ui('chooseAnswer'),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.70),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final selectedAnswer = _currentAnswers.firstWhere(
      (answer) => answer.id == _selectedAnswerId,
    );

    final isCorrect = selectedAnswer.isCorrect;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: _softBoxDecoration(
        color: isCorrect
            ? _successColor.withValues(alpha: 0.10)
            : _errorColor.withValues(alpha: 0.10),
        borderColor: isCorrect
            ? _successColor.withValues(alpha: 0.32)
            : _errorColor.withValues(alpha: 0.32),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isCorrect ? Icons.check_circle_outline : Icons.info_outline,
            color: isCorrect ? _successColor : _errorColor,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AppText(
              isCorrect ? _ui('correct') : _ui('wrong'),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.86),
                fontWeight: FontWeight.w700,
                height: 1.32,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: _softBoxDecoration(),
      child: Row(
        children: [
          Expanded(
            child: _StatusMetric(
              icon: Icons.star_rounded,
              iconColor: _warningColor,
              value: '$_score',
              label: _ui('points'),
            ),
          ),
          _buildMetricDivider(),
          Expanded(
            child: _StatusMetric(
              icon: Icons.local_fire_department_rounded,
              iconColor: Colors.deepOrangeAccent,
              value: '$_streak',
              label: _ui('streak'),
            ),
          ),
          _buildMetricDivider(),
          Expanded(
            child: _StatusMetric(
              icon: Icons.favorite_rounded,
              iconColor: _errorColor,
              value: '$_lives',
              label: _ui('lives'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricDivider() {
    return Container(
      width: 1,
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: _accentColor.withValues(alpha: 0.18),
    );
  }

  Widget _buildPrimaryButton() {
    final canConfirm = _selectedAnswerId != null && !_hasAnswered;
    final buttonText = !_hasAnswered
        ? _ui('confirm')
        : _isLastQuestion
        ? _ui('finish')
        : _ui('next');

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: !_hasAnswered
            ? canConfirm
                  ? _confirmAnswer
                  : null
            : _nextQuestion,
        style: ElevatedButton.styleFrom(
          backgroundColor: _accentColor,
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.10),
          foregroundColor: const Color(0xFF05202D),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.35),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 17),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: AppText(
          buttonText,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  Widget _buildFinishedCard() {
    final total = _questions.length;
    final maxScore = total * 90;
    final percentage = maxScore == 0 ? 0 : ((_score / maxScore) * 100).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(
        color: _cardColor.withValues(alpha: 0.96),
        borderColor: _accentColor.withValues(alpha: 0.58),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _accentColor.withValues(alpha: 0.14),
              border: Border.all(
                color: _accentColor.withValues(alpha: 0.70),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: Colors.amber,
              size: 42,
            ),
          ),
          const SizedBox(height: 16),
          AppText(
            _ui('quizCompleted'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          AppText(
            _ui('quizCompletedDescription'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 15,
              height: 1.38,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: _softBoxDecoration(),
            child: Row(
              children: [
                Expanded(
                  child: _StatusMetric(
                    icon: Icons.star_rounded,
                    iconColor: _warningColor,
                    value: '$_score',
                    label: _ui('points'),
                  ),
                ),
                _buildMetricDivider(),
                Expanded(
                  child: _StatusMetric(
                    icon: Icons.percent_rounded,
                    iconColor: _accentColor,
                    value: '$percentage%',
                    label: _ui('performance'),
                  ),
                ),
                _buildMetricDivider(),
                Expanded(
                  child: _StatusMetric(
                    icon: Icons.favorite_rounded,
                    iconColor: _errorColor,
                    value: '$_lives',
                    label: _ui('lives'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _restartQuiz,
              icon: const Icon(Icons.refresh),
              label: AppText(_ui('newRound')),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: const Color(0xFF05202D),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                textStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration({
    Color color = _cardColor,
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: borderColor ?? _accentColor.withValues(alpha: 0.28),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.24),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  BoxDecoration _softBoxDecoration({Color? color, Color? borderColor}) {
    return BoxDecoration(
      color: color ?? _panelColor.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: borderColor ?? _accentColor.withValues(alpha: 0.18),
      ),
    );
  }

  /// Normaliza o código para um dos idiomas existentes na app.
  String _normaliseLanguageCode(String code, {String fallbackCode = 'pt-PT'}) {
    final String value = code.trim();

    if (_availableLanguages.contains(value)) {
      return value;
    }

    final String lower = value.toLowerCase().replaceAll('_', '-');

    if (lower.startsWith('pt')) return 'pt-PT';
    if (lower.startsWith('en')) return 'en-US';
    if (lower.startsWith('es')) return 'es-ES';
    if (lower.startsWith('fr')) return 'fr-FR';
    if (lower.startsWith('it')) return 'it-IT';
    if (lower.startsWith('de')) return 'de-DE';

    return fallbackCode;
  }

  String _fallbackLearningLanguage(String userLanguageCode) {
    return userLanguageCode == 'it-IT' ? 'pt-PT' : 'it-IT';
  }

  /// Converte o código completo da app para a chave curta das traduções.
  String _translationKey(String code) {
    final String lower = code.toLowerCase();

    if (lower.startsWith('pt')) return 'pt';
    if (lower.startsWith('en')) return 'en';
    if (lower.startsWith('es')) return 'es';
    if (lower.startsWith('fr')) return 'fr';
    if (lower.startsWith('it')) return 'it';
    if (lower.startsWith('de')) return 'de';

    return 'pt';
  }

  String _ui(String key) {
    final String languageKey = _translationKey(_userLanguageCode);
    return _uiTexts[languageKey]?[key] ?? _uiTexts['pt']![key] ?? key;
  }
}

/// Métrica compacta usada na área de pontuação.
class _StatusMetric extends StatelessWidget {
  const _StatusMetric({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: iconColor, size: 26),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AppText(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 2),
              AppText(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.62),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuizQuestion {
  const _QuizQuestion({
    required this.id,
    required this.category,
    required this.scenario,
    required this.prompt,
    required this.correctAnswer,
    required this.distractors,
    required this.icon,
    required this.visualIcon,
  });

  final String id;
  final _LocalizedText category;
  final _LocalizedText scenario;
  final _LocalizedText prompt;
  final _LocalizedText correctAnswer;
  final List<_LocalizedText> distractors;
  final IconData icon;
  final IconData visualIcon;
}

class _QuizAnswer {
  const _QuizAnswer({
    required this.id,
    required this.text,
    required this.isCorrect,
  });

  final String id;
  final String text;
  final bool isCorrect;
}

class _LocalizedText {
  const _LocalizedText({required this.id, required this.translations});

  final String id;
  final Map<String, String> translations;

  String textFor(String languageCode) {
    return translations[languageCode] ??
        translations['en'] ??
        translations['pt'] ??
        id;
  }
}

const List<String> _availableLanguages = <String>[
  'pt-PT',
  'en-US',
  'es-ES',
  'fr-FR',
  'it-IT',
  'de-DE',
];

const Map<String, Map<String, String>> _uiTexts = <String, Map<String, String>>{
  'pt': <String, String>{
    'question': 'Pergunta',
    'of': 'de',
    'contextLabel': 'Conversas do dia a dia · Erasmus+',
    'listen': 'Ouvir',
    'audioSoon': 'O áudio desta pergunta será integrado numa próxima versão.',
    'loadingLanguages': 'A carregar os idiomas definidos no perfil...',
    'chooseAnswer': 'Escolhe a melhor resposta no idioma que estás a praticar.',
    'correct':
        'Correto. Esta é uma resposta natural para a situação apresentada.',
    'wrong':
        'Ainda não é a melhor opção. Observa a resposta correta antes de avançar.',
    'points': 'Pontos',
    'streak': 'Sequência',
    'lives': 'Vidas',
    'confirm': 'Confirmar',
    'next': 'Seguinte',
    'finish': 'Terminar',
    'quizCompleted': 'Quiz concluído',
    'quizCompletedDescription':
        'Boa prática. A atividade treinou respostas úteis para situações reais em contexto escolar.',
    'performance': 'Desempenho',
    'newRound': 'Nova ronda',
  },
  'en': <String, String>{
    'question': 'Question',
    'of': 'of',
    'contextLabel': 'Everyday conversations · Erasmus+',
    'listen': 'Listen',
    'audioSoon':
        'Audio for this question will be integrated in a future version.',
    'loadingLanguages': 'Loading the languages defined in your profile...',
    'chooseAnswer':
        'Choose the best answer in the language you are practising.',
    'correct': 'Correct. This is a natural answer for the situation shown.',
    'wrong':
        'That is not the best option yet. Check the correct answer before continuing.',
    'points': 'Points',
    'streak': 'Streak',
    'lives': 'Lives',
    'confirm': 'Confirm',
    'next': 'Next',
    'finish': 'Finish',
    'quizCompleted': 'Quiz completed',
    'quizCompletedDescription':
        'Good practice. This activity trained useful answers for real school situations.',
    'performance': 'Performance',
    'newRound': 'New round',
  },
  'es': <String, String>{
    'question': 'Pregunta',
    'of': 'de',
    'contextLabel': 'Conversaciones del día a día · Erasmus+',
    'listen': 'Escuchar',
    'audioSoon':
        'El audio de esta pregunta se integrará en una próxima versión.',
    'loadingLanguages': 'Cargando los idiomas definidos en tu perfil...',
    'chooseAnswer':
        'Elige la mejor respuesta en el idioma que estás practicando.',
    'correct':
        'Correcto. Es una respuesta natural para la situación presentada.',
    'wrong':
        'Todavía no es la mejor opción. Observa la respuesta correcta antes de continuar.',
    'points': 'Puntos',
    'streak': 'Racha',
    'lives': 'Vidas',
    'confirm': 'Confirmar',
    'next': 'Siguiente',
    'finish': 'Terminar',
    'quizCompleted': 'Quiz completado',
    'quizCompletedDescription':
        'Buena práctica. La actividad entrenó respuestas útiles para situaciones escolares reales.',
    'performance': 'Rendimiento',
    'newRound': 'Nueva ronda',
  },
  'fr': <String, String>{
    'question': 'Question',
    'of': 'sur',
    'contextLabel': 'Conversations du quotidien · Erasmus+',
    'listen': 'Écouter',
    'audioSoon':
        'L’audio de cette question sera intégré dans une prochaine version.',
    'loadingLanguages': 'Chargement des langues définies dans ton profil...',
    'chooseAnswer':
        'Choisis la meilleure réponse dans la langue que tu pratiques.',
    'correct':
        'Correct. C’est une réponse naturelle pour la situation présentée.',
    'wrong':
        'Ce n’est pas encore la meilleure option. Regarde la bonne réponse avant de continuer.',
    'points': 'Points',
    'streak': 'Série',
    'lives': 'Vies',
    'confirm': 'Confirmer',
    'next': 'Suivant',
    'finish': 'Terminer',
    'quizCompleted': 'Quiz terminé',
    'quizCompletedDescription':
        'Bonne pratique. L’activité a entraîné des réponses utiles pour des situations scolaires réelles.',
    'performance': 'Performance',
    'newRound': 'Nouvelle manche',
  },
  'it': <String, String>{
    'question': 'Domanda',
    'of': 'di',
    'contextLabel': 'Conversazioni quotidiane · Erasmus+',
    'listen': 'Ascolta',
    'audioSoon':
        'L’audio di questa domanda sarà integrato in una prossima versione.',
    'loadingLanguages': 'Caricamento delle lingue definite nel profilo...',
    'chooseAnswer':
        'Scegli la risposta migliore nella lingua che stai praticando.',
    'correct':
        'Corretto. È una risposta naturale per la situazione presentata.',
    'wrong':
        'Non è ancora l’opzione migliore. Guarda la risposta corretta prima di continuare.',
    'points': 'Punti',
    'streak': 'Serie',
    'lives': 'Vite',
    'confirm': 'Conferma',
    'next': 'Avanti',
    'finish': 'Termina',
    'quizCompleted': 'Quiz completato',
    'quizCompletedDescription':
        'Buona pratica. L’attività ha allenato risposte utili per situazioni scolastiche reali.',
    'performance': 'Prestazione',
    'newRound': 'Nuovo turno',
  },
  'de': <String, String>{
    'question': 'Frage',
    'of': 'von',
    'contextLabel': 'Alltagsgespräche · Erasmus+',
    'listen': 'Anhören',
    'audioSoon':
        'Audio für diese Frage wird in einer nächsten Version integriert.',
    'loadingLanguages': 'Die im Profil festgelegten Sprachen werden geladen...',
    'chooseAnswer': 'Wähle die beste Antwort in der Sprache, die du übst.',
    'correct':
        'Richtig. Das ist eine natürliche Antwort für die gezeigte Situation.',
    'wrong':
        'Das ist noch nicht die beste Option. Sieh dir die richtige Antwort an, bevor du weitergehst.',
    'points': 'Punkte',
    'streak': 'Serie',
    'lives': 'Leben',
    'confirm': 'Bestätigen',
    'next': 'Weiter',
    'finish': 'Beenden',
    'quizCompleted': 'Quiz abgeschlossen',
    'quizCompletedDescription':
        'Gute Übung. Die Aktivität trainierte nützliche Antworten für reale Schulsituationen.',
    'performance': 'Leistung',
    'newRound': 'Neue Runde',
  },
};

const _LocalizedText _categorySchool = _LocalizedText(
  id: 'category_school',
  translations: <String, String>{
    'pt': 'Na escola',
    'en': 'At school',
    'es': 'En la escuela',
    'fr': 'À l’école',
    'it': 'A scuola',
    'de': 'In der Schule',
  },
);

const _LocalizedText _categoryHostFamily = _LocalizedText(
  id: 'category_host_family',
  translations: <String, String>{
    'pt': 'Família anfitriã',
    'en': 'Host family',
    'es': 'Familia anfitriona',
    'fr': 'Famille d’accueil',
    'it': 'Famiglia ospitante',
    'de': 'Gastfamilie',
  },
);

const _LocalizedText _categoryHelp = _LocalizedText(
  id: 'category_help',
  translations: <String, String>{
    'pt': 'Pedir ajuda',
    'en': 'Asking for help',
    'es': 'Pedir ayuda',
    'fr': 'Demander de l’aide',
    'it': 'Chiedere aiuto',
    'de': 'Um Hilfe bitten',
  },
);

const _LocalizedText _promptBestAnswer = _LocalizedText(
  id: 'prompt_best_answer',
  translations: <String, String>{
    'pt': 'Como responderias nesta situação?',
    'en': 'How would you answer in this situation?',
    'es': '¿Cómo responderías en esta situación?',
    'fr': 'Comment répondrais-tu dans cette situation?',
    'it': 'Come risponderesti in questa situazione?',
    'de': 'Wie würdest du in dieser Situation antworten?',
  },
);

const _LocalizedText _promptChoosePhrase = _LocalizedText(
  id: 'prompt_choose_phrase',
  translations: <String, String>{
    'pt': 'Escolhe a frase mais adequada.',
    'en': 'Choose the most appropriate sentence.',
    'es': 'Elige la frase más adecuada.',
    'fr': 'Choisis la phrase la plus adaptée.',
    'it': 'Scegli la frase più adatta.',
    'de': 'Wähle den passendsten Satz.',
  },
);

const List<_QuizQuestion> _quizBank = <_QuizQuestion>[
  _QuizQuestion(
    id: 'science_room',
    category: _categorySchool,
    scenario: _LocalizedText(
      id: 'scenario_science_room',
      translations: <String, String>{
        'pt':
            'Chegaste à escola e não sabes onde fica a sala de ciências. Queres perguntar a um colega.',
        'en':
            'You arrived at school and do not know where the science room is. You want to ask a classmate.',
        'es':
            'Has llegado a la escuela y no sabes dónde está la sala de ciencias. Quieres preguntarle a un compañero.',
        'fr':
            'Tu es arrivé à l’école et tu ne sais pas où se trouve la salle de sciences. Tu veux demander à un camarade.',
        'it':
            'Sei arrivato a scuola e non sai dov’è l’aula di scienze. Vuoi chiederlo a un compagno.',
        'de':
            'Du bist in der Schule angekommen und weißt nicht, wo der Naturwissenschaftsraum ist. Du möchtest einen Mitschüler fragen.',
      },
    ),
    prompt: _promptChoosePhrase,
    correctAnswer: _LocalizedText(
      id: 'answer_where_science_room',
      translations: <String, String>{
        'pt': 'Onde fica a sala de ciências?',
        'en': 'Where is the science room?',
        'es': '¿Dónde está la sala de ciencias?',
        'fr': 'Où est la salle de sciences?',
        'it': 'Dov’è l’aula di scienze?',
        'de': 'Wo ist der Naturwissenschaftsraum?',
      },
    ),
    distractors: <_LocalizedText>[
      _LocalizedText(
        id: 'answer_science_room_statement',
        translations: <String, String>{
          'pt': 'A sala de ciências é aqui.',
          'en': 'The science room is here.',
          'es': 'La sala de ciencias está aquí.',
          'fr': 'La salle de sciences est ici.',
          'it': 'L’aula di scienze è qui.',
          'de': 'Der Naturwissenschaftsraum ist hier.',
        },
      ),
      _LocalizedText(
        id: 'answer_i_like_science',
        translations: <String, String>{
          'pt': 'Gosto de ciências.',
          'en': 'I like science.',
          'es': 'Me gustan las ciencias.',
          'fr': 'J’aime les sciences.',
          'it': 'Mi piacciono le scienze.',
          'de': 'Ich mag Naturwissenschaften.',
        },
      ),
      _LocalizedText(
        id: 'answer_science_room_later',
        translations: <String, String>{
          'pt': 'A sala de ciências é mais tarde.',
          'en': 'The science room is later.',
          'es': 'La sala de ciencias es más tarde.',
          'fr': 'La salle de sciences est plus tard.',
          'it': 'L’aula di scienze è più tardi.',
          'de': 'Der Naturwissenschaftsraum ist später.',
        },
      ),
    ],
    icon: Icons.school_outlined,
    visualIcon: Icons.meeting_room_outlined,
  ),
  _QuizQuestion(
    id: 'repeat_please',
    category: _categorySchool,
    scenario: _LocalizedText(
      id: 'scenario_repeat_please',
      translations: <String, String>{
        'pt':
            'O professor explicou uma instrução rapidamente e tu não compreendeste tudo.',
        'en':
            'The teacher explained an instruction quickly and you did not understand everything.',
        'es':
            'El profesor explicó una instrucción rápidamente y no entendiste todo.',
        'fr':
            'Le professeur a expliqué une consigne rapidement et tu n’as pas tout compris.',
        'it':
            'L’insegnante ha spiegato un’istruzione velocemente e non hai capito tutto.',
        'de':
            'Der Lehrer hat eine Anweisung schnell erklärt und du hast nicht alles verstanden.',
      },
    ),
    prompt: _promptBestAnswer,
    correctAnswer: _LocalizedText(
      id: 'answer_can_repeat',
      translations: <String, String>{
        'pt': 'Pode repetir, por favor?',
        'en': 'Can you repeat, please?',
        'es': '¿Puede repetir, por favor?',
        'fr': 'Pouvez-vous répéter, s’il vous plaît?',
        'it': 'Può ripetere, per favore?',
        'de': 'Können Sie das bitte wiederholen?',
      },
    ),
    distractors: <_LocalizedText>[
      _LocalizedText(
        id: 'answer_good_morning',
        translations: <String, String>{
          'pt': 'Bom dia, professor.',
          'en': 'Good morning, teacher.',
          'es': 'Buenos días, profesor.',
          'fr': 'Bonjour, professeur.',
          'it': 'Buongiorno, professore.',
          'de': 'Guten Morgen, Lehrer.',
        },
      ),
      _LocalizedText(
        id: 'answer_i_am_tired',
        translations: <String, String>{
          'pt': 'Estou cansado.',
          'en': 'I am tired.',
          'es': 'Estoy cansado.',
          'fr': 'Je suis fatigué.',
          'it': 'Sono stanco.',
          'de': 'Ich bin müde.',
        },
      ),
      _LocalizedText(
        id: 'answer_where_breakfast',
        translations: <String, String>{
          'pt': 'Onde é o pequeno-almoço?',
          'en': 'Where is breakfast?',
          'es': '¿Dónde es el desayuno?',
          'fr': 'Où est le petit-déjeuner?',
          'it': 'Dov’è la colazione?',
          'de': 'Wo ist das Frühstück?',
        },
      ),
    ],
    icon: Icons.record_voice_over_outlined,
    visualIcon: Icons.hearing_outlined,
  ),
  _QuizQuestion(
    id: 'food_allergy',
    category: _categoryHostFamily,
    scenario: _LocalizedText(
      id: 'scenario_food_allergy',
      translations: <String, String>{
        'pt':
            'A família anfitriã pergunta se tens alguma alergia antes do jantar.',
        'en': 'The host family asks if you have any allergy before dinner.',
        'es':
            'La familia anfitriona pregunta si tienes alguna alergia antes de la cena.',
        'fr':
            'La famille d’accueil demande si tu as une allergie avant le dîner.',
        'it':
            'La famiglia ospitante chiede se hai qualche allergia prima della cena.',
        'de':
            'Die Gastfamilie fragt vor dem Abendessen, ob du eine Allergie hast.',
      },
    ),
    prompt: _promptBestAnswer,
    correctAnswer: _LocalizedText(
      id: 'answer_allergic_nuts',
      translations: <String, String>{
        'pt': 'Sou alérgico a frutos secos.',
        'en': 'I am allergic to nuts.',
        'es': 'Soy alérgico a los frutos secos.',
        'fr': 'Je suis allergique aux fruits à coque.',
        'it': 'Sono allergico alla frutta secca.',
        'de': 'Ich bin allergisch gegen Nüsse.',
      },
    ),
    distractors: <_LocalizedText>[
      _LocalizedText(
        id: 'answer_i_like_school',
        translations: <String, String>{
          'pt': 'Gosto da escola.',
          'en': 'I like school.',
          'es': 'Me gusta la escuela.',
          'fr': 'J’aime l’école.',
          'it': 'Mi piace la scuola.',
          'de': 'Ich mag die Schule.',
        },
      ),
      _LocalizedText(
        id: 'answer_where_bathroom',
        translations: <String, String>{
          'pt': 'Onde fica a casa de banho?',
          'en': 'Where is the bathroom?',
          'es': '¿Dónde está el baño?',
          'fr': 'Où sont les toilettes?',
          'it': 'Dov’è il bagno?',
          'de': 'Wo ist die Toilette?',
        },
      ),
      _LocalizedText(
        id: 'answer_thanks_help',
        translations: <String, String>{
          'pt': 'Obrigado pela ajuda.',
          'en': 'Thank you for your help.',
          'es': 'Gracias por la ayuda.',
          'fr': 'Merci pour votre aide.',
          'it': 'Grazie per l’aiuto.',
          'de': 'Danke für die Hilfe.',
        },
      ),
    ],
    icon: Icons.restaurant_outlined,
    visualIcon: Icons.dinner_dining_outlined,
  ),
  _QuizQuestion(
    id: 'breakfast_time',
    category: _categoryHostFamily,
    scenario: _LocalizedText(
      id: 'scenario_breakfast_time',
      translations: <String, String>{
        'pt':
            'É o primeiro dia em casa da família anfitriã e queres saber a hora do pequeno-almoço.',
        'en':
            'It is your first day at the host family’s home and you want to know breakfast time.',
        'es':
            'Es tu primer día en casa de la familia anfitriona y quieres saber la hora del desayuno.',
        'fr':
            'C’est ton premier jour chez la famille d’accueil et tu veux connaître l’heure du petit-déjeuner.',
        'it':
            'È il tuo primo giorno a casa della famiglia ospitante e vuoi sapere l’orario della colazione.',
        'de':
            'Es ist dein erster Tag bei der Gastfamilie und du möchtest wissen, wann es Frühstück gibt.',
      },
    ),
    prompt: _promptChoosePhrase,
    correctAnswer: _LocalizedText(
      id: 'answer_breakfast_time',
      translations: <String, String>{
        'pt': 'A que horas é o pequeno-almoço?',
        'en': 'What time is breakfast?',
        'es': '¿A qué hora es el desayuno?',
        'fr': 'À quelle heure est le petit-déjeuner?',
        'it': 'A che ora è la colazione?',
        'de': 'Um wie viel Uhr ist das Frühstück?',
      },
    ),
    distractors: <_LocalizedText>[
      _LocalizedText(
        id: 'answer_breakfast_good',
        translations: <String, String>{
          'pt': 'O pequeno-almoço é bom.',
          'en': 'Breakfast is good.',
          'es': 'El desayuno es bueno.',
          'fr': 'Le petit-déjeuner est bon.',
          'it': 'La colazione è buona.',
          'de': 'Das Frühstück ist gut.',
        },
      ),
      _LocalizedText(
        id: 'answer_i_am_breakfast',
        translations: <String, String>{
          'pt': 'Eu sou pequeno-almoço.',
          'en': 'I am breakfast.',
          'es': 'Soy desayuno.',
          'fr': 'Je suis petit-déjeuner.',
          'it': 'Sono colazione.',
          'de': 'Ich bin Frühstück.',
        },
      ),
      _LocalizedText(
        id: 'answer_school_time',
        translations: <String, String>{
          'pt': 'A escola é às horas.',
          'en': 'School is at the hours.',
          'es': 'La escuela es a las horas.',
          'fr': 'L’école est aux heures.',
          'it': 'La scuola è alle ore.',
          'de': 'Die Schule ist um die Uhr.',
        },
      ),
    ],
    icon: Icons.home_outlined,
    visualIcon: Icons.free_breakfast_outlined,
  ),
  _QuizQuestion(
    id: 'need_help',
    category: _categoryHelp,
    scenario: _LocalizedText(
      id: 'scenario_need_help',
      translations: <String, String>{
        'pt': 'Estás perdido no corredor da escola e precisas de ajuda.',
        'en': 'You are lost in the school corridor and need help.',
        'es': 'Estás perdido en el pasillo de la escuela y necesitas ayuda.',
        'fr': 'Tu es perdu dans le couloir de l’école et tu as besoin d’aide.',
        'it': 'Ti sei perso nel corridoio della scuola e hai bisogno di aiuto.',
        'de': 'Du hast dich im Schulflur verlaufen und brauchst Hilfe.',
      },
    ),
    prompt: _promptBestAnswer,
    correctAnswer: _LocalizedText(
      id: 'answer_need_help',
      translations: <String, String>{
        'pt': 'Preciso de ajuda, por favor.',
        'en': 'I need help, please.',
        'es': 'Necesito ayuda, por favor.',
        'fr': 'J’ai besoin d’aide, s’il vous plaît.',
        'it': 'Ho bisogno di aiuto, per favore.',
        'de': 'Ich brauche bitte Hilfe.',
      },
    ),
    distractors: <_LocalizedText>[
      _LocalizedText(
        id: 'answer_i_need_lunch',
        translations: <String, String>{
          'pt': 'Preciso de almoço.',
          'en': 'I need lunch.',
          'es': 'Necesito almuerzo.',
          'fr': 'J’ai besoin de déjeuner.',
          'it': 'Ho bisogno di pranzo.',
          'de': 'Ich brauche Mittagessen.',
        },
      ),
      _LocalizedText(
        id: 'answer_i_am_school',
        translations: <String, String>{
          'pt': 'Eu sou a escola.',
          'en': 'I am the school.',
          'es': 'Soy la escuela.',
          'fr': 'Je suis l’école.',
          'it': 'Sono la scuola.',
          'de': 'Ich bin die Schule.',
        },
      ),
      _LocalizedText(
        id: 'answer_you_are_help',
        translations: <String, String>{
          'pt': 'Tu és ajuda.',
          'en': 'You are help.',
          'es': 'Tú eres ayuda.',
          'fr': 'Tu es aide.',
          'it': 'Tu sei aiuto.',
          'de': 'Du bist Hilfe.',
        },
      ),
    ],
    icon: Icons.help_outline,
    visualIcon: Icons.support_agent_outlined,
  ),
  _QuizQuestion(
    id: 'thank_you',
    category: _categoryHelp,
    scenario: _LocalizedText(
      id: 'scenario_thank_you',
      translations: <String, String>{
        'pt': 'Um colega ajudou-te a encontrar a sala certa. Queres agradecer.',
        'en':
            'A classmate helped you find the right room. You want to say thank you.',
        'es':
            'Un compañero te ayudó a encontrar la sala correcta. Quieres agradecer.',
        'fr':
            'Un camarade t’a aidé à trouver la bonne salle. Tu veux le remercier.',
        'it':
            'Un compagno ti ha aiutato a trovare l’aula giusta. Vuoi ringraziare.',
        'de':
            'Ein Mitschüler hat dir geholfen, den richtigen Raum zu finden. Du möchtest dich bedanken.',
      },
    ),
    prompt: _promptChoosePhrase,
    correctAnswer: _LocalizedText(
      id: 'answer_thank_you_help',
      translations: <String, String>{
        'pt': 'Obrigado pela ajuda.',
        'en': 'Thank you for your help.',
        'es': 'Gracias por la ayuda.',
        'fr': 'Merci pour ton aide.',
        'it': 'Grazie per l’aiuto.',
        'de': 'Danke für deine Hilfe.',
      },
    ),
    distractors: <_LocalizedText>[
      _LocalizedText(
        id: 'answer_i_am_late',
        translations: <String, String>{
          'pt': 'Estou atrasado.',
          'en': 'I am late.',
          'es': 'Llego tarde.',
          'fr': 'Je suis en retard.',
          'it': 'Sono in ritardo.',
          'de': 'Ich bin spät dran.',
        },
      ),
      _LocalizedText(
        id: 'answer_where_room',
        translations: <String, String>{
          'pt': 'Onde fica a sala?',
          'en': 'Where is the room?',
          'es': '¿Dónde está la sala?',
          'fr': 'Où est la salle?',
          'it': 'Dov’è l’aula?',
          'de': 'Wo ist der Raum?',
        },
      ),
      _LocalizedText(
        id: 'answer_i_do_not_understand',
        translations: <String, String>{
          'pt': 'Não compreendo.',
          'en': 'I do not understand.',
          'es': 'No entiendo.',
          'fr': 'Je ne comprends pas.',
          'it': 'Non capisco.',
          'de': 'Ich verstehe nicht.',
        },
      ),
    ],
    icon: Icons.volunteer_activism_outlined,
    visualIcon: Icons.handshake_outlined,
  ),
];
