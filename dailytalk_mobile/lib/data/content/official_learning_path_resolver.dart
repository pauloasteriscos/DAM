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

  static const Map<String, OfficialLearningPathDescriptor>
  _descriptors = <String, OfficialLearningPathDescriptor>{
    'pt-PT': OfficialLearningPathDescriptor(
      learningLanguageCode: 'pt-PT',
      learningPathId: 'student.pt-pt.phase1',
      baselineAssetPath: 'assets/content/official_pt_pt_phase1.v1.json',
      baselinePackageVersion: 1,
      baselineSha256:
          '7c02afa87233cad2a175e7ba10c8d07e0340096a867b619b54d7359643e257e2',
    ),
    'en-US': OfficialLearningPathDescriptor(
      learningLanguageCode: 'en-US',
      learningPathId: 'student.en-us.phase1',
      baselineAssetPath: 'assets/content/official_en_us_phase1.v1.json',
      baselinePackageVersion: 1,
      baselineSha256:
          'f8951f542e81f07221d46f2721b949cb30d67e8a97f62a770e95dbbb71871196',
    ),
    'es-ES': OfficialLearningPathDescriptor(
      learningLanguageCode: 'es-ES',
      learningPathId: 'student.es-es.phase1',
      baselineAssetPath: 'assets/content/official_es_es_phase1.v1.json',
      baselinePackageVersion: 1,
      baselineSha256:
          '571c79de28444cc3421cad66123ca6c5c9ab24df99b941f17abc06f2c1d86e08',
    ),
    'fr-FR': OfficialLearningPathDescriptor(
      learningLanguageCode: 'fr-FR',
      learningPathId: 'student.fr-fr.phase1',
      baselineAssetPath: 'assets/content/official_fr_fr_phase1.v5.json',
      baselinePackageVersion: 5,
      baselineSha256:
          '114d338f667364067a4c451b0a32039ee7384ef0dbcf65b57dbdd43def53404c',
    ),
    'it-IT': OfficialLearningPathDescriptor(
      learningLanguageCode: 'it-IT',
      learningPathId: 'student.it-it.phase1',
      baselineAssetPath: 'assets/content/official_it_it_phase1.v1.json',
      baselinePackageVersion: 1,
      baselineSha256:
          'cd90b7829d6668769af10d80f16b9ece5d9ad45f74dde822556bb35797ff1a9e',
    ),
    'de-DE': OfficialLearningPathDescriptor(
      learningLanguageCode: 'de-DE',
      learningPathId: 'student.de-de.phase1',
      baselineAssetPath: 'assets/content/official_de_de_phase1.v1.json',
      baselinePackageVersion: 1,
      baselineSha256:
          '36b8918f56626f9fa537a0a2a74d4314b2bc806bb899ba352ab07a87de0ac30b',
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
