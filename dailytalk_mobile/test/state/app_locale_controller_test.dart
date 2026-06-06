import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dailytalk_mobile/l10n/app_localizations.dart';
import 'package:dailytalk_mobile/state/app_locale_controller.dart';

Widget _buildLocalizedProbe(AppLocaleController controller) {
  return AppLocaleScope(
    controller: controller,
    child: const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Column(
          children: <Widget>[
            AppText('Entrar'),
            AppText('Language'),
            AppText('Idioma da aplicação'),
          ],
        ),
      ),
    ),
  );
}

void main() {
  test('traduz textos parametrizados e mantém Language inalterado', () {
    expect(AppTranslations.translate('Entrar', 'en-US'), 'Sign in');
    expect(AppTranslations.translate('Entrar', 'es-ES'), 'Iniciar sesión');
    expect(AppTranslations.translate('Language', 'fr-FR'), 'Language');
    expect(
      AppTranslations.translate(
        'Guardado: {source} → {target}',
        'de-DE',
        parameters: const <String, Object?>{
          'source': 'Portugiesisch',
          'target': 'Italienisch',
        },
      ),
      'Gespeichert: Portugiesisch → Italienisch',
    );
  });

  testWidgets('a interface reage imediatamente à mudança de idioma',
      (WidgetTester tester) async {
    final controller = AppLocaleController.instance;
    await controller.setLanguageCode('pt-PT');

    await tester.pumpWidget(_buildLocalizedProbe(controller));
    await tester.pump();

    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Idioma da aplicação'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);

    await controller.setLanguageCode('en-US');
    await tester.pump();

    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Application language'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);

    // Repõe o idioma base para não influenciar os restantes testes que usam
    // o singleton global.
    await controller.setLanguageCode('pt-PT');
    await tester.pump();
  });
}
