import 'dart:math';

import 'package:flutter/material.dart';

import '../data/dao/app_settings_dao.dart';
import '../data/database/app_database.dart';
import '../data/repositories/auth_repository.dart';

/// Ecrã do jogo "Combina pares" do DailyTalk.pt.
///
/// A coluna da esquerda apresenta palavras/frases no idioma do utilizador.
/// A coluna da direita apresenta as mesmas ideias no idioma que o utilizador
/// quer aprender.
class VocabularyPairsPage extends StatefulWidget {
  const VocabularyPairsPage({
    super.key,
    this.userLanguageCode = 'pt-PT',
    this.learningLanguageCode = 'it-IT',
  });

  /// Idioma do utilizador / idioma da aplicação.
  final String userLanguageCode;

  /// Idioma que o utilizador quer aprender.
  final String learningLanguageCode;

  @override
  State<VocabularyPairsPage> createState() => _VocabularyPairsPageState();
}

class _VocabularyPairsPageState extends State<VocabularyPairsPage> {
  static const Color _backgroundColor = Color(0xFF0D1B22);
  static const Color _cardColor = Color(0xFF071D2A);
  static const Color _panelColor = Color(0xFF10232D);
  static const Color _accentColor = Color(0xFF35C8FF);
  static const Color _primaryBlue = Color(0xFF168CFF);

  late String _userLanguageCode;
  late String _learningLanguageCode;

  late List<_VocabularyPairCard> _leftCards;
  late List<_VocabularyPairCard> _rightCards;

  final Set<String> _matchedIds = <String>{};

  _VocabularyPairCard? _selectedLeft;
  _VocabularyPairCard? _selectedRight;

  String? _wrongLeftId;
  String? _wrongRightId;

  int _attempts = 0;
  String _feedbackKey = 'choosePairs';

  bool get _isCompleted =>
      _leftCards.isNotEmpty && _matchedIds.length == _leftCards.length;

  @override
  void initState() {
    super.initState();

    _userLanguageCode = _normaliseLanguageCode(widget.userLanguageCode);
    _learningLanguageCode = _normaliseLanguageCode(widget.learningLanguageCode);

    // Evita o caso em que as duas colunas ficam no mesmo idioma.
    if (_userLanguageCode == _learningLanguageCode) {
      _learningLanguageCode = _fallbackLearningLanguage(_userLanguageCode);
    }

    _startNewRound();

    Future<void>.microtask(_loadSavedLanguages);
  }

  /// Carrega os idiomas definidos no ecrã Language.
  ///
  /// A fonte principal é a tabela local app_settings, através das mesmas chaves
  /// usadas por LanguageSelectionPage: native_language_code e target_language_code.
  /// Quando a sessão remota está disponível, também sincroniza com o perfil remoto
  /// para manter o comportamento igual ao ecrã Language.
  Future<void> _loadSavedLanguages() async {
    try {
      final db = await AppDatabase.instance.database;
      final settingsDao = AppSettingsDao(db);

      var nativeLanguageCode = await settingsDao.getNativeLanguageCode();
      var targetLanguageCode = await settingsDao.getTargetLanguageCode();

      _applyLoadedLanguages(
        nativeLanguageCode: nativeLanguageCode,
        targetLanguageCode: targetLanguageCode,
      );

      try {
        final currentUser = await AuthRepository().getCurrentUser();

        if (currentUser != null) {
          nativeLanguageCode = _normaliseLanguageCode(
            currentUser.preferences.appLanguageCode,
          );
          targetLanguageCode = _normaliseLanguageCode(
            currentUser.preferences.learningLanguageCode,
          );

          await settingsDao.setLanguagePair(
            nativeLanguageCode: nativeLanguageCode,
            targetLanguageCode: targetLanguageCode,
          );

          _applyLoadedLanguages(
            nativeLanguageCode: nativeLanguageCode,
            targetLanguageCode: targetLanguageCode,
          );
        }
      } catch (_) {
        // Se a API/sessão remota não estiver disponível, fica a cache local.
      }
    } catch (_) {
      // Se a base local ainda não estiver disponível, mantém os valores do construtor.
    }
  }

  /// Aplica o par de idiomas carregado e recria a ronda se houver mudança.
  void _applyLoadedLanguages({
    required String nativeLanguageCode,
    required String targetLanguageCode,
  }) {
    if (!mounted) {
      return;
    }

    final String nextUserLanguage = _normaliseLanguageCode(nativeLanguageCode);
    String nextLearningLanguage = _normaliseLanguageCode(targetLanguageCode);

    if (nextUserLanguage == nextLearningLanguage) {
      nextLearningLanguage = _fallbackLearningLanguage(nextUserLanguage);
    }

    if (nextUserLanguage == _userLanguageCode &&
        nextLearningLanguage == _learningLanguageCode) {
      return;
    }

    setState(() {
      _userLanguageCode = nextUserLanguage;
      _learningLanguageCode = nextLearningLanguage;
      _startNewRound();
    });
  }

  /// Prepara uma nova ronda com pares contextualizados para o DailyTalk.pt.
  void _startNewRound() {
    final List<_VocabularyItem> selectedItems = _vocabularyBank.toList()
      ..shuffle(Random());

    final List<_VocabularyItem> roundItems = selectedItems.take(6).toList();

    _leftCards = roundItems
        .map(
          (item) => _VocabularyPairCard(
            id: item.id,
            text: item.textFor(_translationKey(_userLanguageCode)),
          ),
        )
        .toList();

    _rightCards = roundItems
        .map(
          (item) => _VocabularyPairCard(
            id: item.id,
            text: item.textFor(_translationKey(_learningLanguageCode)),
          ),
        )
        .toList()
      ..shuffle(Random());

    _matchedIds.clear();
    _selectedLeft = null;
    _selectedRight = null;
    _wrongLeftId = null;
    _wrongRightId = null;
    _attempts = 0;
    _feedbackKey = 'choosePairs';
  }

  /// Trata a seleção de um cartão da esquerda ou da direita.
  void _selectCard(_VocabularyPairCard card, {required bool isLeft}) {
    if (_matchedIds.contains(card.id)) {
      return;
    }

    setState(() {
      _wrongLeftId = null;
      _wrongRightId = null;

      if (isLeft) {
        _selectedLeft = card;
      } else {
        _selectedRight = card;
      }
    });

    if (_selectedLeft != null && _selectedRight != null) {
      _checkCurrentSelection();
    }
  }

  /// Valida se os dois cartões selecionados pertencem ao mesmo par.
  Future<void> _checkCurrentSelection() async {
    final _VocabularyPairCard? left = _selectedLeft;
    final _VocabularyPairCard? right = _selectedRight;

    if (left == null || right == null) {
      return;
    }

    if (left.id == right.id) {
      setState(() {
        _attempts++;
        _matchedIds.add(left.id);
        _selectedLeft = null;
        _selectedRight = null;
        _feedbackKey = _isCompleted ? 'completed' : 'correct';
      });

      return;
    }

    setState(() {
      _attempts++;
      _wrongLeftId = left.id;
      _wrongRightId = right.id;
      _feedbackKey = 'tryAgain';
    });

    await Future<void>.delayed(const Duration(milliseconds: 750));

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedLeft = null;
      _selectedRight = null;
      _wrongLeftId = null;
      _wrongRightId = null;
    });
  }

  /// Reinicia manualmente a ronda atual.
  void _resetRound() {
    setState(_startNewRound);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: _buildAppBarBrand(),
      ),
      bottomNavigationBar: _buildFooter(),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _buildCardsColumn(
                    title: _languageName(_userLanguageCode),
                    subtitle: _ui('sourceColumn'),
                    cards: _leftCards,
                    isLeft: true,
                  ),
                  const SizedBox(width: 14),
                  _buildCardsColumn(
                    title: _languageName(_learningLanguageCode),
                    subtitle: _ui('targetColumn'),
                    cards: _rightCards,
                    isLeft: false,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBarBrand() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF06345C),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _accentColor.withValues(alpha: 0.38),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: _accentColor.withValues(alpha: 0.16),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.menu_book,
            color: Colors.amber,
            size: 25,
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'DailyTalk.pt',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }

  /// Constrói uma coluna de cartões.
  Widget _buildCardsColumn({
    required String title,
    required String subtitle,
    required List<_VocabularyPairCard> cards,
    required bool isLeft,
  }) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _panelColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _accentColor.withValues(alpha: 0.28),
              ),
            ),
            child: Column(
              children: <Widget>[
                Text(
                  subtitle.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _accentColor.withValues(alpha: 0.86),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.separated(
              itemCount: cards.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                return _buildPairCard(cards[index], isLeft: isLeft);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Constrói cada cartão selecionável do jogo.
  Widget _buildPairCard(
    _VocabularyPairCard card, {
    required bool isLeft,
  }) {
    final bool isMatched = _matchedIds.contains(card.id);
    final bool isSelected =
        isLeft ? _selectedLeft?.id == card.id : _selectedRight?.id == card.id;
    final bool isWrong =
        isLeft ? _wrongLeftId == card.id : _wrongRightId == card.id;

    Color borderColor = Colors.white.withValues(alpha: 0.14);
    Color backgroundColor = _cardColor.withValues(alpha: 0.92);
    Color textColor = Colors.white;
    IconData? trailingIcon;
    Color? trailingColor;

    if (isMatched) {
      borderColor = Colors.greenAccent.withValues(alpha: 0.72);
      backgroundColor = Colors.greenAccent.withValues(alpha: 0.11);
      trailingIcon = Icons.check_circle;
      trailingColor = Colors.greenAccent;
    } else if (isWrong) {
      borderColor = Colors.redAccent.withValues(alpha: 0.90);
      backgroundColor = Colors.redAccent.withValues(alpha: 0.15);
      trailingIcon = Icons.close;
      trailingColor = Colors.redAccent;
    } else if (isSelected) {
      borderColor = _accentColor;
      backgroundColor = _accentColor.withValues(alpha: 0.14);
      textColor = _accentColor;
      trailingIcon = Icons.radio_button_checked;
      trailingColor = _accentColor;
    }

    return Opacity(
      opacity: isMatched ? 0.78 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isMatched ? null : () => _selectCard(card, isLeft: isLeft),
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            constraints: const BoxConstraints(minHeight: 74),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: borderColor,
                width: isSelected || isWrong || isMatched ? 2.0 : 1.2,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 14,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Flexible(
                  child: Text(
                    card.text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      height: 1.18,
                    ),
                  ),
                ),
                if (trailingIcon != null) ...<Widget>[
                  const SizedBox(width: 8),
                  Icon(
                    trailingIcon,
                    color: trailingColor,
                    size: 20,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Rodapé com estado da ronda, progresso e ação de reinício.
  Widget _buildFooter() {
    final int total = _leftCards.length;
    final int completed = _matchedIds.length;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: _cardDecoration(
          color: _panelColor.withValues(alpha: 0.96),
          borderColor: _accentColor.withValues(alpha: 0.24),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    _isCompleted ? _ui('completed') : _ui(_feedbackKey),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$completed/$total • $_attempts ${_ui('attempts')}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.56),
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    Color(0xFF49D7FF),
                    _primaryBlue,
                  ],
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: _primaryBlue.withValues(alpha: 0.30),
                    blurRadius: 16,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: IconButton(
                tooltip: _ui('newRound'),
                onPressed: _resetRound,
                color: Colors.white,
                icon: const Icon(Icons.refresh),
              ),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration({
    Color? color,
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: color ?? _cardColor.withValues(alpha: 0.86),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: borderColor ?? Colors.white.withValues(alpha: 0.14),
        width: 1.2,
      ),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.18),
          blurRadius: 18,
          offset: const Offset(0, 9),
        ),
      ],
    );
  }

  /// Normaliza códigos vindos da app, como pt-PT, en-US, fr-FR, it-IT, etc.
  String _normaliseLanguageCode(String code) {
    final String value = code.trim();

    for (final _DailyTalkLanguage language in _availableLanguages) {
      if (language.code.toLowerCase() == value.toLowerCase()) {
        return language.code;
      }
    }

    final String lower = value.toLowerCase().replaceAll('_', '-');

    if (lower.startsWith('pt')) return 'pt-PT';
    if (lower.startsWith('en')) return 'en-US';
    if (lower.startsWith('es')) return 'es-ES';
    if (lower.startsWith('fr')) return 'fr-FR';
    if (lower.startsWith('it')) return 'it-IT';
    if (lower.startsWith('de')) return 'de-DE';
    return 'pt-PT';
  }

  /// Converte o código completo da app para a chave curta usada no banco local.
  String _translationKey(String code) {
    final String lower = code.toLowerCase().replaceAll('_', '-');

    if (lower.startsWith('pt')) return 'pt';
    if (lower.startsWith('en')) return 'en';
    if (lower.startsWith('es')) return 'es';
    if (lower.startsWith('fr')) return 'fr';
    if (lower.startsWith('it')) return 'it';
    if (lower.startsWith('de')) return 'de';
    if (lower.startsWith('zh') || lower.startsWith('cn')) return 'zh';

    return 'pt';
  }

  String _fallbackLearningLanguage(String userLanguageCode) {
    return userLanguageCode == 'pt-PT' ? 'en-US' : 'pt-PT';
  }


  String _languageName(String code) {
    for (final _DailyTalkLanguage language in _availableLanguages) {
      if (language.code == code) {
        return language.name;
      }
    }

    return code.toUpperCase();
  }

  String _ui(String key) {
    final String uiLanguageKey = _translationKey(_userLanguageCode);
    return _uiTexts[uiLanguageKey]?[key] ?? _uiTexts['pt']![key] ?? key;
  }
}

/// Idioma disponível no DailyTalk.pt.
class _DailyTalkLanguage {
  const _DailyTalkLanguage({
    required this.code,
    required this.name,
  });

  final String code;
  final String name;
}

/// Cartão apresentado no ecrã.
class _VocabularyPairCard {
  const _VocabularyPairCard({
    required this.id,
    required this.text,
  });

  final String id;
  final String text;
}

/// Item do banco de vocabulário contextualizado.
class _VocabularyItem {
  const _VocabularyItem({
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

/// Lista de idiomas alinhada com a seleção de idioma da aplicação.
///
/// Se a página language_selection_page.dart tiver uma lista diferente, esta é a
/// única zona que precisa de ser ajustada neste ecrã.
const List<_DailyTalkLanguage> _availableLanguages = <_DailyTalkLanguage>[
  _DailyTalkLanguage(code: 'pt-PT', name: 'Português'),
  _DailyTalkLanguage(code: 'en-US', name: 'English'),
  _DailyTalkLanguage(code: 'es-ES', name: 'Español'),
  _DailyTalkLanguage(code: 'fr-FR', name: 'Français'),
  _DailyTalkLanguage(code: 'it-IT', name: 'Italiano'),
  _DailyTalkLanguage(code: 'de-DE', name: 'Deutsch'),
];

const Map<String, Map<String, String>> _uiTexts = <String, Map<String, String>>{
  'pt': <String, String>{
    'title': 'Combina pares',
    'heroTitle': 'Vocabulário DailyTalk.pt',
    'sourceColumn': 'Idioma do utilizador',
    'targetColumn': 'Idioma a aprender',
    'instructions':
        'Liga cada palavra ou frase do DailyTalk.pt ao significado correto no idioma que estás a aprender.',
    'userLanguage': 'Idioma do utilizador',
    'learningLanguage': 'Idioma a aprender',
    'choosePairs': 'Escolhe um cartão de cada lado.',
    'correct': 'Correto. Continua.',
    'tryAgain': 'Esse par não corresponde. Tenta novamente.',
    'completed': 'Ronda concluída. Muito bem!',
    'attempts': 'tentativas',
    'newRound': 'Nova ronda',
  },
  'en': <String, String>{
    'title': 'Match pairs',
    'heroTitle': 'DailyTalk.pt vocabulary',
    'sourceColumn': 'User language',
    'targetColumn': 'Learning language',
    'instructions':
        'Match each DailyTalk.pt word or sentence with the correct meaning in the language you are learning.',
    'userLanguage': 'User language',
    'learningLanguage': 'Learning language',
    'choosePairs': 'Choose one card from each side.',
    'correct': 'Correct. Keep going.',
    'tryAgain': 'That pair does not match. Try again.',
    'completed': 'Round completed. Well done!',
    'attempts': 'attempts',
    'newRound': 'New round',
  },
  'es': <String, String>{
    'title': 'Combina pares',
    'heroTitle': 'Vocabulario DailyTalk.pt',
    'sourceColumn': 'Idioma del usuario',
    'targetColumn': 'Idioma a aprender',
    'instructions':
        'Une cada palabra o frase de DailyTalk.pt con su significado correcto en el idioma que estás aprendiendo.',
    'userLanguage': 'Idioma del usuario',
    'learningLanguage': 'Idioma a aprender',
    'choosePairs': 'Elige una tarjeta de cada lado.',
    'correct': 'Correcto. Continúa.',
    'tryAgain': 'Ese par no corresponde. Inténtalo de nuevo.',
    'completed': 'Ronda completada. ¡Muy bien!',
    'attempts': 'intentos',
    'newRound': 'Nueva ronda',
  },
  'fr': <String, String>{
    'title': 'Associer les paires',
    'heroTitle': 'Vocabulaire DailyTalk.pt',
    'sourceColumn': 'Langue utilisateur',
    'targetColumn': 'Langue à apprendre',
    'instructions':
        'Associe chaque mot ou phrase DailyTalk.pt au sens correct dans la langue que tu apprends.',
    'userLanguage': 'Langue utilisateur',
    'learningLanguage': 'Langue à apprendre',
    'choosePairs': 'Choisis une carte de chaque côté.',
    'correct': 'Correct. Continue.',
    'tryAgain': 'Cette paire ne correspond pas. Réessaie.',
    'completed': 'Manche terminée. Très bien!',
    'attempts': 'essais',
    'newRound': 'Nouvelle manche',
  },
  'it': <String, String>{
    'title': 'Abbina le coppie',
    'heroTitle': 'Vocabolario DailyTalk.pt',
    'sourceColumn': 'Lingua utente',
    'targetColumn': 'Lingua da imparare',
    'instructions':
        'Abbina ogni parola o frase di DailyTalk.pt al significato corretto nella lingua che stai imparando.',
    'userLanguage': 'Lingua utente',
    'learningLanguage': 'Lingua da imparare',
    'choosePairs': 'Scegli una carta da ogni lato.',
    'correct': 'Corretto. Continua.',
    'tryAgain': 'Questa coppia non corrisponde. Riprova.',
    'completed': 'Round completato. Molto bene!',
    'attempts': 'tentativi',
    'newRound': 'Nuovo round',
  },
  'de': <String, String>{
    'title': 'Paare finden',
    'heroTitle': 'DailyTalk.pt-Wortschatz',
    'sourceColumn': 'Nutzersprache',
    'targetColumn': 'Lernsprache',
    'instructions':
        'Verbinde jedes DailyTalk.pt-Wort oder jeden Satz mit der richtigen Bedeutung in der Lernsprache.',
    'userLanguage': 'Nutzersprache',
    'learningLanguage': 'Lernsprache',
    'choosePairs': 'Wähle je eine Karte auf jeder Seite.',
    'correct': 'Richtig. Weiter so.',
    'tryAgain': 'Dieses Paar passt nicht. Versuche es erneut.',
    'completed': 'Runde abgeschlossen. Sehr gut!',
    'attempts': 'Versuche',
    'newRound': 'Neue Runde',
  },
  'zh': <String, String>{
    'title': '配对练习',
    'heroTitle': 'DailyTalk.pt 词汇',
    'sourceColumn': '用户语言',
    'targetColumn': '学习语言',
    'instructions': '把每个 DailyTalk.pt 单词或句子与学习语言中的正确意思配对。',
    'userLanguage': '用户语言',
    'learningLanguage': '学习语言',
    'choosePairs': '左右各选择一张卡片。',
    'correct': '正确。继续。',
    'tryAgain': '这组不匹配。再试一次。',
    'completed': '本轮完成。很好！',
    'attempts': '次尝试',
    'newRound': '新一轮',
  },
};

/// Banco inicial de vocabulário contextualizado para o DailyTalk.pt.
///
/// A intenção não é ter palavras soltas aleatórias, mas situações reais:
/// chegada à casa, escola, anfitrião, alimentação, ajuda e comunicação básica.
const List<_VocabularyItem> _vocabularyBank = <_VocabularyItem>[
  _VocabularyItem(
    id: 'hello',
    translations: <String, String>{
      'pt': 'Olá',
      'en': 'Hello',
      'es': 'Hola',
      'fr': 'Bonjour',
      'it': 'Ciao',
      'de': 'Hallo',
      'zh': '你好',
    },
  ),
  _VocabularyItem(
    id: 'good_morning',
    translations: <String, String>{
      'pt': 'Bom dia',
      'en': 'Good morning',
      'es': 'Buenos días',
      'fr': 'Bonjour',
      'it': 'Buongiorno',
      'de': 'Guten Morgen',
      'zh': '早上好',
    },
  ),
  _VocabularyItem(
    id: 'thank_you',
    translations: <String, String>{
      'pt': 'Obrigado',
      'en': 'Thank you',
      'es': 'Gracias',
      'fr': 'Merci',
      'it': 'Grazie',
      'de': 'Danke',
      'zh': '谢谢',
    },
  ),
  _VocabularyItem(
    id: 'please',
    translations: <String, String>{
      'pt': 'Por favor',
      'en': 'Please',
      'es': 'Por favor',
      'fr': 'S’il vous plaît',
      'it': 'Per favore',
      'de': 'Bitte',
      'zh': '请',
    },
  ),
  _VocabularyItem(
    id: 'bathroom',
    translations: <String, String>{
      'pt': 'Casa de banho',
      'en': 'Bathroom',
      'es': 'Baño',
      'fr': 'Salle de bain',
      'it': 'Bagno',
      'de': 'Badezimmer',
      'zh': '洗手间',
    },
  ),
  _VocabularyItem(
    id: 'bedroom',
    translations: <String, String>{
      'pt': 'Quarto',
      'en': 'Bedroom',
      'es': 'Habitación',
      'fr': 'Chambre',
      'it': 'Camera',
      'de': 'Schlafzimmer',
      'zh': '卧室',
    },
  ),
  _VocabularyItem(
    id: 'breakfast',
    translations: <String, String>{
      'pt': 'Pequeno-almoço',
      'en': 'Breakfast',
      'es': 'Desayuno',
      'fr': 'Petit-déjeuner',
      'it': 'Colazione',
      'de': 'Frühstück',
      'zh': '早餐',
    },
  ),
  _VocabularyItem(
    id: 'school',
    translations: <String, String>{
      'pt': 'Escola',
      'en': 'School',
      'es': 'Escuela',
      'fr': 'École',
      'it': 'Scuola',
      'de': 'Schule',
      'zh': '学校',
    },
  ),
  _VocabularyItem(
    id: 'teacher',
    translations: <String, String>{
      'pt': 'Professor',
      'en': 'Teacher',
      'es': 'Profesor',
      'fr': 'Professeur',
      'it': 'Insegnante',
      'de': 'Lehrer',
      'zh': '老师',
    },
  ),
  _VocabularyItem(
    id: 'host_family',
    translations: <String, String>{
      'pt': 'Família anfitriã',
      'en': 'Host family',
      'es': 'Familia anfitriona',
      'fr': 'Famille d’accueil',
      'it': 'Famiglia ospitante',
      'de': 'Gastfamilie',
      'zh': '寄宿家庭',
    },
  ),
  _VocabularyItem(
    id: 'i_need_help',
    translations: <String, String>{
      'pt': 'Preciso de ajuda',
      'en': 'I need help',
      'es': 'Necesito ayuda',
      'fr': 'J’ai besoin d’aide',
      'it': 'Ho bisogno di aiuto',
      'de': 'Ich brauche Hilfe',
      'zh': '我需要帮助',
    },
  ),
  _VocabularyItem(
    id: 'i_do_not_understand',
    translations: <String, String>{
      'pt': 'Não compreendo',
      'en': 'I do not understand',
      'es': 'No entiendo',
      'fr': 'Je ne comprends pas',
      'it': 'Non capisco',
      'de': 'Ich verstehe nicht',
      'zh': '我不明白',
    },
  ),
  _VocabularyItem(
    id: 'can_you_repeat',
    translations: <String, String>{
      'pt': 'Pode repetir?',
      'en': 'Can you repeat?',
      'es': '¿Puede repetir?',
      'fr': 'Pouvez-vous répéter?',
      'it': 'Puoi ripetere?',
      'de': 'Können Sie das wiederholen?',
      'zh': '可以再说一遍吗？',
    },
  ),
  _VocabularyItem(
    id: 'what_time',
    translations: <String, String>{
      'pt': 'A que horas?',
      'en': 'What time?',
      'es': '¿A qué hora?',
      'fr': 'À quelle heure?',
      'it': 'A che ora?',
      'de': 'Um wie viel Uhr?',
      'zh': '几点？',
    },
  ),
  _VocabularyItem(
    id: 'where_is_the_bathroom',
    translations: <String, String>{
      'pt': 'Onde fica a casa de banho?',
      'en': 'Where is the bathroom?',
      'es': '¿Dónde está el baño?',
      'fr': 'Où sont les toilettes?',
      'it': 'Dov’è il bagno?',
      'de': 'Wo ist die Toilette?',
      'zh': '洗手间在哪里？',
    },
  ),
  _VocabularyItem(
    id: 'i_am_allergic',
    translations: <String, String>{
      'pt': 'Sou alérgico',
      'en': 'I am allergic',
      'es': 'Soy alérgico',
      'fr': 'Je suis allergique',
      'it': 'Sono allergico',
      'de': 'Ich bin allergisch',
      'zh': '我过敏',
    },
  ),
  _VocabularyItem(
    id: 'i_am_hungry',
    translations: <String, String>{
      'pt': 'Tenho fome',
      'en': 'I am hungry',
      'es': 'Tengo hambre',
      'fr': 'J’ai faim',
      'it': 'Ho fame',
      'de': 'Ich habe Hunger',
      'zh': '我饿了',
    },
  ),
  _VocabularyItem(
    id: 'i_am_tired',
    translations: <String, String>{
      'pt': 'Estou cansado',
      'en': 'I am tired',
      'es': 'Estoy cansado',
      'fr': 'Je suis fatigué',
      'it': 'Sono stanco',
      'de': 'Ich bin müde',
      'zh': '我累了',
    },
  ),
];
