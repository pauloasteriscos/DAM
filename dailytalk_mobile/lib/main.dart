import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/database/database_factory_config.dart';
import 'screens/auth_gate.dart';
import 'state/app_locale_controller.dart';
import 'state/app_session_controller.dart';

/// Ponto de entrada da aplicação DailyTalk.pt.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configura a base de dados conforme a plataforma atual.
  await configureDatabaseFactory();

  // Lê o idioma guardado antes de construir o primeiro ecrã. Desta forma, a
  // aplicação não apresenta primeiro português e só depois muda de idioma.
  await AppLocaleController.instance.initialize();

  runApp(const DailyTalkApp());
}

/// Aplicação principal do DailyTalk.pt.
class DailyTalkApp extends StatelessWidget {
  const DailyTalkApp({super.key});

  @override
  Widget build(BuildContext context) {
    final localeController = AppLocaleController.instance;

    return AppLocaleScope(
      controller: localeController,
      child: AppSessionScope(
        controller: AppSessionController.instance,
        child: AnimatedBuilder(
          animation: localeController,
          builder: (context, child) {
            return MaterialApp(
              title: 'DailyTalk.pt',
              debugShowCheckedModeBanner: false,
              locale: localeController.locale,
              supportedLocales: const <Locale>[
                Locale('pt', 'PT'),
                Locale('en', 'US'),
                Locale('es', 'ES'),
                Locale('fr', 'FR'),
                Locale('it', 'IT'),
                Locale('de', 'DE'),
              ],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
                useMaterial3: true,
              ),
              home: const AuthGate(),
            );
          },
        ),
      ),
    );
  }
}
