import 'package:dailytalk_mobile/presentation/learning_path/learning_map_home_host.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldUseLearningMapHome', () {
    test('accepts authenticated account when feature is enabled', () {
      expect(
        shouldUseLearningMapHome(
          featureEnabled: true,
          isAuthenticated: true,
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
          accountId: 'account-1',
        ),
        isFalse,
      );
    });

    test('fails closed without a stable account id', () {
      expect(
        shouldUseLearningMapHome(
          featureEnabled: true,
          isAuthenticated: true,
          accountId: '   ',
        ),
        isFalse,
      );

      expect(
        shouldUseLearningMapHome(
          featureEnabled: true,
          isAuthenticated: true,
          accountId: null,
        ),
        isFalse,
      );
    });
  });
}
