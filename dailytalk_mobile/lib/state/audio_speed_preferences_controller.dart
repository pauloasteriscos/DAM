import 'package:flutter/foundation.dart';

import '../data/dao/app_settings_dao.dart';
import '../data/database/app_database.dart';
import '../models/audio_speed_control_style.dart';

typedef AudioSpeedStyleReader = Future<String?> Function();
typedef AudioSpeedStyleWriter = Future<void> Function(String value);

/// Runtime owner of the user's preferred visual control for audio speed.
///
/// The preference is deliberately local and non-sensitive. It does not affect
/// pedagogical progression or the speed chosen by a lesson; it only changes
/// how the same five speed choices are presented.
final class AudioSpeedPreferencesController extends ChangeNotifier {
  AudioSpeedPreferencesController({
    AudioSpeedStyleReader? readStyle,
    AudioSpeedStyleWriter? writeStyle,
  }) : _readStyle = readStyle ?? _readFromDatabase,
       _writeStyle = writeStyle ?? _writeToDatabase;

  static final AudioSpeedPreferencesController instance =
      AudioSpeedPreferencesController();

  final AudioSpeedStyleReader _readStyle;
  final AudioSpeedStyleWriter _writeStyle;

  AudioSpeedControlStyle _style = AudioSpeedControlStyle.buttons;
  bool _loaded = false;
  Future<void>? _loadOperation;

  AudioSpeedControlStyle get style => _style;
  bool get isLoaded => _loaded;

  Future<void> ensureLoaded() {
    if (_loaded) {
      return Future<void>.value();
    }

    return _loadOperation ??= _load();
  }

  Future<void> _load() async {
    try {
      final stored = await _readStyle();
      _style = AudioSpeedControlStyle.fromStorage(stored);
    } on Object catch (error) {
      debugPrint('Audio speed style preference could not be loaded: $error');
      _style = AudioSpeedControlStyle.buttons;
    } finally {
      _loaded = true;
      _loadOperation = null;
      notifyListeners();
    }
  }

  Future<bool> setStyle(AudioSpeedControlStyle style) async {
    final changed = _style != style || !_loaded;
    _style = style;
    _loaded = true;

    if (changed) {
      notifyListeners();
    }

    try {
      await _writeStyle(style.storageValue);
      return true;
    } on Object catch (error) {
      // Keep the in-memory choice for the current session. Persistence failure
      // must not block an activity.
      debugPrint('Audio speed style preference could not be saved: $error');
      return false;
    }
  }

  static Future<String?> _readFromDatabase() async {
    final db = await AppDatabase.instance.database;
    return AppSettingsDao(db).getAudioSpeedControlStyle();
  }

  static Future<void> _writeToDatabase(String value) async {
    final db = await AppDatabase.instance.database;
    await AppSettingsDao(db).setAudioSpeedControlStyle(value);
  }
}
