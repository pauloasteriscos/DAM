enum FeatureFlag {
  remoteContentCatalog,
  progressionEngineV2,
  dynamicLearningMap,
  communityActivities,
}

class FeatureFlagSnapshot {
  const FeatureFlagSnapshot({
    required this.remoteContentCatalog,
    required this.progressionEngineV2,
    required this.dynamicLearningMap,
    required this.communityActivities,
  });

  final bool remoteContentCatalog;
  final bool progressionEngineV2;
  final bool dynamicLearningMap;
  final bool communityActivities;

  bool raw(FeatureFlag flag) {
    return switch (flag) {
      FeatureFlag.remoteContentCatalog => remoteContentCatalog,
      FeatureFlag.progressionEngineV2 => progressionEngineV2,
      FeatureFlag.dynamicLearningMap => dynamicLearningMap,
      FeatureFlag.communityActivities => communityActivities,
    };
  }

  bool isEnabled(FeatureFlag flag) {
    return switch (flag) {
      FeatureFlag.remoteContentCatalog => remoteContentCatalog,
      FeatureFlag.progressionEngineV2 => progressionEngineV2,
      FeatureFlag.dynamicLearningMap =>
        dynamicLearningMap &&
            remoteContentCatalog &&
            progressionEngineV2,
      FeatureFlag.communityActivities => communityActivities,
    };
  }

  Set<FeatureFlag> get enabled => {
        for (final flag in FeatureFlag.values)
          if (isEnabled(flag)) flag,
      };
}

abstract final class FeatureFlags {
  static const FeatureFlagSnapshot build = FeatureFlagSnapshot(
    remoteContentCatalog: bool.fromEnvironment(
      'DAILYTALK_FEATURE_REMOTE_CONTENT_CATALOG',
      defaultValue: false,
    ),
    progressionEngineV2: bool.fromEnvironment(
      'DAILYTALK_FEATURE_PROGRESSION_ENGINE_V2',
      defaultValue: false,
    ),
    dynamicLearningMap: bool.fromEnvironment(
      'DAILYTALK_FEATURE_DYNAMIC_LEARNING_MAP',
      defaultValue: false,
    ),
    communityActivities: bool.fromEnvironment(
      'DAILYTALK_FEATURE_COMMUNITY_ACTIVITIES',
      defaultValue: false,
    ),
  );

  static bool isEnabled(FeatureFlag flag) => build.isEnabled(flag);
}
