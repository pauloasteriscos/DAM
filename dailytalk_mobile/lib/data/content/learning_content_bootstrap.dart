import 'package:flutter/services.dart';

import '../../domain/learning/learning_domain.dart';
import 'learning_content_catalog.dart';
import 'learning_content_import.dart';
import 'learning_content_remote.dart';

/// Bootstrap offline-first do percurso oficial atualmente embarcado na app.
///
/// A primeira execução garante uma cópia local válida antes de qualquer
/// atualização remota. Atualizações posteriores continuam a ser feitas pela
/// fronteira HTTP da Fase 2.2B.
final class LearningContentBootstrapService {
  LearningContentBootstrapService({
    Future<String> Function()? bundledSourceLoader,
    LearningContentImportService? importService,
    LearningContentCatalogService? catalogService,
    LearningContentRemoteService? remoteService,
  }) : _bundledSourceLoader =
           bundledSourceLoader ??
           (() => rootBundle.loadString(officialBaselineAssetPath)),
       importService = importService ?? LearningContentImportService(),
       catalogService = catalogService ?? LearningContentCatalogService() {
    this.remoteService =
        remoteService ??
        LearningContentRemoteService(
          importService: this.importService,
          catalogService: this.catalogService,
        );
  }

  static final LearningContentBootstrapService instance =
      LearningContentBootstrapService();

  static const String officialLearningPathId = 'student.fr-fr.phase1';
  static const String officialBaselineAssetPath =
      'assets/content/phase1_example_path.v1.json';
  static const int officialBaselinePackageVersion = 1;
  static const String officialBaselineSha256 =
      '6d5bee9037aecaf70773e484076ad646d6b05d7f01bf0f00b8f5a70e798de968';

  final Future<String> Function() _bundledSourceLoader;
  final LearningContentImportService importService;
  final LearningContentCatalogService catalogService;
  late final LearningContentRemoteService remoteService;

  /// Garante que existe conteúdo local ativo sem depender da rede.
  Future<ActiveLearningContent> ensureLocalBaseline() async {
    try {
      return await catalogService.loadActive(officialLearningPathId);
    } on LearningContentCatalogException catch (error) {
      if (error.code != LearningContentCatalogErrorCode.noActivePackage) {
        rethrow;
      }
    }

    // Se existirem pacotes previamente importados, recuperar primeiro a
    // versão local mais recente que continue válida. Isto evita downgrade
    // apenas porque o ponteiro do catálogo ainda não foi criado.
    final localPackages = await importService.repository.listPackages(
      officialLearningPathId,
    );
    for (final package in localPackages.reversed) {
      try {
        await importService.validateStoredPackage(package);
        await catalogService.activate(
          learningPathId: officialLearningPathId,
          packageVersion: package.packageVersion,
        );
        return await catalogService.loadActive(officialLearningPathId);
      } on LearningContentImportException {
        // Tenta a versão local anterior; nenhuma linha é apagada.
      } on LearningContentException {
        // Tenta a versão local anterior; nenhuma linha é apagada.
      }
    }

    final payload = await _bundledSourceLoader();
    await importService.importPackage(
      payloadJson: payload,
      packageVersion: officialBaselinePackageVersion,
      source: 'bundled:$officialBaselineAssetPath',
      expectedSha256: officialBaselineSha256,
    );
    await catalogService.activate(
      learningPathId: officialLearningPathId,
      packageVersion: officialBaselinePackageVersion,
    );
    return catalogService.loadActive(officialLearningPathId);
  }

  /// Consulta a distribuição oficial. Deve ser chamada fora do caminho
  /// crítico da UI; qualquer falha deixa a réplica local anterior intacta.
  Future<LearningContentRefreshResult> refreshOfficialContent() {
    return remoteService.refreshLearningPath(officialLearningPathId);
  }
}
