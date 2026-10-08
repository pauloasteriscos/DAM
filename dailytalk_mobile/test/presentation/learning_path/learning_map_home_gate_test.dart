import 'package:dailytalk_mobile/presentation/learning_path/learning_map_home_host.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldUseLearningMapHome', () {
    test('accepts authenticated account when feature is enabled', () {
      expect(
        shouldUseLearningMapHome(
          featureEnabled: true,
          isAuthenticated: true,
          isTestMode: false,
          accountId: 'account-1',
        ),
        isTrue,
      );
    });

    test('fails closed when feature is disabled', () {
      expect(
        shouldUseLearningMapHome(
          featureEnabled: false,
          isAuthenticated: true,
          isTestMode: false,
          accountId: 'account-1',
        ),
        isFalse,
      );
    });

    test('fails closed when session is not authenticated', () {
      expect(
        shouldUseLearningMapHome(
          featureEnabled: true,
          isAuthenticated: false,
          isTestMode: false,
          accountId: 'account-1',
        ),
        isFalse,
      );
    });

    test('accepts test mode with ephemeral local progress id', () {
      expect(
        shouldUseLearningMapHome(
          featureEnabled: true,
          isAuthenticated: false,
          isTestMode: true,
          accountId: 'guest-session:123:1',
        ),
        isTrue,
      );
    });

    test('fails closed for unauthenticated non-test session', () {
      expect(
        shouldUseLearningMapHome(
          featureEnabled: true,
          isAuthenticated: false,
          isTestMode: false,
          accountId: 'guest-session:123:1',
        ),
        isFalse,
      );
    });

    test('fails closed without a stable account id', () {
      expect(
        shouldUseLearningMapHome(
          featureEnabled: true,
          isAuthenticated: true,
          isTestMode: false,
          accountId: '   ',
        ),
        isFalse,
      );

      expect(
        shouldUseLearningMapHome(
          featureEnabled: true,
          isAuthenticated: true,
          isTestMode: false,
          accountId: null,
        ),
        isFalse,
      );
    });
  });

  group('LearningMapPracticeController', () {
    test('fails closed while no Learning Map host is attached', () async {
      final controller = LearningMapPracticeController();

      expect(controller.isReady, isFalse);
      expect(await controller.openRecommendedActivity(), isFalse);
    });

    test('delegates to current Learning Map practice action', () async {
      final controller = LearningMapPracticeController();
      var calls = 0;

      final owner = Object();

      controller.attach(owner, () async {
        calls += 1;
        return true;
      });

      expect(controller.isReady, isTrue);
      expect(await controller.openRecommendedActivity(), isTrue);
      expect(calls, 1);
    });

    test('detach prevents stale Learning Map practice navigation', () async {
      final controller = LearningMapPracticeController();
      var calls = 0;

      final owner = Object();

      controller.attach(owner, () async {
        calls += 1;
        return true;
      });
      controller.detach(owner);

      expect(controller.isReady, isFalse);
      expect(await controller.openRecommendedActivity(), isFalse);
      expect(calls, 0);
    });
    test('stale host cannot detach a newer practice action', () async {
      final controller = LearningMapPracticeController();
      final oldOwner = Object();
      final newOwner = Object();
      var calls = 0;

      controller.attach(oldOwner, () async => false);
      controller.attach(newOwner, () async {
        calls += 1;
        return true;
      });

      controller.detach(oldOwner);

      expect(controller.isReady, isTrue);
      expect(await controller.openRecommendedActivity(), isTrue);
      expect(calls, 1);
    });
  });
}
