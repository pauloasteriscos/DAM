/// Descriptor imutável do percurso oficial associado a um idioma de prática.
final class OfficialLearningPathDescriptor {
  const OfficialLearningPathDescriptor({
    required this.learningLanguageCode,
    required this.learningPathId,
    required this.baselineAssetPath,
    required this.baselinePackageVersion,
    required this.baselineSha256,
  });

  final String learningLanguageCode;
  final String learningPathId;
  final String baselineAssetPath;
  final int baselinePackageVersion;
  final String baselineSha256;
}

/// Resolve explicitamente `learningLanguageCode -> learningPathId`.
///
/// Esta é a única autoridade para selecionar o percurso oficial por idioma.
/// Não faz I/O, não lê preferências e não ativa conteúdo.
abstract final class OfficialLearningPathResolver {
  static const List<String> supportedLearningLanguageCodes = <String>[
    'pt-PT',
    'en-US',
    'es-ES',
    'fr-FR',
    'it-IT',
    'de-DE',
  ];

  static const Map<String, OfficialLearningPathDescriptor> _descriptors =
      <String, OfficialLearningPathDescriptor>{
        'pt-PT': OfficialLearningPathDescriptor(
          learningLanguageCode: 'pt-PT',
          learningPathId: 'student.pt-pt.phase1',
          baselineAssetPath: 'assets/content/official_pt_pt_phase1.v2.json',
          baselinePackageVersion: 2,
          baselineSha256:
              'cece86320a578cf660bf0bb6c6d5ce7f6de60cbf1248bfcc4dc7d3b38c28ebd5',
        ),
        'en-US': OfficialLearningPathDescriptor(
          learningLanguageCode: 'en-US',
          learningPathId: 'student.en-us.phase1',
          baselineAssetPath: 'assets/content/official_en_us_phase1.v2.json',
          baselinePackageVersion: 2,
          baselineSha256:
              'f9b7d8ec84926d149ff1c1a8e7296255e3de716dea77d81a31d68f827048cf45',
        ),
        'es-ES': OfficialLearningPathDescriptor(
          learningLanguageCode: 'es-ES',
          learningPathId: 'student.es-es.phase1',
          baselineAssetPath: 'assets/content/official_es_es_phase1.v2.json',
          baselinePackageVersion: 2,
          baselineSha256:
              'd16bb679fbd0dc6c9d9faf0c88f41ea1070f82f83c3e1e8d43314bd3796c24ae',
        ),
        'fr-FR': OfficialLearningPathDescriptor(
          learningLanguageCode: 'fr-FR',
          learningPathId: 'student.fr-fr.phase1',
          baselineAssetPath: 'assets/content/official_fr_fr_phase1.v6.json',
          baselinePackageVersion: 6,
          baselineSha256:
              '79bde8996567d933ad0ca8111da1004ffa938adfd8229697a11b94311dbef460',
        ),
        'it-IT': OfficialLearningPathDescriptor(
          learningLanguageCode: 'it-IT',
          learningPathId: 'student.it-it.phase1',
          baselineAssetPath: 'assets/content/official_it_it_phase1.v2.json',
          baselinePackageVersion: 2,
          baselineSha256:
              '9a81e76376587e8c3ddfe93054dffc7f40c9d43d0fda841e70f33662fb917f39',
        ),
        'de-DE': OfficialLearningPathDescriptor(
          learningLanguageCode: 'de-DE',
          learningPathId: 'student.de-de.phase1',
          baselineAssetPath: 'assets/content/official_de_de_phase1.v2.json',
          baselinePackageVersion: 2,
          baselineSha256:
              'e4f9a391a135b7b7f72bbd251d03bda9df323a31d668958300786b888c10c05d',
        ),
      };

  static String? normalizeSupportedLanguageCode(String? languageCode) {
    if (languageCode == null || languageCode.trim().isEmpty) {
      return null;
    }

    final normalized = languageCode.trim().replaceAll('_', '-');

    for (final supported in supportedLearningLanguageCodes) {
      if (supported.toLowerCase() == normalized.toLowerCase()) {
        return supported;
      }
    }

    final baseLanguage = normalized.split('-').first.toLowerCase();
    final matches = supportedLearningLanguageCodes.where(
      (code) => code.split('-').first.toLowerCase() == baseLanguage,
    );

    return matches.length == 1 ? matches.single : null;
  }

  static OfficialLearningPathDescriptor resolve(String learningLanguageCode) {
    final normalized = normalizeSupportedLanguageCode(learningLanguageCode);
    final descriptor = normalized == null ? null : _descriptors[normalized];

    if (descriptor == null) {
      throw UnsupportedError(
        'Idioma de aprendizagem sem percurso oficial suportado: '
        '$learningLanguageCode',
      );
    }

    return descriptor;
  }
}
