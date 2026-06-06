import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dailytalk_mobile/screens/home_gamificada.dart';
import 'package:dailytalk_mobile/state/app_locale_controller.dart';
import 'package:dailytalk_mobile/state/app_session_controller.dart';

Widget _buildHome({required bool isTestMode}) {
  return AppLocaleScope(
    controller: AppLocaleController.instance,
    child: AppSessionScope(
      controller: AppSessionController.instance,
      child: MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: HomeGamificada(
          isTestMode: isTestMode,
          onAuthenticated: () {},
        ),
      ),
      ),
    ),
  );
}

void main() {
  testWidgets('Home em modo teste mostra aviso compacto e CTA Entrar',
      (tester) async {
    await tester.pumpWidget(_buildHome(isTestMode: true));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('DailyTalk.pt'), findsOneWidget);
    expect(find.text('Modo teste · progresso não guardado'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('MAPA DE ATIVIDADES'), findsOneWidget);
  });

  testWidgets('Home autenticada não mostra aviso de modo teste', (tester) async {
    await tester.pumpWidget(_buildHome(isTestMode: false));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('DailyTalk.pt'), findsOneWidget);
    expect(find.text('Modo teste · progresso não guardado'), findsNothing);
    expect(find.text('MAPA DE ATIVIDADES'), findsOneWidget);
  });

  testWidgets('Home em landscape compacto não gera exceção de layout',
      (tester) async {
    tester.view.physicalSize = const Size(900, 420);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildHome(isTestMode: true));
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.text('DailyTalk.pt'), findsOneWidget);
    expect(find.text('Modo teste · progresso não guardado'), findsOneWidget);
  });
}
