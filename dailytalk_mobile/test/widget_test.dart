import 'package:flutter_test/flutter_test.dart';
import 'package:dailytalk_mobile/main.dart';

void main() {
  testWidgets('Mostra a tela inicial gamificada do DailyTalk', (WidgetTester tester) async {
    // Carrega a aplicação principal no ambiente de teste.
    await tester.pumpWidget(const DailyTalkApp());

    // Verifica se o nome da aplicação aparece.
    expect(find.text('DailyTalk.pt'), findsWidgets);

    // Verifica se o título da unidade aparece.
    expect(find.text('UNIDADE 5'), findsOneWidget);

    // Verifica se o tema atual aparece.
    expect(find.text('Tema: Comunicação e amizades'), findsOneWidget);
  });
}