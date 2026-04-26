import 'package:flutter/material.dart';

/// Tela de seleção de idioma da aplicação.
class LanguageSelectionPage extends StatelessWidget {
  const LanguageSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final languages = const [
      _LanguageOption(
        code: 'pt-PT',
        name: 'Português',
        description: 'Português de Portugal',
        flag: '🇵🇹',
      ),
      _LanguageOption(
        code: 'en-US',
        name: 'English',
        description: 'English - United States',
        flag: '🇺🇸',
      ),
      _LanguageOption(
        code: 'es-ES',
        name: 'Español',
        description: 'Spanish - Spain',
        flag: '🇪🇸',
      ),
      _LanguageOption(
        code: 'fr-FR',
        name: 'Français',
        description: 'French - France',
        flag: '🇫🇷',
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B22),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B22),
        foregroundColor: Colors.white,
        title: const Text('Language'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: languages.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final language = languages[index];

          return Card(
            color: const Color(0xFF14252D),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 10,
              ),
              leading: Text(
                language.flag,
                style: const TextStyle(fontSize: 32),
              ),
              title: Text(
                language.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                language.description,
                style: const TextStyle(
                  color: Colors.white70,
                ),
              ),
              trailing: const Icon(
                Icons.chevron_right,
                color: Colors.white70,
              ),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Idioma selecionado: ${language.code}'),
                  ),
                );

                Navigator.pop(context);
              },
            ),
          );
        },
      ),
    );
  }
}

/// Modelo interno para representar cada opção de idioma.
class _LanguageOption {
  const _LanguageOption({
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