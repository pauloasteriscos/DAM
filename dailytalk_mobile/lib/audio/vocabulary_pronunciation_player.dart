import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Boundary used by the vocabulary runtime to pronounce target-language cards.
///
/// The runtime depends on this small contract rather than directly on a TTS
/// plugin so that official cached audio can replace the implementation later
/// without changing the matching-pairs interaction.
abstract interface class VocabularyPronunciationPlayer {
  Future<bool> isAvailable({required String locale});

  Future<bool> speak({
    required String text,
    required String locale,
    required double speed,
  });

  Future<void> stop();
}

/// Device/browser TTS implementation used by the current pronunciation
/// increment.
///
/// The visible DailyTalk speeds are pedagogical multipliers. `flutter_tts`
/// exposes a normalized 0..1 speech-rate scale, therefore 1x maps to 0.5 and
/// the other values scale around that midpoint.
final class TtsVocabularyPronunciationPlayer
    implements VocabularyPronunciationPlayer {
  TtsVocabularyPronunciationPlayer({FlutterTts? tts})
    : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;

  @override
  Future<bool> isAvailable({required String locale}) async {
    // Browser TTS capability probes are not reliable enough to be used as a
    // hard disable gate. Chrome can report an exact locale as unavailable and
    // still synthesize it successfully through a compatible installed voice.
    // On Web we therefore keep the control enabled until an actual speak()
    // attempt fails. Native platforms keep the explicit language probe.
    if (kIsWeb) {
      return true;
    }

    try {
      final result = await _tts.isLanguageAvailable(locale);

      if (result is bool) {
        return result;
      }
      if (result is num) {
        return result != 0;
      }

      final normalized = result?.toString().trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
      if (normalized == 'false' || normalized == '0' || normalized == 'no') {
        return false;
      }

      // Some Web engines do not expose a reliable capability probe even though
      // speech synthesis itself works. An inconclusive answer must therefore
      // not disable a feature that can still succeed on user interaction.
      return true;
    } on Object {
      // Same rationale as above: an unsupported capability probe is different
      // from a confirmed absence of speech synthesis.
      return true;
    }
  }

  @override
  Future<bool> speak({
    required String text,
    required String locale,
    required double speed,
  }) async {
    final normalizedText = text.trim();
    if (normalizedText.isEmpty) {
      return false;
    }

    try {
      await _tts.stop();
      await _tts.setLanguage(locale);
      await _tts.setVolume(1);
      await _tts.setPitch(1);
      await _tts.setSpeechRate(_ttsRateFor(speed));

      // On Web, `speak` can complete successfully without returning the integer
      // value used by some native implementations. Success is therefore
      // defined by the absence of an exception, not by `result == 1`.
      await _tts.speak(normalizedText);
      return true;
    } on Object {
      // Pronunciation is an enhancement: an unavailable TTS engine must never
      // block the vocabulary activity or its local pedagogical progression.
      return false;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } on Object {
      // Best-effort cleanup only.
    }
  }

  double _ttsRateFor(double speed) {
    final mapped = speed * 0.5;
    return mapped.clamp(0.0, 1.0).toDouble();
  }
}
