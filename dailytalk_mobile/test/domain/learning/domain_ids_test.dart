import 'package:dailytalk_mobile/domain/learning/learning_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DomainId', () {
    test('aceita identificadores estáveis no formato definido', () {
      final id = ActivityId('arrival.greetings-01');

      expect(id.value, 'arrival.greetings-01');
      expect(id.toString(), 'arrival.greetings-01');
    });

    test('compara valor e tipo do identificador', () {
      expect(ActivityId('greeting-01'), ActivityId('greeting-01'));
      expect(
        ActivityId('greeting-01'),
        isNot(equals(CompetencyId('greeting-01'))),
      );
    });

    test('rejeita vazio, espaços e letras maiúsculas', () {
      expect(() => ActivityId(''), throwsArgumentError);
      expect(() => ActivityId('arrival greeting'), throwsArgumentError);
      expect(() => ActivityId('Arrival-Greeting'), throwsArgumentError);
    });
  });
}
