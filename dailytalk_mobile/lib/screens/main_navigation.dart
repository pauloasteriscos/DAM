import 'package:flutter/material.dart';

import 'activity_config_content.dart';
import 'home_gamificada.dart';
import 'placeholder_page.dart';

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
      title: 'Configuração da Atividade',
      message: 'Aqui será a configuração da nova atividade.',
      icon: Icons.add_circle_outline,
      child: ActivityConfigContent(),
    ),
    PlaceholderPage(
      title: 'Meus Resultados',
      message: 'Aqui será a página de resultados do aluno.',
      icon: Icons.emoji_events_outlined,
    ),
    PlaceholderPage(
      title: 'Análises',
      message: 'Aqui será a página de análises do professor.',
      icon: Icons.bar_chart,
    ),
    PlaceholderPage(
      title: 'Ajustes',
      message: 'Aqui será a página de ajustes da aplicação.',
      icon: Icons.settings,
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
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),

      // Rodapé principal da aplicação.
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF111C22),
        selectedItemColor: Colors.lightBlue,
        unselectedItemColor: Colors.white70,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: 'Atividade',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.emoji_events_outlined),
            label: 'Resultados',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Análises',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }
}