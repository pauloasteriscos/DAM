import 'dart:math';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

import '../data/dao/app_settings_dao.dart';
import '../data/database/app_database.dart';
import '../data/repositories/auth_repository.dart';

/// Tela de revisão do DailyTalk.pt.
///
/// Regras de idioma:
/// - interface, instruções e feedback: idioma da aplicação/utilizador;
/// - cartão principal: idioma que o utilizador quer praticar;
/// - significado/apoio: idioma da aplicação/utilizador.
class RevisionPage extends StatefulWidget {
  const RevisionPage({
    super.key,
    this.userLanguageCode = 'pt-PT',
    this.learningLanguageCode = 'it-IT',
  });

  final String userLanguageCode;
  final String learningLanguageCode;

  @override
  State<RevisionPage> createState() => _RevisionPageState();
}

class _RevisionPageState extends State<RevisionPage> {
  static const Color _backgroundColor = Color(0xFF0D1B22);
  static const Color _cardColor = Color(0xFF071D2A);
  static const Color _panelColor = Color(0xFF10232D);
  static const Color _accentColor = Color(0xFF35C8FF);
  static const Color _primaryBlue = Color(0xFF168CFF);
  static const Color _successColor = Color(0xFF45E08F);
  static const Color _warningColor = Color(0xFFFFC857);

  late String _userLanguageCode;
  late String _learningLanguageCode;
  late List<_ReviewCardItem> _cards;

  bool _isLoading = true;
  bool _isRevealed = false;
  int _currentIndex = 0;
  int _knownCount = 0;
  int _reviewCount = 0;
  int _streak = 0;

  bool get _isFinished => _currentIndex >= _cards.length;
  _ReviewCardItem get _currentCard => _cards[_currentIndex];

  @override
  void initState() {
    super.initState();
    _userLanguageCode = _normaliseLanguageCode(widget.userLanguageCode);
    _learningLanguageCode = _normaliseLanguageCode(widget.learningLanguageCode);

    if (_userLanguageCode == _learningLanguageCode) {
      _learningLanguageCode = _fallbackLearningLanguage(_userLanguageCode);
    }

    Future<void>.microtask(_loadLanguagesFromSettings);
  }

  /// Lê os idiomas definidos no perfil/cache local, tal como nas outras telas.
  Future<void> _loadLanguagesFromSettings() async {
    var nextUserLanguage = _userLanguageCode;
    var nextLearningLanguage = _learningLanguageCode;

    try {
      final db = await AppDatabase.instance.database;
      final settingsDao = AppSettingsDao(db);

      nextUserLanguage = await settingsDao.getNativeLanguageCode();
      nextLearningLanguage = await settingsDao.getTargetLanguageCode();

      try {
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
        // Mantém a cache local quando a sessão/API não estiver disponível.
      }
    } catch (_) {
      // Usa os valores padrão se a base local ainda não estiver pronta.
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
      _startReview(resetProgress: true);
      _isLoading = false;
    });
  }

  /// Cria uma ronda curta com cartões contextualizados para o DailyTalk.pt.
  void _startReview({required bool resetProgress}) {
    _cards = _reviewBank.toList()..shuffle(Random());
    _cards = _cards.take(8).toList();
    _currentIndex = 0;
    _isRevealed = false;

    if (resetProgress) {
      _knownCount = 0;
      _reviewCount = 0;
      _streak = 0;
    }
  }

  void _showMeaning() {
    setState(() {
      _isRevealed = true;
    });
  }

  void _markKnown() {
    setState(() {
      _knownCount++;
      _streak++;
      _nextCard();
    });
  }

  void _markForReview() {
    setState(() {
      _reviewCount++;
      _streak = 0;
      _nextCard();
    });
  }

  void _nextCard() {
    _currentIndex++;
    _isRevealed = false;
  }

  void _restart() {
    setState(() {
      _startReview(resetProgress: true);
    });
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
                Color(0xFF0D1B22),
                Color(0xFF07141B),
              ],
            ),
          ),
          child: Column(
            children: <Widget>[
              _buildHeader(),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: _accentColor,
                        ),
                      )
                    : Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                            child: _isFinished
                                ? _buildFinishedState()
                                : _buildReviewContent(),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: _ui('back'),
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.white,
              size: 20,
            ),
          ),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF06345C),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _accentColor.withValues(alpha: 0.40),
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: _accentColor.withValues(alpha: 0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.menu_book,
              color: Colors.amber,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: AppText(
              'DailyTalk.pt',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewContent() {
    return Column(
      children: <Widget>[
        _buildProgressPanel(),
        const SizedBox(height: 14),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                _buildCard(),
                const SizedBox(height: 14),
                _buildActions(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressPanel() {
    final double progress = (_currentIndex + 1) / _cards.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _panelColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _accentColor.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: AppText(
                  '${_ui('review')} ${_currentIndex + 1}/${_cards.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _buildLanguageBadge(),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: const Color(0xFF0D4D7A),
              valueColor: const AlwaysStoppedAnimation<Color>(_accentColor),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              _buildMetric(Icons.check_circle_outline, _ui('known'), '$_knownCount', _successColor),
              const SizedBox(width: 8),
              _buildMetric(Icons.refresh, _ui('toReview'), '$_reviewCount', _warningColor),
              const SizedBox(width: 8),
              _buildMetric(Icons.local_fire_department, _ui('streak'), '$_streak', Colors.orangeAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _primaryBlue.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: _accentColor.withValues(alpha: 0.32),
        ),
      ),
      child: AppText(
        '${_languageName(_userLanguageCode)} → ${_languageName(_learningLanguageCode)}',
        style: const TextStyle(
          color: _accentColor,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildMetric(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: AppText(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            AppText(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard() {
    final card = _currentCard;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 330),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: _isRevealed
              ? _successColor.withValues(alpha: 0.55)
              : _accentColor.withValues(alpha: 0.38),
          width: 1.4,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: _accentColor.withValues(alpha: 0.10),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _primaryBlue.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _accentColor.withValues(alpha: 0.30)),
                ),
                child: const Icon(
                  Icons.style,
                  color: _accentColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    AppText(
                      _ui('cardTitle'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    AppText(
                      card.categoryFor(_translationKey(_userLanguageCode)),
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          AppText(
            _ui('frontLabel'),
            style: const TextStyle(
              color: _accentColor,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          AppText(
            card.textFor(_translationKey(_learningLanguageCode)),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              height: 1.14,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _panelColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _isRevealed ? _buildMeaning(card) : _buildHiddenHint(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHiddenHint() {
    return Row(
      key: const ValueKey<String>('hidden'),
      children: <Widget>[
        const Icon(Icons.visibility_outlined, color: _accentColor, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: AppText(
            _ui('hint'),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMeaning(_ReviewCardItem card) {
    return Column(
      key: const ValueKey<String>('meaning'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AppText(
          _ui('meaning'),
          style: const TextStyle(
            color: _successColor,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        AppText(
          card.textFor(_translationKey(_userLanguageCode)),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            height: 1.22,
          ),
        ),
        const SizedBox(height: 10),
        AppText(
          card.contextFor(_translationKey(_userLanguageCode)),
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 13,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _panelColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _accentColor.withValues(alpha: 0.25)),
      ),
      child: _isRevealed ? _buildDecisionButtons() : _buildRevealButton(),
    );
  }

  Widget _buildRevealButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        onPressed: _showMeaning,
        icon: const Icon(Icons.visibility),
        label: AppText(_ui('showMeaning')),
        style: FilledButton.styleFrom(
          backgroundColor: _primaryBlue,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _buildDecisionButtons() {
    return Row(
      children: <Widget>[
        Expanded(
          child: SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: _markForReview,
              icon: const Icon(Icons.refresh),
              label: AppText(_ui('reviewAgain')),
              style: OutlinedButton.styleFrom(
                foregroundColor: _warningColor,
                side: BorderSide(color: _warningColor.withValues(alpha: 0.65)),
                textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _markKnown,
              icon: const Icon(Icons.check_circle),
              label: AppText(_ui('iKnow')),
              style: FilledButton.styleFrom(
                backgroundColor: _successColor,
                foregroundColor: const Color(0xFF062014),
                textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFinishedState() {
    final int total = _knownCount + _reviewCount;
    final int percent = total == 0 ? 0 : ((_knownCount / total) * 100).round();

    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: _successColor.withValues(alpha: 0.45)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.workspace_premium, color: _successColor, size: 54),
            const SizedBox(height: 14),
            AppText(
              _ui('finishedTitle'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            AppText(
              _ui('finishedSubtitle'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                _buildFinalMetric(_ui('known'), '$_knownCount'),
                const SizedBox(width: 8),
                _buildFinalMetric(_ui('toReview'), '$_reviewCount'),
                const SizedBox(width: 8),
                _buildFinalMetric(_ui('mastery'), '$percent%'),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _restart,
                icon: const Icon(Icons.replay),
                label: AppText(_ui('newReview')),
                style: FilledButton.styleFrom(
                  backgroundColor: _primaryBlue,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinalMetric(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: _panelColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _accentColor.withValues(alpha: 0.18)),
        ),
        child: Column(
          children: <Widget>[
            AppText(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            AppText(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _normaliseLanguageCode(String code, {String fallbackCode = 'pt-PT'}) {
    final String value = code.trim();

    if (_availableLanguages.contains(value)) {
      return value;
    }

    final String lower = value.toLowerCase();

    if (lower.startsWith('pt')) return 'pt-PT';
    if (lower.startsWith('en')) return 'en-US';
    if (lower.startsWith('es')) return 'es-ES';
    if (lower.startsWith('fr')) return 'fr-FR';
    if (lower.startsWith('it')) return 'it-IT';
    if (lower.startsWith('de')) return 'de-DE';

    return _availableLanguages.contains(fallbackCode) ? fallbackCode : 'pt-PT';
  }

  String _fallbackLearningLanguage(String userLanguageCode) {
    return userLanguageCode == 'pt-PT' ? 'en-US' : 'pt-PT';
  }

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
    return _languageNames[code] ?? code.toUpperCase();
  }

  String _ui(String key) {
    final String shortCode = _translationKey(_userLanguageCode);
    return _uiTexts[shortCode]?[key] ?? _uiTexts['pt']![key] ?? key;
  }
}

class _ReviewCardItem {
  const _ReviewCardItem({
    required this.id,
    required this.category,
    required this.context,
    required this.translations,
  });

  final String id;
  final Map<String, String> category;
  final Map<String, String> context;
  final Map<String, String> translations;

  String categoryFor(String languageCode) {
    return category[languageCode] ?? category['en'] ?? category['pt'] ?? id;
  }

  String contextFor(String languageCode) {
    return context[languageCode] ?? context['en'] ?? context['pt'] ?? id;
  }

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
    'back': 'Voltar',
    'review': 'Revisão',
    'known': 'Sei',
    'toReview': 'Rever',
    'streak': 'Série',
    'cardTitle': 'Cartão de revisão',
    'frontLabel': 'FRASE A PRATICAR',
    'hint': 'Lê a frase e tenta recordar o significado antes de revelar.',
    'meaning': 'SIGNIFICADO',
    'showMeaning': 'Mostrar significado',
    'reviewAgain': 'Preciso rever',
    'iKnow': 'Já sei',
    'finishedTitle': 'Revisão concluída',
    'finishedSubtitle': 'Boa sessão. As frases marcadas para rever podem voltar numa ronda posterior.',
    'mastery': 'Domínio',
    'newReview': 'Nova revisão',
  },
  'en': <String, String>{
    'back': 'Back',
    'review': 'Review',
    'known': 'Known',
    'toReview': 'Review',
    'streak': 'Streak',
    'cardTitle': 'Review card',
    'frontLabel': 'PHRASE TO PRACTICE',
    'hint': 'Read the phrase and try to remember the meaning before revealing it.',
    'meaning': 'MEANING',
    'showMeaning': 'Show meaning',
    'reviewAgain': 'Review again',
    'iKnow': 'I know it',
    'finishedTitle': 'Review completed',
    'finishedSubtitle': 'Good session. Phrases marked for review can return in a later round.',
    'mastery': 'Mastery',
    'newReview': 'New review',
  },
  'es': <String, String>{
    'back': 'Volver',
    'review': 'Revisión',
    'known': 'Sé',
    'toReview': 'Revisar',
    'streak': 'Racha',
    'cardTitle': 'Tarjeta de revisión',
    'frontLabel': 'FRASE A PRACTICAR',
    'hint': 'Lee la frase e intenta recordar el significado antes de revelarlo.',
    'meaning': 'SIGNIFICADO',
    'showMeaning': 'Mostrar significado',
    'reviewAgain': 'Necesito revisar',
    'iKnow': 'Ya lo sé',
    'finishedTitle': 'Revisión completada',
    'finishedSubtitle': 'Buena sesión. Las frases marcadas para revisar pueden volver en otra ronda.',
    'mastery': 'Dominio',
    'newReview': 'Nueva revisión',
  },
  'fr': <String, String>{
    'back': 'Retour',
    'review': 'Révision',
    'known': 'Acquis',
    'toReview': 'Revoir',
    'streak': 'Série',
    'cardTitle': 'Carte de révision',
    'frontLabel': 'PHRASE À PRATIQUER',
    'hint': 'Lis la phrase et essaie de te souvenir du sens avant de le révéler.',
    'meaning': 'SENS',
    'showMeaning': 'Afficher le sens',
    'reviewAgain': 'À revoir',
    'iKnow': 'Je sais',
    'finishedTitle': 'Révision terminée',
    'finishedSubtitle': 'Bonne session. Les phrases à revoir peuvent revenir dans une prochaine manche.',
    'mastery': 'Maîtrise',
    'newReview': 'Nouvelle révision',
  },
  'it': <String, String>{
    'back': 'Indietro',
    'review': 'Ripasso',
    'known': 'So',
    'toReview': 'Ripassa',
    'streak': 'Serie',
    'cardTitle': 'Scheda di ripasso',
    'frontLabel': 'FRASE DA PRATICARE',
    'hint': 'Leggi la frase e prova a ricordare il significato prima di mostrarlo.',
    'meaning': 'SIGNIFICATO',
    'showMeaning': 'Mostra significato',
    'reviewAgain': 'Devo ripassare',
    'iKnow': 'Lo so già',
    'finishedTitle': 'Ripasso completato',
    'finishedSubtitle': 'Buona sessione. Le frasi segnate per il ripasso possono tornare in un altro giro.',
    'mastery': 'Padronanza',
    'newReview': 'Nuovo ripasso',
  },
  'de': <String, String>{
    'back': 'Zurück',
    'review': 'Wiederholung',
    'known': 'Kann ich',
    'toReview': 'Üben',
    'streak': 'Serie',
    'cardTitle': 'Wiederholungskarte',
    'frontLabel': 'SATZ ZUM ÜBEN',
    'hint': 'Lies den Satz und versuche, die Bedeutung zu erinnern, bevor du sie aufdeckst.',
    'meaning': 'BEDEUTUNG',
    'showMeaning': 'Bedeutung zeigen',
    'reviewAgain': 'Noch einmal üben',
    'iKnow': 'Kann ich schon',
    'finishedTitle': 'Wiederholung abgeschlossen',
    'finishedSubtitle': 'Gute Sitzung. Sätze zum Wiederholen können später erneut erscheinen.',
    'mastery': 'Sicherheit',
    'newReview': 'Neue Wiederholung',
  },
};

const Map<String, String> _categorySchool = <String, String>{
  'pt': 'Escola',
  'en': 'School',
  'es': 'Escuela',
  'fr': 'École',
  'it': 'Scuola',
  'de': 'Schule',
};

const Map<String, String> _categoryHost = <String, String>{
  'pt': 'Família anfitriã',
  'en': 'Host family',
  'es': 'Familia anfitriona',
  'fr': 'Famille d’accueil',
  'it': 'Famiglia ospitante',
  'de': 'Gastfamilie',
};

const Map<String, String> _categoryHelp = <String, String>{
  'pt': 'Ajuda e segurança',
  'en': 'Help and safety',
  'es': 'Ayuda y seguridad',
  'fr': 'Aide et sécurité',
  'it': 'Aiuto e sicurezza',
  'de': 'Hilfe und Sicherheit',
};

const Map<String, String> _contextSchool = <String, String>{
  'pt': 'Útil em corredores, salas e atividades escolares.',
  'en': 'Useful in corridors, classrooms, and school activities.',
  'es': 'Útil en pasillos, aulas y actividades escolares.',
  'fr': 'Utile dans les couloirs, les salles et les activités scolaires.',
  'it': 'Utile nei corridoi, nelle aule e nelle attività scolastiche.',
  'de': 'Nützlich in Fluren, Klassenräumen und Schulaktivitäten.',
};

const Map<String, String> _contextHost = <String, String>{
  'pt': 'Útil na chegada e na convivência com a família anfitriã.',
  'en': 'Useful when arriving and living with the host family.',
  'es': 'Útil al llegar y convivir con la familia anfitriona.',
  'fr': 'Utile à l’arrivée et dans la vie avec la famille d’accueil.',
  'it': 'Utile all’arrivo e nella vita con la famiglia ospitante.',
  'de': 'Nützlich bei der Ankunft und im Alltag mit der Gastfamilie.',
};

const Map<String, String> _contextHelp = <String, String>{
  'pt': 'Útil quando precisas esclarecer algo ou pedir apoio.',
  'en': 'Useful when you need to clarify something or ask for support.',
  'es': 'Útil cuando necesitas aclarar algo o pedir apoyo.',
  'fr': 'Utile quand tu dois clarifier quelque chose ou demander de l’aide.',
  'it': 'Utile quando devi chiarire qualcosa o chiedere supporto.',
  'de': 'Nützlich, wenn du etwas klären oder um Hilfe bitten musst.',
};

const List<_ReviewCardItem> _reviewBank = <_ReviewCardItem>[
  _ReviewCardItem(
    id: 'where_is_science_room',
    category: _categorySchool,
    context: _contextSchool,
    translations: <String, String>{
      'pt': 'Onde fica a sala de ciências?',
      'en': 'Where is the science room?',
      'es': '¿Dónde está la sala de ciencias?',
      'fr': 'Où est la salle de sciences ?',
      'it': 'Dov’è l’aula di scienze?',
      'de': 'Wo ist der Naturwissenschaftsraum?',
    },
  ),
  _ReviewCardItem(
    id: 'can_i_sit_here',
    category: _categorySchool,
    context: _contextSchool,
    translations: <String, String>{
      'pt': 'Posso sentar-me aqui?',
      'en': 'Can I sit here?',
      'es': '¿Puedo sentarme aquí?',
      'fr': 'Puis-je m’asseoir ici ?',
      'it': 'Posso sedermi qui?',
      'de': 'Kann ich mich hier hinsetzen?',
    },
  ),
  _ReviewCardItem(
    id: 'what_time_class_starts',
    category: _categorySchool,
    context: _contextSchool,
    translations: <String, String>{
      'pt': 'A que horas começa a aula?',
      'en': 'What time does the class start?',
      'es': '¿A qué hora empieza la clase?',
      'fr': 'À quelle heure commence le cours ?',
      'it': 'A che ora inizia la lezione?',
      'de': 'Um wie viel Uhr beginnt der Unterricht?',
    },
  ),
  _ReviewCardItem(
    id: 'i_need_help',
    category: _categoryHelp,
    context: _contextHelp,
    translations: <String, String>{
      'pt': 'Preciso de ajuda.',
      'en': 'I need help.',
      'es': 'Necesito ayuda.',
      'fr': 'J’ai besoin d’aide.',
      'it': 'Ho bisogno di aiuto.',
      'de': 'Ich brauche Hilfe.',
    },
  ),
  _ReviewCardItem(
    id: 'i_do_not_understand',
    category: _categoryHelp,
    context: _contextHelp,
    translations: <String, String>{
      'pt': 'Não compreendo.',
      'en': 'I do not understand.',
      'es': 'No entiendo.',
      'fr': 'Je ne comprends pas.',
      'it': 'Non capisco.',
      'de': 'Ich verstehe nicht.',
    },
  ),
  _ReviewCardItem(
    id: 'can_you_repeat',
    category: _categoryHelp,
    context: _contextHelp,
    translations: <String, String>{
      'pt': 'Pode repetir, por favor?',
      'en': 'Can you repeat, please?',
      'es': '¿Puede repetir, por favor?',
      'fr': 'Pouvez-vous répéter, s’il vous plaît ?',
      'it': 'Può ripetere, per favore?',
      'de': 'Können Sie das bitte wiederholen?',
    },
  ),
  _ReviewCardItem(
    id: 'i_am_allergic',
    category: _categoryHost,
    context: _contextHost,
    translations: <String, String>{
      'pt': 'Sou alérgico a frutos secos.',
      'en': 'I am allergic to nuts.',
      'es': 'Soy alérgico a los frutos secos.',
      'fr': 'Je suis allergique aux fruits à coque.',
      'it': 'Sono allergico alla frutta secca.',
      'de': 'Ich bin gegen Nüsse allergisch.',
    },
  ),
  _ReviewCardItem(
    id: 'where_is_bathroom',
    category: _categoryHost,
    context: _contextHost,
    translations: <String, String>{
      'pt': 'Onde fica a casa de banho?',
      'en': 'Where is the bathroom?',
      'es': '¿Dónde está el baño?',
      'fr': 'Où sont les toilettes ?',
      'it': 'Dov’è il bagno?',
      'de': 'Wo ist die Toilette?',
    },
  ),
  _ReviewCardItem(
    id: 'thank_you_for_help',
    category: _categoryHelp,
    context: _contextHelp,
    translations: <String, String>{
      'pt': 'Obrigado pela ajuda.',
      'en': 'Thank you for your help.',
      'es': 'Gracias por la ayuda.',
      'fr': 'Merci pour votre aide.',
      'it': 'Grazie per l’aiuto.',
      'de': 'Danke für die Hilfe.',
    },
  ),
  _ReviewCardItem(
    id: 'what_is_for_breakfast',
    category: _categoryHost,
    context: _contextHost,
    translations: <String, String>{
      'pt': 'O que há para o pequeno-almoço?',
      'en': 'What is for breakfast?',
      'es': '¿Qué hay para desayunar?',
      'fr': 'Qu’est-ce qu’il y a pour le petit-déjeuner ?',
      'it': 'Che cosa c’è per colazione?',
      'de': 'Was gibt es zum Frühstück?',
    },
  ),
];
