import 'dart:io';
import 'dart:math';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stable device/session context sent as HTTP headers on every API request.
///
/// Headers written:
///   X-Device-ID    — UUID persisted in SharedPreferences (stable across sessions)
///   X-Session-ID   — UUID generated once per app launch (reset on kill/restart)
///   X-App-Version  — e.g. "1.4.2" from package_info_plus
///   X-Platform     — "android" | "ios"
///   X-App-Type     — "parent"
class DeviceContext {
  static const _prefKeyDeviceId = 'analytics_device_id';

  static String? _deviceId;
  static String? _sessionId;
  static String? _appVersion;

  /// Call once from main() before runApp(). Safe to call multiple times.
  static Future<void> init() async {
    if (_deviceId != null) return;

    final prefs = await SharedPreferences.getInstance();

    _deviceId = prefs.getString(_prefKeyDeviceId);
    if (_deviceId == null) {
      _deviceId = _uuid();
      await prefs.setString(_prefKeyDeviceId, _deviceId!);
    }

    _sessionId = _uuid();

    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = info.version;
    } catch (_) {
      _appVersion = 'unknown';
    }
  }

  static Map<String, String> get headers {
    return {
      if (_deviceId != null)   'X-Device-ID':   _deviceId!,
      if (_sessionId != null)  'X-Session-ID':  _sessionId!,
      if (_appVersion != null) 'X-App-Version': _appVersion!,
      'X-Platform': Platform.isIOS ? 'ios' : 'android',
      'X-App-Type': 'parent',
    };
  }

  static String _uuid() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
