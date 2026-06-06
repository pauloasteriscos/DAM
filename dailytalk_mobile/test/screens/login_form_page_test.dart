import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dailytalk_mobile/screens/login_form_page.dart';
import 'package:dailytalk_mobile/state/app_locale_controller.dart';
import 'package:dailytalk_mobile/state/app_session_controller.dart';

Widget _buildLoginFormPage() {
  return AppLocaleScope(
    controller: AppLocaleController.instance,
    child: AppSessionScope(
      controller: AppSessionController.instance,
      child: MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginFormPage(
        onAuthenticated: () {},
      ),
      ),
    ),
  );
}

void main() {
  testWidgets('Mostra autenticação tradicional e opção Google futura',
      (tester) async {
    await tester.pumpWidget(_buildLoginFormPage());
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Aceder à tua conta'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Esqueci a palavra-passe'), findsOneWidget);
    expect(find.text('Continuar com Google'), findsOneWidget);
    expect(find.text('Ainda não tem conta? Criar conta'), findsOneWidget);
  });

  testWidgets('Google Account mostra mensagem de funcionalidade futura',
      (tester) async {
    await tester.pumpWidget(_buildLoginFormPage());
    await tester.pump(const Duration(milliseconds: 300));

    final googleButton = find.text('Continuar com Google');
    await tester.ensureVisible(googleButton);
    await tester.pump(const Duration(milliseconds: 150));

    await tester.tap(googleButton);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Integração futura'), findsOneWidget);
    expect(find.textContaining('Nesta versão de protótipo'), findsOneWidget);
    expect(find.text('Compreendi'), findsOneWidget);
  });
}
