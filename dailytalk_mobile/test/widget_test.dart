import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dailytalk_mobile/screens/login_page.dart';
import 'package:dailytalk_mobile/state/app_session_controller.dart';

/// Cria um ambiente mínimo de teste para o ecrã inicial.
///
/// Evita usar o DailyTalkApp/AuthGate diretamente, porque o AuthGate valida a
/// sessão guardada de forma assíncrona. Em testes de widget, isso pode manter
/// animações/pedidos pendentes e fazer o pumpAndSettle expirar.
Widget _buildTestApp() {
  return AppSessionScope(
    controller: AppSessionController.instance,
    child: MaterialApp(
      title: 'DailyTalk.pt',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: LoginPage(
        onAuthenticated: () {},
      ),
    ),
  );
}

void main() {
  testWidgets('Mostra o ecrã inicial do DailyTalk', (tester) async {
    await tester.pumpWidget(_buildTestApp());

    // Usa pumps fixos em vez de pumpAndSettle para evitar timeout causado por
    // animações contínuas ou validações assíncronas não relevantes para o teste.
    await tester.pump(const Duration(milliseconds: 300));

    // O primeiro ecrã deixou de ser o formulário de login.
    // Agora apresenta três ações principais sem scroll.
    expect(find.text('Testar agora'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Criar conta'), findsOneWidget);

    // Os campos de autenticação já não aparecem no primeiro ecrã.
    expect(find.text('Email'), findsNothing);
    expect(find.text('Password'), findsNothing);
  });

  testWidgets('Abre o ecrã de autenticação ao tocar em Entrar', (tester) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Entrar'));

    // Avança a animação de navegação sem depender de pumpAndSettle.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    // O formulário de login agora existe num segundo ecrã.
    expect(find.text('Aceder à tua conta'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Esqueci a palavra-passe'), findsOneWidget);
    expect(find.text('Continuar com Google'), findsOneWidget);
  });
}
