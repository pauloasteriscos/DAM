import 'dart:math';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

import '../state/app_session_controller.dart';
import 'analytics_content.dart';
import 'vocabulary_pairs_page.dart';
import 'quiz_page.dart';
import 'dialogue_page.dart';
import 'home_gamificada.dart';
import 'placeholder_page.dart';
import 'practice_content.dart';
import 'results_content.dart';
import 'settings_content.dart';

/// Tela principal da aplicação.
///
/// Esta classe controla a navegação inferior da app.
/// O modo teste/autenticado é observado através de [AppSessionController],
/// evitando passar o mesmo parâmetro manualmente por todas as telas.
class MainNavigation extends StatefulWidget {
  const MainNavigation({
    super.key,
    this.isTestMode = false,
    this.onAuthenticated,
  });

  /// Mantido apenas por compatibilidade com versões anteriores do código.
  /// O estado real passa a vir do AppSessionController.
  final bool isTestMode;

  /// Callback chamado quando o utilizador autentica a partir do modo teste.
  final VoidCallback? onAuthenticated;

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  final Random _random = Random();

  /// Índice atualmente selecionado no menu inferior.
  int _selectedIndex = 0;

  /// Lista das páginas associadas ao menu inferior.
  ///
  /// O IndexedStack mantém o estado das páginas ao trocar de aba.
  List<Widget> _buildPages(BuildContext context) {
    final session = AppSessionScope.watch(context);

    void handleAuthenticated() {
      widget.onAuthenticated?.call();
      AppSessionScope.read(context).markAuthenticated();
    }

    return [
      HomeGamificada(
        isTestMode: session.isTestMode,
        onAuthenticated: handleAuthenticated,
      ),
      const PlaceholderPage(
        title: 'Praticar',
        message:
            'Responde a atividades predefinidas e melhora a tua comunicação.',
        icon: Icons.play_circle_outline,
        child: PracticeContent(),
      ),
      const PlaceholderPage(
        title: 'Meus Resultados',
        message: 'Consulta o teu histórico de atividades e pontuações.',
        icon: Icons.emoji_events_outlined,
        child: ResultsContent(),
      ),
      const PlaceholderPage(
        title: 'Análises',
        message:
            'Consulta métricas de aprendizagem e acompanhamento pedagógico.',
        icon: Icons.bar_chart,
        child: AnalyticsContent(),
      ),
      const PlaceholderPage(
        title: 'Ajustes',
        message: 'Configura a aplicação e acede a opções secundárias.',
        icon: Icons.settings,
        child: SettingsContent(),
      ),
    ];
  }

  /// Atualiza a aba selecionada.
  ///
  /// Quando o utilizador toca em "Praticar", a aplicação abre aleatoriamente
  /// uma das atividades principais do DailyTalk.pt: Vocabulário, Diálogo ou Quiz.
  /// Esta decisão reforça a lógica gamificada, evitando que o botão funcione
  /// apenas como uma página estática intermédia.
  Future<void> _onItemTapped(int index) async {
    if (index == 1) {
      await _openRandomPracticeActivity();
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  /// Abre uma atividade prática de forma aleatória.
  Future<void> _openRandomPracticeActivity() async {
    final List<Widget> practiceActivities = <Widget>[
      const VocabularyPairsPage(),
      const DialoguePage(),
      const QuizPage(),
    ];

    final Widget selectedActivity =
        practiceActivities[_random.nextInt(practiceActivities.length)];

    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => selectedActivity));
  }

  @override
  Widget build(BuildContext context) {
    final pages = _buildPages(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B22),

      // Mantém cada página viva e apenas alterna qual delas fica visível.
      body: IndexedStack(index: _selectedIndex, children: pages),

      // Rodapé principal da aplicação.
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF111C22),
        selectedItemColor: Colors.lightBlue,
        unselectedItemColor: Colors.white70,
        onTap: _onItemTapped,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home),
            label: context.tr('Home'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.play_circle_outline),
            label: context.tr('Praticar'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.emoji_events_outlined),
            label: context.tr('Resultados'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.bar_chart),
            label: context.tr('Análises'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings),
            label: context.tr('Ajustes'),
          ),
        ],
      ),
    );
  }
}
