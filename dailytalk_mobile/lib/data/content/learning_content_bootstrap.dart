import 'package:flutter/services.dart';

import '../../domain/learning/learning_domain.dart';
import 'learning_content_catalog.dart';
import 'learning_content_import.dart';
import 'learning_content_remote.dart';
import 'official_learning_path_resolver.dart';

/// Bootstrap offline-first do percurso oficial correspondente ao idioma que o
/// utilizador está a praticar.
///
/// A primeira execução garante uma cópia local válida antes de qualquer
/// atualização remota. Atualizações posteriores continuam a ser feitas pela
/// fronteira HTTP da Fase 2.2B.
final class LearningContentBootstrapService {
  LearningContentBootstrapService({
    Future<String> Function(String assetPath)? bundledSourceLoader,
    LearningContentImportService? importService,
    LearningContentCatalogService? catalogService,
    LearningContentRemoteService? remoteService,
  }) : _bundledSourceLoader =
           bundledSourceLoader ?? ((path) => rootBundle.loadString(path)),
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

  final Future<String> Function(String assetPath) _bundledSourceLoader;
  final LearningContentImportService importService;
  final LearningContentCatalogService catalogService;
  late final LearningContentRemoteService remoteService;

  /// Garante que existe conteúdo local ativo para o idioma escolhido sem
  /// depender da rede.
  ///
  /// Nunca faz downgrade: um pacote local válido mais recente que a baseline
  /// embarcada é preservado e, se necessário, reativado.
  Future<ActiveLearningContent> ensureLocalBaseline({
    required String learningLanguageCode,
  }) async {
    final descriptor = OfficialLearningPathResolver.resolve(
      learningLanguageCode,
    );
    final learningPathId = descriptor.learningPathId;

    try {
      final active = await catalogService.loadActive(learningPathId);
      if (active.package.packageVersion >=
          descriptor.baselinePackageVersion) {
        return active;
      }
    } on LearningContentCatalogException catch (error) {
      if (error.code != LearningContentCatalogErrorCode.noActivePackage) {
        rethrow;
      }
    }

    // Se existirem pacotes previamente importados, recuperar primeiro a
    // versão local mais recente que continue válida. Pacotes abaixo da
    // baseline embarcada não impedem a atualização local mínima.
    final localPackages = await importService.repository.listPackages(
      learningPathId,
    );
    for (final package in localPackages.reversed) {
      if (package.packageVersion < descriptor.baselinePackageVersion) {
        break;
      }

      try {
        await importService.validateStoredPackage(package);
        await catalogService.activate(
          learningPathId: learningPathId,
          packageVersion: package.packageVersion,
        );
        return await catalogService.loadActive(learningPathId);
      } on LearningContentImportException {
        // Tenta a versão local anterior; nenhuma linha é apagada.
      } on LearningContentException {
        // Tenta a versão local anterior; nenhuma linha é apagada.
      }
    }

    final payload = await _bundledSourceLoader(descriptor.baselineAssetPath);
    final imported = await importService.importPackage(
      payloadJson: payload,
      packageVersion: descriptor.baselinePackageVersion,
      source: 'bundled:${descriptor.baselineAssetPath}',
      expectedSha256: descriptor.baselineSha256,
    );

    if (imported.path.id.value != learningPathId) {
      throw StateError(
        'Baseline ${descriptor.baselineAssetPath} pertence a '
        '${imported.path.id.value}, não a $learningPathId.',
      );
    }

    await catalogService.activate(
      learningPathId: learningPathId,
      packageVersion: descriptor.baselinePackageVersion,
    );
    return catalogService.loadActive(learningPathId);
  }

  /// Consulta a distribuição oficial para o percurso correspondente ao idioma
  /// escolhido. Deve ser chamada fora do caminho crítico da UI; qualquer
  /// falha deixa a réplica local anterior intacta.
  Future<LearningContentRefreshResult> refreshOfficialContent({
    required String learningLanguageCode,
  }) {
    final descriptor = OfficialLearningPathResolver.resolve(
      learningLanguageCode,
    );
    return remoteService.refreshLearningPath(descriptor.learningPathId);
  }
}
