import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class GuestService {
  static const _kGuestKey = 'guest_player_id';
  static final _uuid = Uuid();

  /// Returns a stable guest id persisted in `SharedPreferences`.
  /// If none exists, generates a v4 UUID and persists it.
  static Future<String> getOrCreateGuestId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_kGuestKey);
    if (existing != null && existing.isNotEmpty) return existing;

    // Generate a v4 UUID for the guest id for cross-platform stability.
    final id = _uuid.v4();
    await prefs.setString(_kGuestKey, id);
    return id;
  }
}
