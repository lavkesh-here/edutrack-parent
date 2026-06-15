import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple TTL-based JSON cache backed by SharedPreferences.
///
/// Usage:
///   await CacheService.set('timetable', myList);
///   final cached = await CacheService.getList('timetable', maxAge: Duration(minutes: 30));
class CacheService {
  static const _prefix = 'cache:v1:';

  // ── Write ──────────────────────────────────────────────────────────────────

  static Future<void> set(String key, dynamic data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_prefix$key', jsonEncode({
        'ts': DateTime.now().toIso8601String(),
        'data': data,
      }));
    } catch (_) {}
  }

  // ── Read ───────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> getMap(
    String key, {
    Duration maxAge = const Duration(hours: 1),
  }) async {
    final raw = await _raw(key, maxAge);
    if (raw == null) return null;
    return raw['data'] as Map<String, dynamic>?;
  }

  static Future<List<dynamic>?> getList(
    String key, {
    Duration maxAge = const Duration(hours: 1),
  }) async {
    final raw = await _raw(key, maxAge);
    if (raw == null) return null;
    return raw['data'] as List<dynamic>?;
  }

  // ── Invalidate ─────────────────────────────────────────────────────────────

  static Future<void> remove(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_prefix$key');
    } catch (_) {}
  }

  /// Clear all cache entries (call on logout).
  static Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
      for (final k in keys) {
        await prefs.remove(k);
      }
    } catch (_) {}
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> _raw(String key, Duration maxAge) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('$_prefix$key');
      if (stored == null) return null;
      final wrapper = jsonDecode(stored) as Map<String, dynamic>;
      final ts = DateTime.parse(wrapper['ts'] as String);
      if (DateTime.now().difference(ts) > maxAge) return null;
      return wrapper;
    } catch (_) {
      return null;
    }
  }
}
