import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'cache.dart';
import 'features.dart';

const _secureStorage = FlutterSecureStorage();
const _kBioEnabled  = 'parent_bio_enabled';

class ParentUser {
  final String parentName;
  final String parentId;
  final String? photoUrl;

  const ParentUser({required this.parentName, required this.parentId, this.photoUrl});
}

class ParentAuthProvider extends ChangeNotifier {
  ParentUser? _user;
  bool _loading = true;
  bool _isLocked = false;
  FeatureFlags _features = FeatureFlags.defaults();
  String? _pendingNotifType;
  String? _pendingNotifStudentId;
  String? _pendingNotifDate;

  // ── Biometric ─────────────────────────────────────────────────────────────
  final _localAuth = LocalAuthentication();

  Future<bool> get isBiometricAvailable async {
    try {
      return await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
    } catch (_) { return false; }
  }

  Future<bool> get isBiometricEnabled async =>
      (await SharedPreferences.getInstance()).getBool(_kBioEnabled) ?? false;

  Future<void> enableBiometric() async {
    (await SharedPreferences.getInstance()).setBool(_kBioEnabled, true);
  }

  Future<void> disableBiometric() async {
    (await SharedPreferences.getInstance()).setBool(_kBioEnabled, false);
    // Clean up any legacy stored credentials
    await _secureStorage.delete(key: 'parent_bio_phone');
    await _secureStorage.delete(key: 'parent_bio_password');
  }

  /// Prompts biometric and unlocks the app. Returns null on success, error string on failure.
  Future<String?> unlockApp() async {
    try {
      final authed = await _localAuth.authenticate(
        localizedReason: 'Unlock EduTrack Parent',
        options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true),
      );
      if (!authed) return 'Authentication cancelled.';
      _isLocked = false;
      notifyListeners();
      return null;
    } catch (e) {
      return 'Biometric error: $e';
    }
  }

  /// Prompts biometric for confirmation (enrollment / toggle). Returns true if authenticated.
  Future<bool> authenticateBiometric(String reason) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true),
      );
    } catch (_) {
      return false;
    }
  }

  void lockApp() {
    _isLocked = true;
    notifyListeners();
  }

  ParentUser? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get loading => _loading;
  bool get isLocked => _isLocked;
  FeatureFlags get features => _features;
  String? get pendingNotifType => _pendingNotifType;
  String? get pendingNotifStudentId => _pendingNotifStudentId;
  String? get pendingNotifDate => _pendingNotifDate;

  void setPendingNavigation(String type, String? studentId, {String? date}) {
    _pendingNotifType = type;
    _pendingNotifStudentId = studentId;
    _pendingNotifDate = date;
  }

  void clearPendingNavigation() {
    _pendingNotifType = null;
    _pendingNotifStudentId = null;
    _pendingNotifDate = null;
  }

  Future<String?> getStoredPhone() async =>
      (await SharedPreferences.getInstance()).getString('parent_phone');

  String get initials {
    if (_user == null) return '?';
    final parts = _user!.parentName.trim().split(' ');
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : '?';
  }

  ParentAuthProvider() {
    ParentApiClient.onUnauthorized = () async => logout();
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final token = await ParentApiClient.getToken();
    if (token != null) {
      final name = prefs.getString('parent_name') ?? '';
      final id = prefs.getString('parent_id') ?? '';
      if (name.isNotEmpty) {
        _user = ParentUser(
          parentName: name,
          parentId: id,
          photoUrl: prefs.getString('parent_photo_url'),
        );
      }
    }
    if (_user != null && (prefs.getBool(_kBioEnabled) ?? false)) {
      _isLocked = true;
    }
    _loading = false;
    notifyListeners();
    if (_user != null) _loadFeatureFlags();
  }

  /// Returns true if user must change password
  Future<bool> login(String phone, String password, {String? deviceName, String? osVersion}) async {
    final res = await ParentApiClient.login(phone, password, deviceName: deviceName, osVersion: osVersion);
    await ParentApiClient.setToken(res.token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('parent_name', res.parentName);
    await prefs.setString('parent_id', res.parentId);
    await prefs.setString('parent_phone', phone);
    _user = ParentUser(parentName: res.parentName, parentId: res.parentId);
    _loadFeatureFlags();
    notifyListeners();
    return res.mustChangePassword;
  }

  Future<void> updatePhotoUrl(String url) async {
    if (_user == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('parent_photo_url', url);
    _user = ParentUser(parentName: _user!.parentName, parentId: _user!.parentId, photoUrl: url);
    notifyListeners();
  }

  Future<void> _loadFeatureFlags() async {
    try {
      final cached = await FeatureFlags.fromCache();
      if (cached != null) {
        _features = cached;
        notifyListeners();
      }
      final fresh = await ParentApiClient.getFeatureConfig();
      _features = FeatureFlags.fromJson(fresh);
      await _features.saveToCache();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> logout() async {
    _isLocked = false;
    await ParentApiClient.setToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('parent_name');
    await prefs.remove('parent_id');
    await prefs.remove('parent_photo_url');
    _user = null;
    _features = FeatureFlags.defaults();
    await CacheService.clearAll();
    notifyListeners();
  }
}
