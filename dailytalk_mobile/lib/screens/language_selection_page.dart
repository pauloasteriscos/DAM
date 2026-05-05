import 'package:flutter/material.dart';

/// Language configuration page.
///
/// The app does not use only one language.
/// The student chooses:
/// - the language they normally use;
/// - the language they want to learn/practice.
class LanguageSelectionPage extends StatefulWidget {
  const LanguageSelectionPage({super.key});

  @override
  State<LanguageSelectionPage> createState() => _LanguageSelectionPageState();
}

class _LanguageSelectionPageState extends State<LanguageSelectionPage> {
  String _nativeLanguageCode = 'pt-PT';
  String _targetLanguageCode = 'it-IT';

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

  void _saveLanguages() {
    if (_nativeLanguageCode == _targetLanguageCode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please choose two different languages.',
          ),
        ),
      );
      return;
    }

    final nativeLanguage = _languageByCode(_nativeLanguageCode);
    final targetLanguage = _languageByCode(_targetLanguageCode);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Saved: ${nativeLanguage.name} → ${targetLanguage.name}',
        ),
      ),
    );

    Navigator.pop(context);
  }

  LanguageOption _languageByCode(String code) {
    return _languages.firstWhere(
      (language) => language.code == code,
      orElse: () => _languages.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final nativeLanguage = _languageByCode(_nativeLanguageCode);
    final targetLanguage = _languageByCode(_targetLanguageCode);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B22),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B22),
        foregroundColor: Colors.white,
        title: const Text('Language'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              _buildIntroCard(),
              const SizedBox(height: 18),
              _buildLanguageSelector(
                title: 'My language',
                description:
                    'Choose the language you normally use. This may also be used as the app interface language.',
                selectedCode: _nativeLanguageCode,
                selectedLanguage: nativeLanguage,
                onChanged: (value) {
                  setState(() {
                    _nativeLanguageCode = value!;
                  });
                },
              ),
              const SizedBox(height: 18),
              _buildLanguageSelector(
                title: 'I want to learn',
                description:
                    'Choose the language you want to practice in activities, dialogues, audio exercises, quizzes and challenges.',
                selectedCode: _targetLanguageCode,
                selectedLanguage: targetLanguage,
                onChanged: (value) {
                  setState(() {
                    _targetLanguageCode = value!;
                  });
                },
              ),
              const SizedBox(height: 22),
              _buildLearningPathCard(
                nativeLanguage: nativeLanguage,
                targetLanguage: targetLanguage,
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _saveLanguages,
                  icon: const Icon(Icons.check),
                  label: const Text(
                    'Save languages',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF14252D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white12,
        ),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.language,
            color: Colors.lightBlueAccent,
            size: 50,
          ),
          SizedBox(height: 12),
          Text(
            'Language settings',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Select your usual language and the language you want to learn. '
            'DailyTalk.pt will use this pair to suggest and prepare activities.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              height: 1.4,
            ),
          ),
        ],
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
      decoration: BoxDecoration(
        color: const Color(0xFF14252D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                selectedLanguage.flag,
                style: const TextStyle(fontSize: 34),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              color: Colors.white70,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: selectedCode,
            dropdownColor: const Color(0xFF14252D),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF0D1B22),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.white24),
              ),
            ),
            items: _languages.map((language) {
              return DropdownMenuItem<String>(
                value: language.code,
                child: Text('${language.flag} ${language.name}'),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.lightBlue.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.lightBlueAccent.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        children: [
          const Text(
            'Learning path',
            style: TextStyle(
              color: Colors.lightBlueAccent,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '${nativeLanguage.flag} ${nativeLanguage.name}  →  '
            '${targetLanguage.flag} ${targetLanguage.name}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Activities will be prepared based on the language you know and the language you want to practice.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

/// Represents an available language option.
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