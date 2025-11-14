import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

class GuestService {
  static const _kGuestKey = 'guest_player_id';

  static Future<String> getOrCreateGuestId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_kGuestKey);
    if (existing != null && existing.isNotEmpty) return existing;

    // generate a short guest id
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random();
    final sb = StringBuffer('guest_');
    for (var i = 0; i < 8; i++) sb.write(chars[rand.nextInt(chars.length)]);
    final id = sb.toString();
    await prefs.setString(_kGuestKey, id);
    return id;
  }
}
