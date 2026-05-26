import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dailytalk_mobile/main.dart';

void main() {
  setUp(() {
    // Simula armazenamento seguro vazio.
    // Assim o AuthGate entende que não há sessão ativa
    // e deve apresentar a tela de login.
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  testWidgets('Mostra a tela de login do DailyTalk', (tester) async {
    await tester.pumpWidget(const DailyTalkApp());

    // Primeiro build.
    await tester.pump();

    // Dá tempo ao AuthGate para verificar o token mockado.
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.text('Serious game para aprendizagem de idiomas'),
      findsOneWidget,
    );


    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Esqueci a palavra-passe'), findsOneWidget);
    expect(find.text('Entrar'), findsWidgets);
    expect(find.text('Criar conta'), findsOneWidget);
  });

  testWidgets('Abre a tela de criação de conta', (tester) async {
    await tester.pumpWidget(const DailyTalkApp());

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final createAccountButton = find.widgetWithText(
      OutlinedButton,
      'Criar conta',
    );

    expect(createAccountButton, findsOneWidget);

    // Garante que o botão está visível antes do clique.
    // No teste, a janela padrão é pequena e o botão pode ficar abaixo da área visível.
    await tester.ensureVisible(createAccountButton);
    await tester.pumpAndSettle();

    await tester.tap(createAccountButton);
    await tester.pumpAndSettle();

  
  });
}