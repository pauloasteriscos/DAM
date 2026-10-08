import 'package:flutter_test/flutter_test.dart';

import 'package:dailytalk_mobile/state/app_session_controller.dart';

void main() {
  group('AppSessionController', () {
    test('startTestMode ativa o modo teste e notifica observadores', () {
      final controller = AppSessionController.instance;
      var notifications = 0;

      void listener() {
        notifications++;
      }

      controller.addListener(listener);
      controller.startTestMode();
      controller.removeListener(listener);

      expect(controller.status, AppSessionStatus.testMode);
      expect(controller.isTestMode, isTrue);
      expect(controller.isAuthenticated, isFalse);
      expect(controller.currentUser, isNull);
      expect(controller.learningProgressAccountId, isNotNull);
      expect(
        controller.learningProgressAccountId,
        startsWith('guest-session:'),
      );
      expect(notifications, greaterThanOrEqualTo(1));
    });

    test('novo modo teste recebe novo identificador efémero', () {
      final controller = AppSessionController.instance;

      controller.startTestMode();
      final first = controller.learningProgressAccountId;

      controller.startTestMode();
      final second = controller.learningProgressAccountId;

      expect(first, isNotNull);
      expect(second, isNotNull);
      expect(second, isNot(first));
    });

    test('markAuthenticated troca modo teste por sessão autenticada', () {
      final controller = AppSessionController.instance;

      controller.startTestMode();
      controller.markAuthenticated();

      expect(controller.status, AppSessionStatus.authenticated);
      expect(controller.isAuthenticated, isTrue);
      expect(controller.isTestMode, isFalse);
      expect(controller.learningProgressAccountId, isNull);
    });
  });
}
