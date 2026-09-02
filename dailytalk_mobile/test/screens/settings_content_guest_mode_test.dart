import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dailytalk_mobile/config/app_config.dart';
import 'package:dailytalk_mobile/screens/settings_content.dart';
import 'package:dailytalk_mobile/state/app_locale_controller.dart';
import 'package:dailytalk_mobile/state/app_session_controller.dart';

Widget _buildSettingsInTestMode() {
  AppSessionController.instance.startTestMode();

  return AppLocaleScope(
    controller: AppLocaleController.instance,
    child: AppSessionScope(
      controller: AppSessionController.instance,
      child: const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Color(0xFF0D1B22),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: SettingsContent(),
          ),
        ),
      ),
      ),
    ),
  );
}

void main() {
  testWidgets('Ajustes em modo teste distingue preferências locais e conta',
      (tester) async {
    await tester.pumpWidget(_buildSettingsInTestMode());
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Modo teste ativo'), findsOneWidget);
    expect(find.text('Conta'), findsOneWidget);
    expect(find.text('Perfil'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Sincronizar'), findsOneWidget);
    expect(find.textContaining('Alterar idiomas localmente'), findsOneWidget);
    expect(find.textContaining('Escolher perfil localmente'), findsOneWidget);
    expect(find.textContaining('Entra para sincronizar'), findsOneWidget);
  });

  testWidgets('Funcionalidade protegida mostra diálogo de conta necessária',
      (tester) async {
    await tester.pumpWidget(_buildSettingsInTestMode());
    await tester.pump(const Duration(milliseconds: 300));

    final createActivity = find.text('Criar atividade');
    await tester.ensureVisible(createActivity);
    await tester.pump(const Duration(milliseconds: 150));

    await tester.tap(createActivity);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Conta necessária'), findsOneWidget);
    expect(find.textContaining('precisa de conta'), findsOneWidget);
    expect(find.text('Continuar a testar'), findsOneWidget);
    expect(find.text('Criar conta'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });

  testWidgets('Sobre apresenta a versão atual da aplicação', (tester) async {
    await tester.pumpWidget(_buildSettingsInTestMode());
    await tester.pump(const Duration(milliseconds: 300));

    final about = find.text('Sobre');
    await tester.ensureVisible(about);
    await tester.pump(const Duration(milliseconds: 150));

    await tester.tap(about);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Sobre o DailyTalk.pt'), findsOneWidget);
    expect(find.text('Versão ${AppConfig.appVersion}'), findsOneWidget);
  });
}
