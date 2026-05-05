import 'package:flutter/material.dart';

import 'analytics_content.dart';
import 'home_gamificada.dart';
import 'placeholder_page.dart';
import 'practice_content.dart';
import 'results_content.dart';
import 'settings_content.dart';

/// Tela principal da aplicação.
///
/// Esta classe controla a navegação inferior da app.
/// Cada item do rodapé abre uma página diferente.
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  /// Índice atualmente selecionado no menu inferior.
  int _selectedIndex = 0;

  /// Lista das páginas associadas ao menu inferior.
  ///
  /// O IndexedStack mantém o estado das páginas ao trocar de aba.
  final List<Widget> _pages = const [
    HomeGamificada(),
    PlaceholderPage(
      title: 'Praticar',
      message:
          'Responde a atividades predefinidas e melhora a tua comunicação.',
      icon: Icons.play_circle_outline,
      child: PracticeContent(),
    ),
    PlaceholderPage(
      title: 'Meus Resultados',
      message: 'Consulta o teu histórico de atividades e pontuações.',
      icon: Icons.emoji_events_outlined,
      child: ResultsContent(),
    ),
    PlaceholderPage(
      title: 'Análises',
      message: 'Consulta métricas de aprendizagem e acompanhamento pedagógico.',
      icon: Icons.bar_chart,
      child: AnalyticsContent(),
    ),
    PlaceholderPage(
      title: 'Ajustes',
      message: 'Configura a aplicação e acede a opções secundárias.',
      icon: Icons.settings,
      child: SettingsContent(),
    ),
  ];

  /// Atualiza a aba selecionada.
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B22),

      // Mantém cada página viva e apenas alterna qual delas fica visível.
      body: IndexedStack(index: _selectedIndex, children: _pages),

      // Rodapé principal da aplicação.
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF111C22),
        selectedItemColor: Colors.lightBlue,
        unselectedItemColor: Colors.white70,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.play_circle_outline),
            label: 'Praticar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.emoji_events_outlined),
            label: 'Resultados',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Análises',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Ajustes'),
        ],
      ),
    );
  }
}
