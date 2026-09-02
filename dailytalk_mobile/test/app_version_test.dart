import 'dart:io';

import 'package:dailytalk_mobile/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('versão da aplicação coincide com o pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+[0-9]+\s*$',
      multiLine: true,
    ).firstMatch(pubspec);

    expect(match, isNotNull, reason: 'pubspec.yaml deve usar x.y.z+build');
    expect(match!.group(1), AppConfig.appVersion);
  });
}
