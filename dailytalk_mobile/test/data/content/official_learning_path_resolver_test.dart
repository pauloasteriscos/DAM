import 'package:dailytalk_mobile/data/content/official_learning_path_resolver.dart';
import 'package:dailytalk_mobile/state/app_learning_language_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('seletor e resolvedor expõem o mesmo conjunto de idiomas', () {
    expect(
      supportedLearningLanguageCodes,
      OfficialLearningPathResolver.supportedLearningLanguageCodes,
    );
  });

  test('resolve os seis idiomas suportados para percursos distintos', () {
    const expected = <String, String>{
      'pt-PT': 'student.pt-pt.phase1',
      'en-US': 'student.en-us.phase1',
      'es-ES': 'student.es-es.phase1',
      'fr-FR': 'student.fr-fr.phase1',
      'it-IT': 'student.it-it.phase1',
      'de-DE': 'student.de-de.phase1',
    };

    for (final entry in expected.entries) {
      final descriptor = OfficialLearningPathResolver.resolve(entry.key);
      expect(descriptor.learningLanguageCode, entry.key);
      expect(descriptor.learningPathId, entry.value);
      expect(descriptor.baselineAssetPath, startsWith('assets/content/'));
      expect(descriptor.baselinePackageVersion, greaterThanOrEqualTo(1));
      expect(descriptor.baselineSha256, hasLength(64));
    }

    expect(
      expected.values.toSet(),
      hasLength(OfficialLearningPathResolver.supportedLearningLanguageCodes.length),
    );
  });

  test('normaliza variantes regionais conhecidas sem adivinhar idioma inválido', () {
    expect(
      OfficialLearningPathResolver.normalizeSupportedLanguageCode('it_IT'),
      'it-IT',
    );
    expect(
      OfficialLearningPathResolver.normalizeSupportedLanguageCode('FR'),
      'fr-FR',
    );
    expect(
      OfficialLearningPathResolver.normalizeSupportedLanguageCode(' en-us '),
      'en-US',
    );
    expect(
      OfficialLearningPathResolver.normalizeSupportedLanguageCode('xx-XX'),
      isNull,
    );
  });

  test('falha fechado para idioma sem percurso oficial', () {
    expect(
      () => OfficialLearningPathResolver.resolve('xx-XX'),
      throwsA(isA<UnsupportedError>()),
    );
  });
}
