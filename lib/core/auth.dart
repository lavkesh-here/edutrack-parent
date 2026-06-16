import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'cache.dart';
import 'features.dart';

class ParentUser {
  final String parentName;
  final String parentId;

  const ParentUser({required this.parentName, required this.parentId});
}

class ParentAuthProvider extends ChangeNotifier {
  ParentUser? _user;
  bool _loading = true;
  FeatureFlags _features = FeatureFlags.defaults();
  String? _pendingNotifType;
  String? _pendingNotifStudentId;

  ParentUser? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get loading => _loading;
  FeatureFlags get features => _features;
  String? get pendingNotifType => _pendingNotifType;
  int? get pendingNotifStudentId => _pendingNotifStudentId;

  void setPendingNavigation(String type, String? studentId) {
    _pendingNotifType = type;
    _pendingNotifStudentId = studentId;
  }

  void clearPendingNavigation() {
    _pendingNotifType = null;
    _pendingNotifStudentId = null;
  }

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
      final id = prefs.getString('parent_id') ?? 0;
      if (name.isNotEmpty) {
        _user = ParentUser(parentName: name, parentId: id);
      }
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
    _user = ParentUser(parentName: res.parentName, parentId: res.parentId);
    _loadFeatureFlags();
    notifyListeners();
    return res.mustChangePassword;
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
    await ParentApiClient.setToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('parent_name');
    await prefs.remove('parent_id');
    _user = null;
    _features = FeatureFlags.defaults();
    await CacheService.clearAll();
    notifyListeners();
  }
}
