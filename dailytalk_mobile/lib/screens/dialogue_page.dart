import 'dart:math';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

import '../data/dao/app_settings_dao.dart';
import '../data/database/app_database.dart';
import '../data/repositories/auth_repository.dart';

/// Ecrã de diálogo contextualizado do DailyTalk.pt.
///
/// Regras de idioma:
/// - cenário, instruções, feedback e interface: idioma da aplicação/utilizador;
/// - falas do diálogo e respostas: idioma que o utilizador quer praticar.
class DialoguePage extends StatefulWidget {
  const DialoguePage({
    super.key,
    this.userLanguageCode = 'pt-PT',
    this.learningLanguageCode = 'it-IT',
  });

  /// Idioma da aplicação/utilizador.
  final String userLanguageCode;

  /// Idioma que o utilizador quer praticar.
  final String learningLanguageCode;

  @override
  State<DialoguePage> createState() => _DialoguePageState();
}

class _DialoguePageState extends State<DialoguePage> {
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
  late _DialogueScenario _scenario;
  late List<_DialogueReply> _currentReplies;

  final Map<int, _DialogueReply> _acceptedReplies = <int, _DialogueReply>{};

  bool _isLoadingLanguages = true;
  bool _isFinished = false;
  int _turnIndex = 0;
  int _score = 0;
  int _streak = 0;
  int _lives = 3;
  bool _hasAnswered = false;
  String? _selectedReplyId;

  _DialogueTurn get _currentTurn => _scenario.turns[_turnIndex];

  bool get _isLastTurn => _turnIndex == _scenario.turns.length - 1;

  bool get _selectedReplyIsCorrect {
    if (!_hasAnswered || _selectedReplyId == null) {
      return false;
    }

    return _currentReplies
        .firstWhere((reply) => reply.id == _selectedReplyId)
        .isCorrect;
  }

  @override
  void initState() {
    super.initState();

    // Valores técnicos de fallback. A atividade real é preparada depois
    // de carregar os idiomas guardados pelo ecrã Language/perfil.
    _userLanguageCode = _normaliseLanguageCode(widget.userLanguageCode);
    _learningLanguageCode = _normaliseLanguageCode(widget.learningLanguageCode);

    if (_userLanguageCode == _learningLanguageCode) {
      _learningLanguageCode = _fallbackLearningLanguage(_userLanguageCode);
    }

    Future<void>.microtask(_loadLanguagesFromSettings);
  }

  /// Lê os idiomas da mesma fonte usada pelo ecrã Language.
  Future<void> _loadLanguagesFromSettings() async {
    var nextUserLanguage = _userLanguageCode;
    var nextLearningLanguage = _learningLanguageCode;

    try {
      final db = await AppDatabase.instance.database;
      final settingsDao = AppSettingsDao(db);

      // 1) Cache local atualizada pelo ecrã Language.
      nextUserLanguage = await settingsDao.getNativeLanguageCode();
      nextLearningLanguage = await settingsDao.getTargetLanguageCode();

      try {
        // 2) Perfil remoto, quando a sessão/API estiver disponível.
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
      _prepareDialogue(resetScore: true);
      _isLoadingLanguages = false;
    });
  }

  /// Prepara uma nova ronda de diálogo.
  void _prepareDialogue({required bool resetScore}) {
    final scenarios = _dialogueBank.toList()..shuffle(Random());
    _scenario = scenarios.first;
    _turnIndex = 0;
    _selectedReplyId = null;
    _hasAnswered = false;
    _isFinished = false;
    _acceptedReplies.clear();
    _currentReplies = _buildRepliesFor(_scenario.turns.first);

    if (resetScore) {
      _score = 0;
      _streak = 0;
      _lives = 3;
    }
  }

  /// Constrói e baralha as respostas possíveis do turno atual.
  List<_DialogueReply> _buildRepliesFor(_DialogueTurn turn) {
    final replies = <_DialogueReply>[
      _DialogueReply(
        id: turn.correctReply.id,
        text: turn.correctReply.textFor(_translationKey(_learningLanguageCode)),
        isCorrect: true,
      ),
      ...turn.distractors.map(
        (reply) => _DialogueReply(
          id: reply.id,
          text: reply.textFor(_translationKey(_learningLanguageCode)),
          isCorrect: false,
        ),
      ),
    ]..shuffle(Random());

    return replies;
  }

  /// Seleciona uma resposta.
  void _selectReply(_DialogueReply reply) {
    if (_hasAnswered) {
      return;
    }

    setState(() {
      _selectedReplyId = reply.id;
    });
  }

  /// Confirma a resposta selecionada.
  void _confirmReply() {
    if (_selectedReplyId == null || _hasAnswered) {
      return;
    }

    final selectedReply = _currentReplies.firstWhere(
      (reply) => reply.id == _selectedReplyId,
    );

    setState(() {
      _hasAnswered = true;

      if (selectedReply.isCorrect) {
        _streak++;
        _score += 35 + (_streak * 10);
        _acceptedReplies[_turnIndex] = selectedReply;
      } else {
        _streak = 0;
        _lives = max(0, _lives - 1);
      }
    });
  }

  /// Avança, termina ou permite nova tentativa no mesmo turno.
  void _continueDialogue() {
    if (!_hasAnswered) {
      return;
    }

    if (!_selectedReplyIsCorrect) {
      setState(() {
        _selectedReplyId = null;
        _hasAnswered = false;
      });
      return;
    }

    if (_isLastTurn) {
      setState(() {
        _isFinished = true;
      });
      return;
    }

    setState(() {
      _turnIndex++;
      _selectedReplyId = null;
      _hasAnswered = false;
      _currentReplies = _buildRepliesFor(_currentTurn);
    });
  }

  /// Reinicia com um novo cenário de diálogo.
  void _restartDialogue() {
    setState(() {
      _prepareDialogue(resetScore: true);
    });
  }

  /// Placeholder para futura reprodução de áudio.
  void _playAudioPlaceholder() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: AppText(_ui('audioSoon'))),
    );
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
              colors: <Color>[
                Color(0xFF061823),
                Color(0xFF0D1B22),
              ],
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
                      _buildDialogueCard(),
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
                border: Border.all(
                  color: _accentColor.withValues(alpha: 0.35),
                ),
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
          child: const Icon(
            Icons.menu_book,
            color: Colors.amber,
            size: 32,
          ),
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

  /// Cartão temporário enquanto os idiomas são carregados.
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

  /// Cartão de progresso da atividade.
  Widget _buildProgressCard() {
    final progress = (_turnIndex + 1) / _scenario.turns.length;
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
                  '${_ui('turn')} ${_turnIndex + 1} ${_ui('of')} ${_scenario.turns.length}',
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

  /// Cartão principal do diálogo.
  Widget _buildDialogueCard() {
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
          _buildScenarioHeader(nativeKey),
          const SizedBox(height: 16),
          _buildScenarioDescription(nativeKey),
          const SizedBox(height: 16),
          _buildTranscript(),
          const SizedBox(height: 16),
          _buildPrompt(nativeKey),
          const SizedBox(height: 14),
          ...List.generate(_currentReplies.length, (index) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == _currentReplies.length - 1 ? 0 : 10,
              ),
              child: _buildReplyButton(_currentReplies[index], index),
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

  Widget _buildScenarioHeader(String nativeKey) {
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
          child: Icon(
            _scenario.icon,
            color: _accentColor,
            size: 26,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                _scenario.title.textFor(nativeKey),
                style: const TextStyle(
                  color: _accentColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              AppText(
                '${_ui('contextLabel')} · ${_languageName(_learningLanguageCode)}',
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

  Widget _buildScenarioDescription(String nativeKey) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: _softBoxDecoration(
        color: _accentColor.withValues(alpha: 0.08),
        borderColor: _accentColor.withValues(alpha: 0.20),
      ),
      child: AppText(
        _scenario.description.textFor(nativeKey),
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.82),
          fontSize: 15.5,
          fontWeight: FontWeight.w600,
          height: 1.36,
        ),
      ),
    );
  }

  /// Constrói a transcrição do diálogo até ao turno atual.
  Widget _buildTranscript() {
    final widgets = <Widget>[];
    final learningKey = _translationKey(_learningLanguageCode);

    for (var index = 0; index <= _turnIndex; index++) {
      final turn = _scenario.turns[index];
      final acceptedReply = _acceptedReplies[index];

      widgets.add(
        _buildBubble(
          speaker: _ui('partner'),
          text: turn.partnerMessage.textFor(learningKey),
          isUser: false,
        ),
      );

      if (acceptedReply != null) {
        widgets.add(
          _buildBubble(
            speaker: _ui('you'),
            text: acceptedReply.text,
            isUser: true,
            isCorrect: true,
          ),
        );
      } else if (index == _turnIndex && _hasAnswered && _selectedReplyId != null) {
        final selectedReply = _currentReplies.firstWhere(
          (reply) => reply.id == _selectedReplyId,
        );

        widgets.add(
          _buildBubble(
            speaker: _ui('you'),
            text: selectedReply.text,
            isUser: true,
            isCorrect: selectedReply.isCorrect,
            isWrong: !selectedReply.isCorrect,
          ),
        );
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: _softBoxDecoration(),
      child: Column(
        children: widgets,
      ),
    );
  }

  Widget _buildBubble({
    required String speaker,
    required String text,
    required bool isUser,
    bool isCorrect = false,
    bool isWrong = false,
  }) {
    final bubbleColor = isUser
        ? _primaryBlue.withValues(alpha: 0.18)
        : Colors.white.withValues(alpha: 0.07);

    final borderColor = isWrong
        ? _errorColor.withValues(alpha: 0.70)
        : isCorrect
            ? _successColor.withValues(alpha: 0.45)
            : _accentColor.withValues(alpha: isUser ? 0.34 : 0.14);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(13, 10, 13, 11),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 5),
            bottomRight: Radius.circular(isUser ? 5 : 18),
          ),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            AppText(
              speaker,
              style: TextStyle(
                color: isUser ? _accentColor : Colors.white.withValues(alpha: 0.58),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            AppText(
              text,
              textAlign: isUser ? TextAlign.right : TextAlign.left,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16.5,
                height: 1.28,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrompt(String nativeKey) {
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
          child: const Icon(
            Icons.chat_bubble_outline,
            color: _accentColor,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AppText(
            _currentTurn.prompt.textFor(nativeKey),
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

  Widget _buildReplyButton(_DialogueReply reply, int index) {
    final isSelected = _selectedReplyId == reply.id;
    final showCorrect = _hasAnswered && reply.isCorrect;
    final showWrong = _hasAnswered && isSelected && !reply.isCorrect;

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
        onTap: () => _selectReply(reply),
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
                  reply.text,
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
          _ui('chooseReply'),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.70),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final isCorrect = _selectedReplyIsCorrect;

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
    final canConfirm = _selectedReplyId != null && !_hasAnswered;
    final buttonText = !_hasAnswered
        ? _ui('confirm')
        : _selectedReplyIsCorrect
            ? _isLastTurn
                ? _ui('finish')
                : _ui('next')
            : _ui('tryAgain');

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: !_hasAnswered
            ? canConfirm
                ? _confirmReply
                : null
            : _continueDialogue,
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
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _buildFinishedCard() {
    final total = _scenario.turns.length;
    final maxScore = total * 85;
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
              Icons.forum_outlined,
              color: _accentColor,
              size: 42,
            ),
          ),
          const SizedBox(height: 16),
          AppText(
            _ui('dialogueCompleted'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          AppText(
            _ui('dialogueCompletedDescription'),
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
              onPressed: _restartDialogue,
              icon: const Icon(Icons.refresh),
              label: AppText(_ui('newDialogue')),
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

  BoxDecoration _softBoxDecoration({
    Color? color,
    Color? borderColor,
  }) {
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

  String _languageName(String code) {
    return _languageNames[code] ?? code;
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

class _DialogueScenario {
  const _DialogueScenario({
    required this.id,
    required this.title,
    required this.description,
    required this.turns,
    required this.icon,
  });

  final String id;
  final _LocalizedText title;
  final _LocalizedText description;
  final List<_DialogueTurn> turns;
  final IconData icon;
}

class _DialogueTurn {
  const _DialogueTurn({
    required this.id,
    required this.partnerMessage,
    required this.prompt,
    required this.correctReply,
    required this.distractors,
  });

  final String id;
  final _LocalizedText partnerMessage;
  final _LocalizedText prompt;
  final _LocalizedText correctReply;
  final List<_LocalizedText> distractors;
}

class _DialogueReply {
  const _DialogueReply({
    required this.id,
    required this.text,
    required this.isCorrect,
  });

  final String id;
  final String text;
  final bool isCorrect;
}

class _LocalizedText {
  const _LocalizedText({
    required this.id,
    required this.translations,
  });

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

const Map<String, String> _languageNames = <String, String>{
  'pt-PT': 'Português',
  'en-US': 'English',
  'es-ES': 'Español',
  'fr-FR': 'Français',
  'it-IT': 'Italiano',
  'de-DE': 'Deutsch',
};

const Map<String, Map<String, String>> _uiTexts = <String, Map<String, String>>{
  'pt': <String, String>{
    'turn': 'Turno',
    'of': 'de',
    'contextLabel': 'Diálogo guiado · Erasmus+',
    'listen': 'Ouvir',
    'audioSoon': 'O áudio deste diálogo será integrado numa próxima versão.',
    'loadingLanguages': 'A carregar os idiomas definidos no perfil...',
    'chooseReply': 'Escolhe a melhor resposta no idioma que estás a praticar.',
    'correct': 'Correto. A resposta é natural e mantém a conversa a avançar.',
    'wrong': 'Ainda não é a melhor resposta. Observa a opção correta e tenta novamente.',
    'partner': 'Interlocutor',
    'you': 'Tu',
    'points': 'Pontos',
    'streak': 'Sequência',
    'lives': 'Vidas',
    'confirm': 'Confirmar',
    'tryAgain': 'Tentar novamente',
    'next': 'Seguinte',
    'finish': 'Terminar',
    'dialogueCompleted': 'Diálogo concluído',
    'dialogueCompletedDescription':
        'Boa prática. Treinaste respostas úteis para uma conversa real em contexto escolar.',
    'performance': 'Desempenho',
    'newDialogue': 'Novo diálogo',
  },
  'en': <String, String>{
    'turn': 'Turn',
    'of': 'of',
    'contextLabel': 'Guided dialogue · Erasmus+',
    'listen': 'Listen',
    'audioSoon': 'Audio for this dialogue will be integrated in a future version.',
    'loadingLanguages': 'Loading the languages defined in your profile...',
    'chooseReply': 'Choose the best reply in the language you are practising.',
    'correct': 'Correct. The reply is natural and keeps the conversation going.',
    'wrong': 'That is not the best reply yet. Check the correct option and try again.',
    'partner': 'Partner',
    'you': 'You',
    'points': 'Points',
    'streak': 'Streak',
    'lives': 'Lives',
    'confirm': 'Confirm',
    'tryAgain': 'Try again',
    'next': 'Next',
    'finish': 'Finish',
    'dialogueCompleted': 'Dialogue completed',
    'dialogueCompletedDescription':
        'Good practice. You trained useful replies for a real school conversation.',
    'performance': 'Performance',
    'newDialogue': 'New dialogue',
  },
  'es': <String, String>{
    'turn': 'Turno',
    'of': 'de',
    'contextLabel': 'Diálogo guiado · Erasmus+',
    'listen': 'Escuchar',
    'audioSoon': 'El audio de este diálogo se integrará en una próxima versión.',
    'loadingLanguages': 'Cargando los idiomas definidos en tu perfil...',
    'chooseReply': 'Elige la mejor respuesta en el idioma que estás practicando.',
    'correct': 'Correcto. La respuesta es natural y mantiene la conversación.',
    'wrong': 'Todavía no es la mejor respuesta. Observa la opción correcta e inténtalo de nuevo.',
    'partner': 'Interlocutor',
    'you': 'Tú',
    'points': 'Puntos',
    'streak': 'Racha',
    'lives': 'Vidas',
    'confirm': 'Confirmar',
    'tryAgain': 'Intentar de nuevo',
    'next': 'Siguiente',
    'finish': 'Terminar',
    'dialogueCompleted': 'Diálogo completado',
    'dialogueCompletedDescription':
        'Buena práctica. Entrenaste respuestas útiles para una conversación escolar real.',
    'performance': 'Rendimiento',
    'newDialogue': 'Nuevo diálogo',
  },
  'fr': <String, String>{
    'turn': 'Tour',
    'of': 'sur',
    'contextLabel': 'Dialogue guidé · Erasmus+',
    'listen': 'Écouter',
    'audioSoon': 'L’audio de ce dialogue sera intégré dans une prochaine version.',
    'loadingLanguages': 'Chargement des langues définies dans ton profil...',
    'chooseReply': 'Choisis la meilleure réponse dans la langue que tu pratiques.',
    'correct': 'Correct. La réponse est naturelle et fait avancer la conversation.',
    'wrong': 'Ce n’est pas encore la meilleure réponse. Observe la bonne option et réessaie.',
    'partner': 'Interlocuteur',
    'you': 'Toi',
    'points': 'Points',
    'streak': 'Série',
    'lives': 'Vies',
    'confirm': 'Confirmer',
    'tryAgain': 'Réessayer',
    'next': 'Suivant',
    'finish': 'Terminer',
    'dialogueCompleted': 'Dialogue terminé',
    'dialogueCompletedDescription':
        'Bonne pratique. Tu as entraîné des réponses utiles pour une vraie conversation scolaire.',
    'performance': 'Performance',
    'newDialogue': 'Nouveau dialogue',
  },
  'it': <String, String>{
    'turn': 'Turno',
    'of': 'di',
    'contextLabel': 'Dialogo guidato · Erasmus+',
    'listen': 'Ascolta',
    'audioSoon': 'L’audio di questo dialogo sarà integrato in una prossima versione.',
    'loadingLanguages': 'Caricamento delle lingue definite nel profilo...',
    'chooseReply': 'Scegli la risposta migliore nella lingua che stai praticando.',
    'correct': 'Corretto. La risposta è naturale e fa andare avanti la conversazione.',
    'wrong': 'Non è ancora la risposta migliore. Guarda l’opzione corretta e riprova.',
    'partner': 'Interlocutore',
    'you': 'Tu',
    'points': 'Punti',
    'streak': 'Serie',
    'lives': 'Vite',
    'confirm': 'Conferma',
    'tryAgain': 'Riprova',
    'next': 'Avanti',
    'finish': 'Termina',
    'dialogueCompleted': 'Dialogo completato',
    'dialogueCompletedDescription':
        'Buona pratica. Hai allenato risposte utili per una conversazione scolastica reale.',
    'performance': 'Prestazione',
    'newDialogue': 'Nuovo dialogo',
  },
  'de': <String, String>{
    'turn': 'Runde',
    'of': 'von',
    'contextLabel': 'Geführter Dialog · Erasmus+',
    'listen': 'Anhören',
    'audioSoon': 'Audio für diesen Dialog wird in einer nächsten Version integriert.',
    'loadingLanguages': 'Die im Profil festgelegten Sprachen werden geladen...',
    'chooseReply': 'Wähle die beste Antwort in der Sprache, die du übst.',
    'correct': 'Richtig. Die Antwort ist natürlich und führt das Gespräch weiter.',
    'wrong': 'Das ist noch nicht die beste Antwort. Sieh dir die richtige Option an und versuche es erneut.',
    'partner': 'Gesprächspartner',
    'you': 'Du',
    'points': 'Punkte',
    'streak': 'Serie',
    'lives': 'Leben',
    'confirm': 'Bestätigen',
    'tryAgain': 'Erneut versuchen',
    'next': 'Weiter',
    'finish': 'Beenden',
    'dialogueCompleted': 'Dialog abgeschlossen',
    'dialogueCompletedDescription':
        'Gute Übung. Du hast nützliche Antworten für ein echtes Schulgespräch trainiert.',
    'performance': 'Leistung',
    'newDialogue': 'Neuer Dialog',
  },
};

const List<_DialogueScenario> _dialogueBank = <_DialogueScenario>[
  _DialogueScenario(
    id: 'host_family_first_morning',
    title: _LocalizedText(
      id: 'title_host_family_first_morning',
      translations: <String, String>{
        'pt': 'Primeiro dia em casa',
        'en': 'First day at home',
        'es': 'Primer día en casa',
        'fr': 'Premier jour à la maison',
        'it': 'Primo giorno in casa',
        'de': 'Erster Tag zu Hause',
      },
    ),
    description: _LocalizedText(
      id: 'description_host_family_first_morning',
      translations: <String, String>{
        'pt': 'Estás com a família anfitriã. Treina uma conversa curta para te apresentares, combinar o pequeno-almoço e pedir ajuda para chegar à escola.',
        'en': 'You are with the host family. Practise a short conversation to introduce yourself, agree on breakfast and ask for help getting to school.',
        'es': 'Estás con la familia anfitriona. Practica una conversación corta para presentarte, acordar el desayuno y pedir ayuda para llegar a la escuela.',
        'fr': 'Tu es avec la famille d’accueil. Entraîne une courte conversation pour te présenter, organiser le petit-déjeuner et demander de l’aide pour aller à l’école.',
        'it': 'Sei con la famiglia ospitante. Esercitati con una breve conversazione per presentarti, concordare la colazione e chiedere aiuto per andare a scuola.',
        'de': 'Du bist bei der Gastfamilie. Übe ein kurzes Gespräch, um dich vorzustellen, das Frühstück abzusprechen und nach Hilfe für den Weg zur Schule zu fragen.',
      },
    ),
    icon: Icons.home_outlined,
    turns: <_DialogueTurn>[
      _DialogueTurn(
        id: 'introduce_yourself',
        partnerMessage: _LocalizedText(
          id: 'partner_welcome_name',
          translations: <String, String>{
            'pt': 'Bem-vindo! Como te chamas?',
            'en': 'Welcome! What is your name?',
            'es': '¡Bienvenido! ¿Cómo te llamas?',
            'fr': 'Bienvenue! Comment tu t’appelles?',
            'it': 'Benvenuto! Come ti chiami?',
            'de': 'Willkommen! Wie heißt du?',
          },
        ),
        prompt: _LocalizedText(
          id: 'prompt_introduce_yourself',
          translations: <String, String>{
            'pt': 'O anfitrião deu-te as boas-vindas e perguntou o teu nome. Escolhe uma resposta natural.',
            'en': 'The host welcomed you and asked your name. Choose a natural reply.',
            'es': 'El anfitrión te dio la bienvenida y preguntó tu nombre. Elige una respuesta natural.',
            'fr': 'L’hôte t’a souhaité la bienvenue et a demandé ton nom. Choisis une réponse naturelle.',
            'it': 'L’ospite ti ha dato il benvenuto e ti ha chiesto il nome. Scegli una risposta naturale.',
            'de': 'Der Gastgeber hat dich begrüßt und nach deinem Namen gefragt. Wähle eine natürliche Antwort.',
          },
        ),
        correctReply: _LocalizedText(
          id: 'reply_my_name_is',
          translations: <String, String>{
            'pt': 'Chamo-me Paulo. Muito obrigado.',
            'en': 'My name is Paulo. Thank you very much.',
            'es': 'Me llamo Paulo. Muchas gracias.',
            'fr': 'Je m’appelle Paulo. Merci beaucoup.',
            'it': 'Mi chiamo Paulo. Grazie mille.',
            'de': 'Ich heiße Paulo. Vielen Dank.',
          },
        ),
        distractors: <_LocalizedText>[
          _LocalizedText(
            id: 'reply_where_bathroom',
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
            id: 'reply_i_am_hungry',
            translations: <String, String>{
              'pt': 'Tenho fome.',
              'en': 'I am hungry.',
              'es': 'Tengo hambre.',
              'fr': 'J’ai faim.',
              'it': 'Ho fame.',
              'de': 'Ich habe Hunger.',
            },
          ),
          _LocalizedText(
            id: 'reply_school_is_later',
            translations: <String, String>{
              'pt': 'A escola é mais tarde.',
              'en': 'School is later.',
              'es': 'La escuela es más tarde.',
              'fr': 'L’école est plus tard.',
              'it': 'La scuola è più tardi.',
              'de': 'Die Schule ist später.',
            },
          ),
        ],
      ),
      _DialogueTurn(
        id: 'breakfast_time',
        partnerMessage: _LocalizedText(
          id: 'partner_breakfast_eight',
          translations: <String, String>{
            'pt': 'Queres tomar pequeno-almoço às oito?',
            'en': 'Do you want to have breakfast at eight?',
            'es': '¿Quieres desayunar a las ocho?',
            'fr': 'Tu veux prendre le petit-déjeuner à huit heures?',
            'it': 'Vuoi fare colazione alle otto?',
            'de': 'Möchtest du um acht Uhr frühstücken?',
          },
        ),
        prompt: _LocalizedText(
          id: 'prompt_breakfast_time',
          translations: <String, String>{
            'pt': 'A família anfitriã perguntou se o horário do pequeno-almoço está bem para ti.',
            'en': 'The host family asked if the breakfast time is fine for you.',
            'es': 'La familia anfitriona preguntó si la hora del desayuno te parece bien.',
            'fr': 'La famille d’accueil demande si l’heure du petit-déjeuner te convient.',
            'it': 'La famiglia ospitante chiede se l’orario della colazione va bene per te.',
            'de': 'Die Gastfamilie fragt, ob die Frühstückszeit für dich passt.',
          },
        ),
        correctReply: _LocalizedText(
          id: 'reply_breakfast_ok',
          translations: <String, String>{
            'pt': 'Sim, está bem. Obrigado.',
            'en': 'Yes, that is fine. Thank you.',
            'es': 'Sí, está bien. Gracias.',
            'fr': 'Oui, ça me va. Merci.',
            'it': 'Sì, va bene. Grazie.',
            'de': 'Ja, das passt. Danke.',
          },
        ),
        distractors: <_LocalizedText>[
          _LocalizedText(
            id: 'reply_my_name_again',
            translations: <String, String>{
              'pt': 'Chamo-me Paulo.',
              'en': 'My name is Paulo.',
              'es': 'Me llamo Paulo.',
              'fr': 'Je m’appelle Paulo.',
              'it': 'Mi chiamo Paulo.',
              'de': 'Ich heiße Paulo.',
            },
          ),
          _LocalizedText(
            id: 'reply_where_science',
            translations: <String, String>{
              'pt': 'Onde fica a sala de ciências?',
              'en': 'Where is the science room?',
              'es': '¿Dónde está la sala de ciencias?',
              'fr': 'Où est la salle de sciences?',
              'it': 'Dov’è l’aula di scienze?',
              'de': 'Wo ist der Naturwissenschaftsraum?',
            },
          ),
          _LocalizedText(
            id: 'reply_i_do_not_school',
            translations: <String, String>{
              'pt': 'Não sou a escola.',
              'en': 'I am not the school.',
              'es': 'No soy la escuela.',
              'fr': 'Je ne suis pas l’école.',
              'it': 'Non sono la scuola.',
              'de': 'Ich bin nicht die Schule.',
            },
          ),
        ],
      ),
      _DialogueTurn(
        id: 'ask_help_school',
        partnerMessage: _LocalizedText(
          id: 'partner_help_school',
          translations: <String, String>{
            'pt': 'Precisas de ajuda para ir para a escola?',
            'en': 'Do you need help getting to school?',
            'es': '¿Necesitas ayuda para ir a la escuela?',
            'fr': 'Tu as besoin d’aide pour aller à l’école?',
            'it': 'Hai bisogno di aiuto per andare a scuola?',
            'de': 'Brauchst du Hilfe, um zur Schule zu kommen?',
          },
        ),
        prompt: _LocalizedText(
          id: 'prompt_ask_help_school',
          translations: <String, String>{
            'pt': 'Queres aceitar ajuda de forma educada.',
            'en': 'You want to accept help politely.',
            'es': 'Quieres aceptar ayuda de forma educada.',
            'fr': 'Tu veux accepter l’aide poliment.',
            'it': 'Vuoi accettare l’aiuto in modo educato.',
            'de': 'Du möchtest höflich Hilfe annehmen.',
          },
        ),
        correctReply: _LocalizedText(
          id: 'reply_yes_help_please',
          translations: <String, String>{
            'pt': 'Sim, podes ajudar-me, por favor?',
            'en': 'Yes, can you help me, please?',
            'es': 'Sí, ¿puedes ayudarme, por favor?',
            'fr': 'Oui, tu peux m’aider, s’il te plaît?',
            'it': 'Sì, puoi aiutarmi, per favore?',
            'de': 'Ja, kannst du mir bitte helfen?',
          },
        ),
        distractors: <_LocalizedText>[
          _LocalizedText(
            id: 'reply_no_thank_random',
            translations: <String, String>{
              'pt': 'Não, obrigado pelo almoço.',
              'en': 'No, thank you for lunch.',
              'es': 'No, gracias por el almuerzo.',
              'fr': 'Non, merci pour le déjeuner.',
              'it': 'No, grazie per il pranzo.',
              'de': 'Nein, danke für das Mittagessen.',
            },
          ),
          _LocalizedText(
            id: 'reply_i_am_teacher',
            translations: <String, String>{
              'pt': 'Sou professor.',
              'en': 'I am a teacher.',
              'es': 'Soy profesor.',
              'fr': 'Je suis professeur.',
              'it': 'Sono un insegnante.',
              'de': 'Ich bin Lehrer.',
            },
          ),
          _LocalizedText(
            id: 'reply_good_night',
            translations: <String, String>{
              'pt': 'Boa noite.',
              'en': 'Good night.',
              'es': 'Buenas noches.',
              'fr': 'Bonne nuit.',
              'it': 'Buona notte.',
              'de': 'Gute Nacht.',
            },
          ),
        ],
      ),
    ],
  ),
  _DialogueScenario(
    id: 'school_first_break',
    title: _LocalizedText(
      id: 'title_school_first_break',
      translations: <String, String>{
        'pt': 'Primeiro intervalo na escola',
        'en': 'First school break',
        'es': 'Primer recreo en la escuela',
        'fr': 'Première pause à l’école',
        'it': 'Prima pausa a scuola',
        'de': 'Erste Pause in der Schule',
      },
    ),
    description: _LocalizedText(
      id: 'description_school_first_break',
      translations: <String, String>{
        'pt': 'Estás no intervalo e falas com um colega. Treina como pedir orientação, pedir para repetir e agradecer.',
        'en': 'You are on a break and talk to a classmate. Practise asking for directions, asking to repeat and saying thank you.',
        'es': 'Estás en el recreo y hablas con un compañero. Practica pedir indicaciones, pedir que repitan y agradecer.',
        'fr': 'Tu es en pause et tu parles avec un camarade. Entraîne-toi à demander une direction, à demander de répéter et à remercier.',
        'it': 'Sei durante la pausa e parli con un compagno. Esercitati a chiedere indicazioni, chiedere di ripetere e ringraziare.',
        'de': 'Du bist in der Pause und sprichst mit einem Mitschüler. Übe, nach dem Weg zu fragen, um Wiederholung zu bitten und dich zu bedanken.',
      },
    ),
    icon: Icons.school_outlined,
    turns: <_DialogueTurn>[
      _DialogueTurn(
        id: 'ask_room',
        partnerMessage: _LocalizedText(
          id: 'partner_need_anything',
          translations: <String, String>{
            'pt': 'Precisas de alguma coisa?',
            'en': 'Do you need anything?',
            'es': '¿Necesitas algo?',
            'fr': 'Tu as besoin de quelque chose?',
            'it': 'Hai bisogno di qualcosa?',
            'de': 'Brauchst du etwas?',
          },
        ),
        prompt: _LocalizedText(
          id: 'prompt_ask_room',
          translations: <String, String>{
            'pt': 'Queres perguntar onde fica a sala de ciências.',
            'en': 'You want to ask where the science room is.',
            'es': 'Quieres preguntar dónde está la sala de ciencias.',
            'fr': 'Tu veux demander où se trouve la salle de sciences.',
            'it': 'Vuoi chiedere dov’è l’aula di scienze.',
            'de': 'Du möchtest fragen, wo der Naturwissenschaftsraum ist.',
          },
        ),
        correctReply: _LocalizedText(
          id: 'reply_where_science_room',
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
            id: 'reply_i_like_science',
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
            id: 'reply_breakfast_time',
            translations: <String, String>{
              'pt': 'A que horas é o pequeno-almoço?',
              'en': 'What time is breakfast?',
              'es': '¿A qué hora es el desayuno?',
              'fr': 'À quelle heure est le petit-déjeuner?',
              'it': 'A che ora è la colazione?',
              'de': 'Um wie viel Uhr ist das Frühstück?',
            },
          ),
          _LocalizedText(
            id: 'reply_i_am_tired',
            translations: <String, String>{
              'pt': 'Estou cansado.',
              'en': 'I am tired.',
              'es': 'Estoy cansado.',
              'fr': 'Je suis fatigué.',
              'it': 'Sono stanco.',
              'de': 'Ich bin müde.',
            },
          ),
        ],
      ),
      _DialogueTurn(
        id: 'repeat_directions',
        partnerMessage: _LocalizedText(
          id: 'partner_directions_fast',
          translations: <String, String>{
            'pt': 'É no segundo piso, depois da biblioteca, à direita.',
            'en': 'It is on the second floor, after the library, on the right.',
            'es': 'Está en el segundo piso, después de la biblioteca, a la derecha.',
            'fr': 'C’est au deuxième étage, après la bibliothèque, à droite.',
            'it': 'È al secondo piano, dopo la biblioteca, a destra.',
            'de': 'Er ist im zweiten Stock, nach der Bibliothek, rechts.',
          },
        ),
        prompt: _LocalizedText(
          id: 'prompt_repeat_directions',
          translations: <String, String>{
            'pt': 'Não compreendeste tudo. Pede para repetir de forma educada.',
            'en': 'You did not understand everything. Ask politely to repeat.',
            'es': 'No entendiste todo. Pide que repitan de forma educada.',
            'fr': 'Tu n’as pas tout compris. Demande poliment de répéter.',
            'it': 'Non hai capito tutto. Chiedi gentilmente di ripetere.',
            'de': 'Du hast nicht alles verstanden. Bitte höflich um Wiederholung.',
          },
        ),
        correctReply: _LocalizedText(
          id: 'reply_repeat_please',
          translations: <String, String>{
            'pt': 'Podes repetir, por favor?',
            'en': 'Can you repeat, please?',
            'es': '¿Puedes repetir, por favor?',
            'fr': 'Tu peux répéter, s’il te plaît?',
            'it': 'Puoi ripetere, per favore?',
            'de': 'Kannst du das bitte wiederholen?',
          },
        ),
        distractors: <_LocalizedText>[
          _LocalizedText(
            id: 'reply_thank_you_short',
            translations: <String, String>{
              'pt': 'Obrigado.',
              'en': 'Thank you.',
              'es': 'Gracias.',
              'fr': 'Merci.',
              'it': 'Grazie.',
              'de': 'Danke.',
            },
          ),
          _LocalizedText(
            id: 'reply_i_am_lost',
            translations: <String, String>{
              'pt': 'Estou perdido.',
              'en': 'I am lost.',
              'es': 'Estoy perdido.',
              'fr': 'Je suis perdu.',
              'it': 'Mi sono perso.',
              'de': 'Ich habe mich verlaufen.',
            },
          ),
          _LocalizedText(
            id: 'reply_good_morning',
            translations: <String, String>{
              'pt': 'Bom dia.',
              'en': 'Good morning.',
              'es': 'Buenos días.',
              'fr': 'Bonjour.',
              'it': 'Buongiorno.',
              'de': 'Guten Morgen.',
            },
          ),
        ],
      ),
      _DialogueTurn(
        id: 'thank_classmate',
        partnerMessage: _LocalizedText(
          id: 'partner_directions_repeated',
          translations: <String, String>{
            'pt': 'Claro. Sobe as escadas e vira à direita.',
            'en': 'Sure. Go up the stairs and turn right.',
            'es': 'Claro. Sube las escaleras y gira a la derecha.',
            'fr': 'Bien sûr. Monte les escaliers et tourne à droite.',
            'it': 'Certo. Sali le scale e gira a destra.',
            'de': 'Klar. Geh die Treppe hoch und dann rechts.',
          },
        ),
        prompt: _LocalizedText(
          id: 'prompt_thank_classmate',
          translations: <String, String>{
            'pt': 'Agora queres agradecer ao colega pela ajuda.',
            'en': 'Now you want to thank the classmate for the help.',
            'es': 'Ahora quieres agradecer al compañero por la ayuda.',
            'fr': 'Maintenant tu veux remercier le camarade pour son aide.',
            'it': 'Ora vuoi ringraziare il compagno per l’aiuto.',
            'de': 'Jetzt möchtest du dich bei dem Mitschüler für die Hilfe bedanken.',
          },
        ),
        correctReply: _LocalizedText(
          id: 'reply_thank_for_help',
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
            id: 'reply_where_again',
            translations: <String, String>{
              'pt': 'Onde fica a escola?',
              'en': 'Where is the school?',
              'es': '¿Dónde está la escuela?',
              'fr': 'Où est l’école?',
              'it': 'Dov’è la scuola?',
              'de': 'Wo ist die Schule?',
            },
          ),
          _LocalizedText(
            id: 'reply_no_understand',
            translations: <String, String>{
              'pt': 'Não compreendo.',
              'en': 'I do not understand.',
              'es': 'No entiendo.',
              'fr': 'Je ne comprends pas.',
              'it': 'Non capisco.',
              'de': 'Ich verstehe nicht.',
            },
          ),
          _LocalizedText(
            id: 'reply_i_need_breakfast',
            translations: <String, String>{
              'pt': 'Preciso de pequeno-almoço.',
              'en': 'I need breakfast.',
              'es': 'Necesito desayuno.',
              'fr': 'J’ai besoin du petit-déjeuner.',
              'it': 'Ho bisogno della colazione.',
              'de': 'Ich brauche Frühstück.',
            },
          ),
        ],
      ),
    ],
  ),
];
