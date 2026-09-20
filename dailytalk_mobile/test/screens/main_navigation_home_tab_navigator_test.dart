import 'package:dailytalk_mobile/screens/main_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Home nested navigation keeps the parent bottom bar visible', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeTabNavigator(
            navigatorKey: navigatorKey,
            child: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  key: const ValueKey<String>('open-mission'),
                  onPressed: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const Scaffold(
                          body: Center(child: Text('DETALHE DA MISSÃO')),
                        ),
                      ),
                    );
                  },
                  child: const Text('Abrir missão'),
                ),
              ),
            ),
          ),
          bottomNavigationBar: const SizedBox(
            key: ValueKey<String>('fixed-footer'),
            height: 64,
            child: Text('Home · Praticar · Resultados · Análises · Ajustes'),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey<String>('fixed-footer')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('open-mission')));
    await tester.pumpAndSettle();

    expect(find.text('DETALHE DA MISSÃO'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('fixed-footer')), findsOneWidget);

    navigatorKey.currentState!.popUntil((route) => route.isFirst);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('open-mission')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('fixed-footer')), findsOneWidget);
  });
}
