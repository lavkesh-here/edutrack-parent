import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';

const _kActiveSchool = 'parent_branding_active_school';

class SchoolBranding {
  final Color primaryColor;
  final String? tagline;
  final String? logoBase64;

  const SchoolBranding({
    required this.primaryColor,
    this.tagline,
    this.logoBase64,
  });

  static SchoolBranding defaults() => const SchoolBranding(primaryColor: Color(0xFFF97316));
}

class ParentBrandingProvider extends ChangeNotifier {
  SchoolBranding _current = SchoolBranding.defaults();
  final Map<String, SchoolBranding> _cache = {};
  String? _activeSchoolId;

  Color get primaryColor => _current.primaryColor;
  String? get tagline => _current.tagline;
  String? get logoBase64 => _current.logoBase64;

  ParentBrandingProvider() {
    _restoreFromCache();
  }

  Future<void> _restoreFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSchoolId = prefs.getString(_kActiveSchool);
    if (lastSchoolId == null) return;
    final hex = prefs.getString('parent_branding_${lastSchoolId}_color');
    if (hex == null) return;
    try {
      final color = Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
      final branding = SchoolBranding(
        primaryColor: color,
        tagline: prefs.getString('parent_branding_${lastSchoolId}_tagline'),
        logoBase64: prefs.getString('parent_branding_${lastSchoolId}_logo'),
      );
      _cache[lastSchoolId] = branding;
      _current = branding;
      _activeSchoolId = lastSchoolId;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadForSchool(String schoolId) async {
    // Apply cached immediately for instant switch
    if (_cache.containsKey(schoolId)) {
      _current = _cache[schoolId]!;
      _activeSchoolId = schoolId;
      notifyListeners();
    }
    // Fetch fresh from API
    try {
      final data = await ParentApiClient.getBranding(schoolId);
      await _apply(schoolId, data);
    } catch (_) {}
  }

  Future<void> _apply(String schoolId, Map<String, dynamic> data) async {
    final colorThemeEnabled = data['color_theme_enabled'] as bool? ?? true;
    Color color = const Color(0xFFF97316);
    String? colorHex;
    if (colorThemeEnabled && data['primary_color'] != null) {
      colorHex = data['primary_color'] as String;
      try {
        color = Color(int.parse('FF${colorHex.replaceFirst('#', '')}', radix: 16));
      } catch (_) {}
    }
    final tagline = data['tagline'] as String?;
    final logoBase64 = data['logo_base64'] as String?;

    final branding = SchoolBranding(primaryColor: color, tagline: tagline, logoBase64: logoBase64);
    _cache[schoolId] = branding;
    if (_activeSchoolId == schoolId || _activeSchoolId == null) {
      _current = branding;
      _activeSchoolId = schoolId;
      notifyListeners();
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kActiveSchool, schoolId);
    if (colorHex != null) {
      await prefs.setString('parent_branding_${schoolId}_color', colorHex);
    } else {
      await prefs.remove('parent_branding_${schoolId}_color');
    }
    if (tagline != null) {
      await prefs.setString('parent_branding_${schoolId}_tagline', tagline);
    } else {
      await prefs.remove('parent_branding_${schoolId}_tagline');
    }
    if (logoBase64 != null) {
      await prefs.setString('parent_branding_${schoolId}_logo', logoBase64);
    } else {
      await prefs.remove('parent_branding_${schoolId}_logo');
    }
  }

  Future<void> reset() async {
    _current = SchoolBranding.defaults();
    _activeSchoolId = null;
    _cache.clear();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('parent_branding_')).toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}
