import 'package:flutter_test/flutter_test.dart';

import 'package:dailytalk_mobile/navigation/web_entry_action.dart';

void main() {
  group('WebEntryAction.fromUri', () {
    test('reads login', () {
      expect(
        WebEntryAction.fromUri(
          Uri.parse('https://dailytalk.pt/web/?action=login'),
        ),
        WebEntryAction.login,
      );
    });

    test('reads register', () {
      expect(
        WebEntryAction.fromUri(
          Uri.parse('https://dailytalk.pt/web/?action=register'),
        ),
        WebEntryAction.register,
      );
    });

    test('reads test', () {
      expect(
        WebEntryAction.fromUri(
          Uri.parse('https://dailytalk.pt/web/?action=test'),
        ),
        WebEntryAction.test,
      );
    });

    test('is case-insensitive and trims', () {
      expect(
        WebEntryAction.fromUri(
          Uri.parse('https://dailytalk.pt/web/?action=%20TEST%20'),
        ),
        WebEntryAction.test,
      );
    });

    test('returns null without action', () {
      expect(
        WebEntryAction.fromUri(Uri.parse('https://dailytalk.pt/web/')),
        isNull,
      );
    });

    test('returns null for unknown action', () {
      expect(
        WebEntryAction.fromUri(
          Uri.parse('https://dailytalk.pt/web/?action=unknown'),
        ),
        isNull,
      );
    });
  });

  group('WebEntryAction.withoutAction', () {
    test('removes the action query parameter', () {
      expect(
        WebEntryAction.withoutAction(
          Uri.parse('https://dailytalk.pt/web/?action=register'),
        ).toString(),
        'https://dailytalk.pt/web/',
      );
    });

    test('preserves unrelated query parameters', () {
      expect(
        WebEntryAction.withoutAction(
          Uri.parse('https://dailytalk.pt/web/?action=login&source=landing'),
        ).toString(),
        'https://dailytalk.pt/web/?source=landing',
      );
    });
    test('preserves repeated unrelated query parameters', () {
      expect(
        WebEntryAction.withoutAction(
          Uri.parse('https://dailytalk.pt/web/?source=a&action=login&source=b'),
        ).toString(),
        'https://dailytalk.pt/web/?source=a&source=b',
      );
    });

    test('preserves fragment while removing action', () {
      expect(
        WebEntryAction.withoutAction(
          Uri.parse('https://dailytalk.pt/web/?action=register#section'),
        ).toString(),
        'https://dailytalk.pt/web/#section',
      );
    });
  });
}
