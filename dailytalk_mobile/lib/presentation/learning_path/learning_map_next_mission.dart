import 'learning_map_activity_navigation.dart';
import 'learning_map_view_model.dart';

/// Resolves the next actionable mission from recommendations already
/// calculated by the progression layer.
///
/// This selector never changes availability and never evaluates
/// prerequisites. It only filters the persisted recommendation order by
/// whether the current app can actually open the element.
abstract final class LearningMapNextMission {
  static LearningMapElementViewModel? resolve(LearningMapViewModel model) {
    LearningMapElementViewModel? selected;

    for (final element in model.elements) {
      final rank = element.recommendationRank;

      if (rank == null) {
        continue;
      }

      if (!element.isActivity || !element.canOpen) {
        continue;
      }

      final navigation = LearningMapActivityNavigation.resolve(element);

      if (!navigation.canNavigate) {
        continue;
      }

      final selectedRank = selected?.recommendationRank;

      if (selected == null || selectedRank == null || rank < selectedRank) {
        selected = element;
      }
    }

    return selected;
  }
}
