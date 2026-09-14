import 'learning_map_activity_navigation.dart';
import 'learning_map_next_mission.dart';
import 'learning_map_view_model.dart';

typedef LearningMapActivityOpenAction =
    Future<LearningMapActivityNavigationOutcome> Function(
      LearningMapElementViewModel element,
    );

typedef LearningMapReloadAction = Future<LearningMapViewModel> Function();

/// Result of one open -> return -> local refresh cycle.
final class LearningMapMissionFlowResult {
  const LearningMapMissionFlowResult({
    required this.navigationOutcome,
    this.refreshedModel,
    this.nextMission,
  });

  final LearningMapActivityNavigationOutcome navigationOutcome;

  /// Present only after a route was actually opened and returned.
  final LearningMapViewModel? refreshedModel;

  /// Calculated exclusively from [refreshedModel].
  final LearningMapElementViewModel? nextMission;

  bool get returnedFromActivity =>
      navigationOutcome == LearningMapActivityNavigationOutcome.opened &&
      refreshedModel != null;
}

/// Coordinates navigation return with a new local Learning Map read.
///
/// The flow deliberately does not interpret route return as completion.
/// Progress must already have been persisted by the activity/application
/// layer. After return, the map is read again and the next actionable
/// recommendation is selected from that refreshed projection.
final class LearningMapMissionFlow {
  const LearningMapMissionFlow({
    required this.openActivity,
    required this.reloadModel,
  });

  final LearningMapActivityOpenAction openActivity;
  final LearningMapReloadAction reloadModel;

  Future<LearningMapMissionFlowResult> openAndRefreshAfterReturn(
    LearningMapElementViewModel element,
  ) async {
    final navigationOutcome = await openActivity(element);

    if (navigationOutcome != LearningMapActivityNavigationOutcome.opened) {
      return LearningMapMissionFlowResult(navigationOutcome: navigationOutcome);
    }

    final refreshedModel = await reloadModel();

    return LearningMapMissionFlowResult(
      navigationOutcome: navigationOutcome,
      refreshedModel: refreshedModel,
      nextMission: LearningMapNextMission.resolve(refreshedModel),
    );
  }
}
