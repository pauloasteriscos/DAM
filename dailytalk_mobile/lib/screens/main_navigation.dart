import 'dart:math';

import 'package:flutter/material.dart';

import '../config/feature_flags.dart';

import '../l10n/app_localizations.dart';

import '../state/app_learning_language_controller.dart';
import '../state/app_locale_controller.dart';
import '../state/app_session_controller.dart';
import 'analytics_content.dart';
import 'vocabulary_pairs_page.dart';
import 'quiz_page.dart';
import 'dialogue_page.dart';
import '../presentation/learning_path/learning_map_home_host.dart';
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
  final GlobalKey<NavigatorState> _homeNavigatorKey =
      GlobalKey<NavigatorState>();

  /// Índice atualmente selecionado no menu inferior.
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    AppLearningLanguageController.instance.addListener(
      _handleLearningLanguageChanged,
    );
  }

  @override
  void dispose() {
    AppLearningLanguageController.instance.removeListener(
      _handleLearningLanguageChanged,
    );
    super.dispose();
  }

  void _handleLearningLanguageChanged() {
    // Uma mudança de idioma invalida qualquer detalhe/runtime aberto no
    // Navigator interno da Home. O utilizador regressa ao mapa e a raiz é
    // reconstruída para carregar o percurso oficial correspondente.
    _resetHomeRoute();

    if (mounted) {
      setState(() {});
    }
  }

  /// Lista das páginas associadas ao menu inferior.
  ///
  /// O IndexedStack mantém o estado das páginas ao trocar de aba.
  List<Widget> _buildPages(BuildContext context) {
    final session = AppSessionScope.watch(context);

    void handleAuthenticated() {
      widget.onAuthenticated?.call();
      AppSessionScope.read(context).markAuthenticated();
    }

    final accountId = session.currentUser?.id.trim();
    final appLanguageCode = AppLocaleController.instance.languageCode;
    final learningLanguageCode =
        AppLearningLanguageController.instance.languageCode;

    final useDynamicLearningMap = shouldUseLearningMapHome(
      featureEnabled: FeatureFlags.isEnabled(FeatureFlag.dynamicLearningMap),
      isAuthenticated: session.isAuthenticated,
      accountId: accountId,
    );

    final Widget Function(Widget footer)? dynamicMapBuilder =
        useDynamicLearningMap
        ? (footer) => LearningMapHomeHost(
            accountId: accountId!,
            key: ValueKey<String>('learning-map-home-$learningLanguageCode'),
            // TARGET segue o idioma praticado. APP/SCAFFOLDING seguem o
            // idioma principal da aplicação, conforme LC-001.
            locale: learningLanguageCode,
            appLanguageCode: appLanguageCode,
            learningLanguageCode: learningLanguageCode,
            footer: footer,
            fallback: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nao foi possivel carregar o percurso.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          )
        : null;

    final Widget homeContent = HomeGamificada(
      isTestMode: session.isTestMode,
      onAuthenticated: handleAuthenticated,
      mapContentBuilder: dynamicMapBuilder,
    );

    // Quando o Learning Path dinâmico está ativo, as rotas de missão vivem
    // dentro da aba Home. Assim, detalhe e runtime substituem apenas o
    // conteúdo da Home e o rodapé principal permanece fixo.
    final Widget home = useDynamicLearningMap
        ? HomeTabNavigator(navigatorKey: _homeNavigatorKey, child: homeContent)
        : homeContent;

    return [
      home,
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
    // Home é sempre o ponto de regresso ao mapa. Se o utilizador estiver no
    // detalhe/runtime de uma missão, fecha a pilha interna antes de trocar.
    if (index == 0) {
      _resetHomeRoute();
      if (mounted) {
        setState(() {
          _selectedIndex = 0;
        });
      }
      return;
    }

    if (_selectedIndex == 0) {
      _resetHomeRoute();
    }

    if (index == 1) {
      await _openRandomPracticeActivity();
      return;
    }

    if (mounted) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  void _resetHomeRoute() {
    final navigator = _homeNavigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.popUntil((route) => route.isFirst);
    }
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

/// Navigator interno da aba Home.
///
/// As missões do Learning Path podem abrir detalhe e runtime sem cobrir o
/// [BottomNavigationBar] pertencente a [MainNavigation]. O widget também
/// mantém o conteúdo raiz atualizável quando sessão/locale mudam.
final class HomeTabNavigator extends StatefulWidget {
  const HomeTabNavigator({required this.child, this.navigatorKey, super.key});

  final Widget child;
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  State<HomeTabNavigator> createState() => _HomeTabNavigatorState();
}

final class _HomeTabNavigatorState extends State<HomeTabNavigator> {
  late final ValueNotifier<Widget> _rootChild;

  @override
  void initState() {
    super.initState();
    _rootChild = ValueNotifier<Widget>(widget.child);
  }

  @override
  void didUpdateWidget(HomeTabNavigator oldWidget) {
    super.didUpdateWidget(oldWidget);
    _rootChild.value = widget.child;
  }

  @override
  void dispose() {
    _rootChild.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: widget.navigatorKey,
      onGenerateRoute: (settings) {
        if (settings.name != Navigator.defaultRouteName) {
          return null;
        }

        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => ValueListenableBuilder<Widget>(
            valueListenable: _rootChild,
            builder: (_, child, _) => child,
          ),
        );
      },
    );
  }
}
