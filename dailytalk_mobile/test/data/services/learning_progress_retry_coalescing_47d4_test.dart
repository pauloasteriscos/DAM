import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dailytalk_mobile/data/services/learning_progress_startup_reconciliation_service.dart';

void main() {
  test(
    '4.7D4 - retry solicitado durante execução ativa é reproduzido depois',
    () async {
      final sessionSignal = ChangeNotifier();
      final firstResolveStarted = Completer<void>();
      final firstResolveGate = Completer<String?>();
      final secondResolveStarted = Completer<void>();

      var resolveCalls = 0;

      final service = LearningProgressStartupReconciliationService(
        sessionListenable: sessionSignal,
        isAuthenticated: () => true,
        resolveAccountId: () {
          resolveCalls += 1;

          if (resolveCalls == 1) {
            if (!firstResolveStarted.isCompleted) {
              firstResolveStarted.complete();
            }

            return firstResolveGate.future;
          }

          if (!secondResolveStarted.isCompleted) {
            secondResolveStarted.complete();
          }

          // Null termina a passagem de forma normal antes de DB/API.
          return Future<String?>.value(null);
        },
        loadContext: () async {
          throw StateError('loadContext não deve ser alcançado');
        },
        loadDatabase: () async {
          throw StateError('DB não deve ser alcançada');
        },
        createApiService: () {
          throw StateError('API não deve ser alcançada');
        },
        notifySyncCompleted: () {},
      );

      addTearDown(() {
        service.stop();
        sessionSignal.dispose();
      });

      service.start();

      await firstResolveStarted.future.timeout(const Duration(seconds: 2));
      expect(resolveCalls, 1);

      // O pedido chega enquanto a primeira execução ainda está suspensa.
      // A 4.7D4 deve preservá-lo para uma segunda passagem.
      service.retryIfAuthenticated();
      expect(resolveCalls, 1);

      // A primeira passagem termina normalmente, sem lançar exceção.
      firstResolveGate.complete(null);

      await secondResolveStarted.future.timeout(const Duration(seconds: 2));
      expect(resolveCalls, 2);

      await service.waitForIdle();
    },
  );
}
