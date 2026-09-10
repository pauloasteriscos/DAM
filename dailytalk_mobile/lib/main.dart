import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'config/feature_flags.dart';
import 'data/content/learning_content_assets.dart';
import 'data/content/learning_content_bootstrap.dart';
import 'data/database/database_factory_config.dart';
import 'screens/auth_gate.dart';
import 'state/app_locale_controller.dart';
import 'state/app_session_controller.dart';

/// Ponto de entrada da aplicação DailyTalk.pt.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configura a base de dados conforme a plataforma atual.
  await configureDatabaseFactory();

  // A primeira execução prepara o pacote oficial local sem depender da rede.
  // Uma falha de conteúdo não impede autenticação/diagnóstico da aplicação.
  try {
    await LearningContentBootstrapService.instance.ensureLocalBaseline();
  } catch (error, stackTrace) {
    debugPrint('Falha ao preparar conteúdo oficial local: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  // Lê o idioma guardado antes de construir o primeiro ecrã. Desta forma, a
  // aplicação não apresenta primeiro português e só depois muda de idioma.
  await AppLocaleController.instance.initialize();

  runApp(const DailyTalkApp());

  // A atualização remota é deliberadamente posterior ao primeiro frame e
  // controlada por feature flag. A aprendizagem continua sobre SQLite.
  if (FeatureFlags.isEnabled(FeatureFlag.remoteContentCatalog)) {
    unawaited(_refreshOfficialContentInBackground());
  }
}

Future<void> _refreshOfficialContentInBackground() async {
  try {
    await LearningContentBootstrapService.instance.refreshOfficialContent();
  } catch (error, stackTrace) {
    // Falha transitória de rede/conteúdo nunca elimina a última versão local.
    debugPrint('Atualização de conteúdo oficial adiada: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  if (!FeatureFlags.isEnabled(FeatureFlag.remoteContentAssets)) {
    return;
  }

  try {
    await LearningContentAssetService.instance.refreshActiveAssets(
      LearningContentBootstrapService.officialLearningPathId,
    );
  } catch (error, stackTrace) {
    // Assets são enriquecimento: a atividade textual permanece utilizável e
    // qualquer cache válido anterior fica preservado.
    debugPrint('Atualização de assets oficiais adiada: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
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
