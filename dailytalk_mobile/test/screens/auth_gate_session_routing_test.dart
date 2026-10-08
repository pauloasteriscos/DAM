import 'package:dailytalk_mobile/screens/auth_gate.dart';
import 'package:dailytalk_mobile/state/app_session_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthGate session routing policy', () {
    test('testMode usa a mesma MainNavigation da sessão autenticada', () {
      expect(
        shouldShowMainNavigationForSession(AppSessionStatus.testMode),
        isTrue,
      );
      expect(
        shouldShowMainNavigationForSession(AppSessionStatus.authenticated),
        isTrue,
      );
    });

    test('logout/sem sessão regressa ao ecrã de entrada', () {
      expect(
        shouldShowMainNavigationForSession(AppSessionStatus.unauthenticated),
        isFalse,
      );
      expect(
        shouldShowMainNavigationForSession(AppSessionStatus.checking),
        isFalse,
      );
    });
  });
}
