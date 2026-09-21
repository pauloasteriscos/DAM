import 'package:flutter_test/flutter_test.dart';

import 'package:dailytalk_mobile/l10n/ui_localization_contract.dart';

void main() {
  test(
    'APP e SCAFFOLDING usam appLanguageCode; TARGET usa learningLanguageCode',
    () {
      const appLanguageCode = 'pt-PT';
      const learningLanguageCode = 'de-DE';

      expect(
        LocalizationRole.app.locale(
          appLanguageCode: appLanguageCode,
          learningLanguageCode: learningLanguageCode,
        ),
        appLanguageCode,
      );
      expect(
        LocalizationRole.scaffolding.locale(
          appLanguageCode: appLanguageCode,
          learningLanguageCode: learningLanguageCode,
        ),
        appLanguageCode,
      );
      expect(
        LocalizationRole.target.locale(
          appLanguageCode: appLanguageCode,
          learningLanguageCode: learningLanguageCode,
        ),
        learningLanguageCode,
      );
    },
  );
}
