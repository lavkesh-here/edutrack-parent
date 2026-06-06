import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';

class ParentUser {
  final String parentName;
  final int parentId;

  const ParentUser({required this.parentName, required this.parentId});
}

class ParentAuthProvider extends ChangeNotifier {
  ParentUser? _user;
  bool _loading = true;

  ParentUser? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get loading => _loading;

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
      final id = prefs.getInt('parent_id') ?? 0;
      if (name.isNotEmpty) {
        _user = ParentUser(parentName: name, parentId: id);
      }
    }
    _loading = false;
    notifyListeners();
  }

  /// Returns true if user must change password
  Future<bool> login(String phone, String password, {String? deviceName, String? osVersion}) async {
    final res = await ParentApiClient.login(phone, password, deviceName: deviceName, osVersion: osVersion);
    await ParentApiClient.setToken(res.token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('parent_name', res.parentName);
    await prefs.setInt('parent_id', res.parentId);
    _user = ParentUser(parentName: res.parentName, parentId: res.parentId);
    notifyListeners();
    return res.mustChangePassword;
  }

  Future<void> logout() async {
    await ParentApiClient.setToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('parent_name');
    await prefs.remove('parent_id');
    _user = null;
    notifyListeners();
  }
}
