import 'dart:collection';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';

import '../../l10n/ui_localization_contract.dart';
import '../repositories/ui_translation_repository.dart';

/// Descriptor imutável de um bundle bootstrap incluído no APK/Web bundle.
final class UiTranslationBootstrapDescriptor {
  const UiTranslationBootstrapDescriptor({
    required this.locale,
    required this.bundleVersion,
    required this.assetPath,
  });

  final String locale;
  final int bundleVersion;
  final String assetPath;
}

/// Instala os bundles LC-001 que acompanham a aplicação.
///
/// SQLite é a fonte persistente em runtime. Os JSON servem apenas de bootstrap
/// offline/last-known-good inicial; depois de instalados, a resolução normal
/// usa o cache em memória.
///
/// A rotina nunca faz downgrade: se um locale já tiver um bundle ativo mais
/// recente (por exemplo vindo futuramente da API/D1), o bootstrap empacotado
/// é ignorado.
final class UiTranslationBootstrapService {
  UiTranslationBootstrapService({
    required this.repository,
    AssetBundle? assetBundle,
  }) : assetBundle = assetBundle ?? rootBundle;

  final UiTranslationRepository repository;
  final AssetBundle assetBundle;

  static const List<UiTranslationBootstrapDescriptor> bundledV1 =
      <UiTranslationBootstrapDescriptor>[
        UiTranslationBootstrapDescriptor(
          locale: 'pt-PT',
          bundleVersion: 1,
          assetPath: 'assets/localization/ui_pt_pt.v1.json',
        ),
        UiTranslationBootstrapDescriptor(
          locale: 'en-US',
          bundleVersion: 1,
          assetPath: 'assets/localization/ui_en_us.v1.json',
        ),
        UiTranslationBootstrapDescriptor(
          locale: 'es-ES',
          bundleVersion: 1,
          assetPath: 'assets/localization/ui_es_es.v1.json',
        ),
        UiTranslationBootstrapDescriptor(
          locale: 'fr-FR',
          bundleVersion: 1,
          assetPath: 'assets/localization/ui_fr_fr.v1.json',
        ),
        UiTranslationBootstrapDescriptor(
          locale: 'it-IT',
          bundleVersion: 1,
          assetPath: 'assets/localization/ui_it_it.v1.json',
        ),
        UiTranslationBootstrapDescriptor(
          locale: 'de-DE',
          bundleVersion: 1,
          assetPath: 'assets/localization/ui_de_de.v1.json',
        ),
      ];

  Future<void> ensureLocalBundles() async {
    for (final descriptor in bundledV1) {
      final current = await repository.readCatalog(descriptor.locale);

      // Um bundle remoto posterior nunca é rebaixado pelo bootstrap do APK.
      if (current != null &&
          current.activeBundleVersion > descriptor.bundleVersion) {
        continue;
      }

      final bundle = await _load(descriptor);

      // Compatibilidade apenas para instalações DEV que já receberam a v1
      // inicial da LC-001 antes de o conjunto de chaves ficar completo. Não
      // cria v2 artificial: repara somente uma v1 bundled incompleta.
      final repaired = await repository.repairBundledV1IfIncomplete(
        locale: bundle.locale,
        schemaVersion: bundle.schemaVersion,
        checksum: bundle.checksum,
        translations: bundle.translations,
        requiredKeys: UiLocalizationContract.requiredKeysCurrent,
      );

      if (current != null &&
          current.activeBundleVersion == descriptor.bundleVersion) {
        final active = await repository.readActiveBundle(bundle.locale);
        final missing = UiLocalizationContract.requiredKeysCurrent.difference(
          active?.translations.keys.toSet() ?? const <String>{},
        );
        if (missing.isNotEmpty) {
          throw UiTranslationBundleIncomplete(
            locale: bundle.locale,
            bundleVersion: bundle.bundleVersion,
            missingKeys: missing,
          );
        }
        continue;
      }

      if (!repaired) {
        await repository.importBundle(
          locale: bundle.locale,
          bundleVersion: bundle.bundleVersion,
          schemaVersion: bundle.schemaVersion,
          checksum: bundle.checksum,
          translations: bundle.translations,
          source: 'bundled',
        );
      }

      await repository.activateBundle(
        locale: bundle.locale,
        bundleVersion: bundle.bundleVersion,
        requiredKeys: UiLocalizationContract.requiredKeysCurrent,
      );
    }
  }

  Future<_BootstrapBundle> _load(
    UiTranslationBootstrapDescriptor descriptor,
  ) async {
    final raw = await assetBundle.loadString(descriptor.assetPath);
    final decoded = jsonDecode(raw);

    if (decoded is! Map<String, dynamic>) {
      throw FormatException('Bundle de UI inválido: ${descriptor.assetPath}.');
    }

    final locale = decoded['locale']?.toString().trim();
    final bundleVersion = decoded['bundleVersion'];
    final schemaVersion = decoded['schemaVersion'];
    final translationsRaw = decoded['translations'];

    if (locale != descriptor.locale) {
      throw FormatException(
        'Locale inesperado em ${descriptor.assetPath}: $locale.',
      );
    }
    if (bundleVersion != descriptor.bundleVersion) {
      throw FormatException(
        'Versão inesperada em ${descriptor.assetPath}: $bundleVersion.',
      );
    }
    if (schemaVersion != UiLocalizationContract.schemaVersion) {
      throw FormatException(
        'Schema inesperado em ${descriptor.assetPath}: $schemaVersion.',
      );
    }
    if (translationsRaw is! Map<String, dynamic>) {
      throw FormatException(
        'translations inválido em ${descriptor.assetPath}.',
      );
    }

    final translations = <String, String>{};
    for (final entry in translationsRaw.entries) {
      final key = entry.key.trim();
      final value = entry.value?.toString().trim() ?? '';
      if (key.isEmpty || value.isEmpty) {
        throw FormatException(
          'Chave/tradução vazia em ${descriptor.assetPath}.',
        );
      }
      translations[key] = value;
    }

    final missing = UiLocalizationContract.requiredKeysCurrent.difference(
      translations.keys.toSet(),
    );
    if (missing.isNotEmpty) {
      throw UiTranslationBundleIncomplete(
        locale: locale!,
        bundleVersion: bundleVersion as int,
        missingKeys: missing,
      );
    }

    return _BootstrapBundle(
      locale: locale!,
      bundleVersion: bundleVersion as int,
      schemaVersion: schemaVersion as int,
      checksum: await _checksum(translations),
      translations: Map<String, String>.unmodifiable(translations),
    );
  }

  Future<String> _checksum(Map<String, String> translations) async {
    final sorted = SplayTreeMap<String, String>.from(translations);
    final canonical = jsonEncode(sorted);
    final hash = await Sha256().hash(utf8.encode(canonical));
    return hash.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}

final class _BootstrapBundle {
  const _BootstrapBundle({
    required this.locale,
    required this.bundleVersion,
    required this.schemaVersion,
    required this.checksum,
    required this.translations,
  });

  final String locale;
  final int bundleVersion;
  final int schemaVersion;
  final String checksum;
  final Map<String, String> translations;
}
