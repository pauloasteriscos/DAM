import 'package:flutter_test/flutter_test.dart';
import 'package:dailytalk_mobile/main.dart';

void main() {
  testWidgets('Mostra mensagem de base de dados OK', (WidgetTester tester) async {
    // Cria a aplicação em modo de teste, passando um valor fixo
    // para simular a quantidade de atividades encontradas na base local.
    await tester.pumpWidget(
      const MyApp(activityCount: 1),
    );

    // Verifica se o texto principal aparece no ecrã.
    expect(find.textContaining('Base de dados SQLite OK'), findsOneWidget);

    // Verifica se a quantidade simulada de atividades aparece no ecrã.
    expect(find.textContaining('Atividades locais encontradas: 1'), findsOneWidget);
  });
}