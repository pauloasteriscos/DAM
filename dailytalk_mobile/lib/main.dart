import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'config/feature_flags.dart';
import 'data/content/learning_content_assets.dart';
import 'data/content/learning_content_bootstrap.dart';
import 'data/content/official_learning_path_resolver.dart';
import 'data/database/database_factory_config.dart';
import 'data/services/learning_progress_startup_reconciliation_service.dart';
import 'screens/auth_gate.dart';
import 'state/app_learning_language_controller.dart';
import 'state/app_locale_controller.dart';
import 'state/app_session_controller.dart';

/// Ponto de entrada da aplicação DailyTalk.pt.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configura a base de dados conforme a plataforma atual.
  await configureDatabaseFactory();

  // Lê os idiomas guardados antes de construir o primeiro ecrã. Desta forma,
  // a UI e o percurso oficial arrancam já com a preferência persistida.
  await AppLocaleController.instance.initialize();
  await AppLearningLanguageController.instance.initialize();

  // A primeira execução prepara o pacote oficial correspondente ao idioma de
  // aprendizagem sem depender da rede. Uma falha de conteúdo não impede
  // autenticação/diagnóstico da aplicação.
  try {
    await LearningContentBootstrapService.instance.ensureLocalBaseline(
      learningLanguageCode:
          AppLearningLanguageController.instance.languageCode,
    );
  } catch (error, stackTrace) {
    debugPrint('Falha ao preparar conteúdo oficial local: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  runApp(const DailyTalkApp());

  // Fase 3.5C:
  //
  // começa a observar a sessão SEM bloquear o primeiro frame.
  // Quando a sessão ficar autenticada, o mesmo Secure Sync usado pela
  // outbox executará push + pull. Outbox vazia continua a gerar pull.
  LearningProgressStartupReconciliationService.instance.start();

  // A atualização remota é deliberadamente posterior ao primeiro frame e
  // controlada por feature flag. A aprendizagem continua sobre SQLite.
  if (FeatureFlags.isEnabled(FeatureFlag.remoteContentCatalog)) {
    unawaited(_refreshOfficialContentInBackground());
  }
}

Future<void> _refreshOfficialContentInBackground() async {
  final learningLanguageCode =
      AppLearningLanguageController.instance.languageCode;
  final descriptor = OfficialLearningPathResolver.resolve(
    learningLanguageCode,
  );

  try {
    await LearningContentBootstrapService.instance.refreshOfficialContent(
      learningLanguageCode: learningLanguageCode,
    );
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
      descriptor.learningPathId,
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
