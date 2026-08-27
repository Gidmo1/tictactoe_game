import 'package:shared_preferences/shared_preferences.dart';

import 'theme.dart';

/// Persists the user's currently selected [GameTheme] on this device.
///
/// Reads are instant via the static [current] cache so screens don't need
/// to await onLoad. The cache is populated once at startup and updated
/// synchronously whenever the user picks a new theme.
class ThemeStore {
  static const _key = 'selected_theme';

  /// The current theme, available synchronously.
  static GameTheme current = GameThemes.classic;

  /// Populate [current] once at startup. Call from main().
  static Future<void> init() async {
    current = await _load();
  }

  /// Internal async load from SharedPreferences.
  static Future<GameTheme> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return GameThemes.byId(prefs.getString(_key) ?? 'classic');
    } catch (_) {
      return GameThemes.classic;
    }
  }

  /// Persists [themeId] and updates [current] synchronously so every screen
  /// that reads [current] sees the change immediately.
  static Future<void> save(String themeId) async {
    current = GameThemes.byId(themeId);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, themeId);
    } catch (_) {}
  }
}