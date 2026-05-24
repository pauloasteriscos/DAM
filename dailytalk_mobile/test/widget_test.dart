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

    expect(find.text('DailyTalk.pt'), findsOneWidget);
    expect(find.text('Entrar'), findsWidgets);
    expect(find.text('Ainda não tenho conta'), findsOneWidget);
  });

  testWidgets('Abre a tela de criação de conta', (tester) async {
    await tester.pumpWidget(const DailyTalkApp());

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final createAccountButton = find.text('Ainda não tenho conta');

    expect(createAccountButton, findsOneWidget);

    await tester.tap(createAccountButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Criar conta'), findsWidgets);
    expect(find.text('Criar perfil DailyTalk.pt'), findsOneWidget);
  });
}