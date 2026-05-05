import 'package:flutter_test/flutter_test.dart';
import 'package:dailytalk_mobile/main.dart';

void main() {
  testWidgets('Mostra a tela inicial gamificada do DailyTalk', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DailyTalkApp());

    expect(find.text('DailyTalk.pt'), findsOneWidget);
    expect(find.text('UNIDADE 5'), findsOneWidget);
    expect(find.text('Tema: Comunicação e amizades'), findsOneWidget);
  });

  testWidgets('Navega para a página Praticar', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DailyTalkApp());

    await tester.tap(find.text('Praticar'));
    await tester.pumpAndSettle();

    expect(find.text('Praticar'), findsWidgets);
    expect(find.textContaining('Como perguntarias'), findsOneWidget);
    expect(find.text('Submeter resposta'), findsOneWidget);
  });
}