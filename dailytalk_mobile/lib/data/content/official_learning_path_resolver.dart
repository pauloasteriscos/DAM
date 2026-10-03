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
      baselineAssetPath: 'assets/content/official_pt_pt_phase1.v8.json',
      baselinePackageVersion: 8,
      baselineSha256:
          'a0ae0cc9bfe51afdd179b64c054c424ea965ffea05df5c58c0399d15eb565deb',
    ),
    'en-US': OfficialLearningPathDescriptor(
      learningLanguageCode: 'en-US',
      learningPathId: 'student.en-us.phase1',
      baselineAssetPath: 'assets/content/official_en_us_phase1.v8.json',
      baselinePackageVersion: 8,
      baselineSha256:
          '00479e9b72f7b454e1c7e0b20d0c596d7218c1e9e39207ba035ba85ca9ad75ea',
    ),
    'es-ES': OfficialLearningPathDescriptor(
      learningLanguageCode: 'es-ES',
      learningPathId: 'student.es-es.phase1',
      baselineAssetPath: 'assets/content/official_es_es_phase1.v8.json',
      baselinePackageVersion: 8,
      baselineSha256:
          '60821d6685cb9fa495e855c9e9741138199e95358a5ca3c41e626b5efd5d267a',
    ),
    'fr-FR': OfficialLearningPathDescriptor(
      learningLanguageCode: 'fr-FR',
      learningPathId: 'student.fr-fr.phase1',
      baselineAssetPath: 'assets/content/official_fr_fr_phase1.v8.json',
      baselinePackageVersion: 8,
      baselineSha256:
          '067f58f44c6d9c4982e76b008e9a05ed1b42d770cf6af6a704c579819e18d05a',
    ),
    'it-IT': OfficialLearningPathDescriptor(
      learningLanguageCode: 'it-IT',
      learningPathId: 'student.it-it.phase1',
      baselineAssetPath: 'assets/content/official_it_it_phase1.v8.json',
      baselinePackageVersion: 8,
      baselineSha256:
          'de3f5cacfd44300e630816a3be2b371f0e3c78230d2e04996151b72dbfed6f25',
    ),
    'de-DE': OfficialLearningPathDescriptor(
      learningLanguageCode: 'de-DE',
      learningPathId: 'student.de-de.phase1',
      baselineAssetPath: 'assets/content/official_de_de_phase1.v8.json',
      baselinePackageVersion: 8,
      baselineSha256:
          'f37dc1d55004e6f15b9024d7d6b1fbc8754a7efec9dafc29d1475a31163a21e5',
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
