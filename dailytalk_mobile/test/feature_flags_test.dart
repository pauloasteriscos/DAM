import 'package:dailytalk_mobile/config/feature_flags.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FeatureFlagSnapshot', () {
    test('todas desligadas produz conjunto efetivo vazio', () {
      const flags = FeatureFlagSnapshot(
        remoteContentCatalog: false,
        remoteContentAssets: false,
        progressionEngineV2: false,
        dynamicLearningMap: false,
        communityActivities: false,
      );

      expect(flags.enabled, isEmpty);
    });

    test('mapa dinâmico falha fechado sem catálogo remoto', () {
      const flags = FeatureFlagSnapshot(
        remoteContentCatalog: false,
        remoteContentAssets: false,
        progressionEngineV2: true,
        dynamicLearningMap: true,
        communityActivities: false,
      );

      expect(flags.raw(FeatureFlag.dynamicLearningMap), isTrue);
      expect(flags.isEnabled(FeatureFlag.dynamicLearningMap), isFalse);
    });

    test('mapa dinâmico falha fechado sem motor de progressão', () {
      const flags = FeatureFlagSnapshot(
        remoteContentCatalog: true,
        remoteContentAssets: false,
        progressionEngineV2: false,
        dynamicLearningMap: true,
        communityActivities: false,
      );

      expect(flags.isEnabled(FeatureFlag.dynamicLearningMap), isFalse);
    });

    test('mapa dinâmico ativa apenas com todas as dependências', () {
      const flags = FeatureFlagSnapshot(
        remoteContentCatalog: true,
        remoteContentAssets: false,
        progressionEngineV2: true,
        dynamicLearningMap: true,
        communityActivities: false,
      );

      expect(flags.isEnabled(FeatureFlag.dynamicLearningMap), isTrue);
    });

    test('assets remotos falham fechados sem catálogo remoto', () {
      const flags = FeatureFlagSnapshot(
        remoteContentCatalog: false,
        remoteContentAssets: true,
        progressionEngineV2: false,
        dynamicLearningMap: false,
        communityActivities: false,
      );

      expect(flags.raw(FeatureFlag.remoteContentAssets), isTrue);
      expect(flags.isEnabled(FeatureFlag.remoteContentAssets), isFalse);
    });

    test('assets remotos ativam quando o catálogo remoto está ativo', () {
      const flags = FeatureFlagSnapshot(
        remoteContentCatalog: true,
        remoteContentAssets: true,
        progressionEngineV2: false,
        dynamicLearningMap: false,
        communityActivities: false,
      );

      expect(flags.isEnabled(FeatureFlag.remoteContentAssets), isTrue);
    });

    test('communityActivities não ativa outras flags', () {
      const flags = FeatureFlagSnapshot(
        remoteContentCatalog: false,
        remoteContentAssets: false,
        progressionEngineV2: false,
        dynamicLearningMap: false,
        communityActivities: true,
      );

      expect(flags.enabled, {FeatureFlag.communityActivities});
    });

    test('enabled devolve somente flags efetivamente disponíveis', () {
      const flags = FeatureFlagSnapshot(
        remoteContentCatalog: true,
        remoteContentAssets: false,
        progressionEngineV2: false,
        dynamicLearningMap: true,
        communityActivities: true,
      );

      expect(flags.enabled, {
        FeatureFlag.remoteContentCatalog,
        FeatureFlag.communityActivities,
      });
    });
  });
}
