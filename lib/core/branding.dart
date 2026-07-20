import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';

const _kActiveSchool    = 'parent_branding_active_school';
// per-school keys — keyed by schoolId so multi-child families work correctly
String _kAdminColor(String id)  => 'parent_branding_${id}_color';
String _kUserColor(String id)   => 'parent_branding_${id}_user_color'; // survives admin changes
String _kTaglineKey(String id)  => 'parent_branding_${id}_tagline';
String _kLogoKey(String id)     => 'parent_branding_${id}_logo';

// Colour presets shown in the in-app picker.
const kBrandingPresets = [
  Color(0xFF14B8A6), // Teal    (parent default)
  Color(0xFFF97316), // Orange  (teacher default)
  Color(0xFF3B82F6), // Blue
  Color(0xFF6366F1), // Indigo
  Color(0xFF8B5CF6), // Violet
  Color(0xFF22C55E), // Green
  Color(0xFFF43F5E), // Rose
  Color(0xFFF59E0B), // Amber
  Color(0xFF0EA5E9), // Sky
];

class SchoolBranding {
  final Color primaryColor;
  final String? tagline;
  final String? logoBase64;

  const SchoolBranding({
    required this.primaryColor,
    this.tagline,
    this.logoBase64,
  });

  static SchoolBranding defaults() =>
      const SchoolBranding(primaryColor: Color(0xFF14B8A6));
}

class ParentBrandingProvider extends ChangeNotifier {
  // Admin colour per school.
  final Map<String, Color> _adminColors = {};
  // User override per school — local only, survives admin changes.
  final Map<String, Color> _userOverrides = {};
  final Map<String, SchoolBranding> _cache = {};

  String? _activeSchoolId;
  SchoolBranding _current = SchoolBranding.defaults();

  /// The colour that should be used everywhere in the UI.
  Color get primaryColor {
    final id = _activeSchoolId;
    if (id == null) return _current.primaryColor;
    return _userOverrides[id] ?? _adminColors[id] ?? _current.primaryColor;
  }

  /// The raw admin colour for the active school.
  Color get adminColor =>
      _adminColors[_activeSchoolId ?? ''] ?? const Color(0xFF14B8A6);

  /// True when the user has picked their own colour.
  bool get hasUserOverride =>
      _activeSchoolId != null && _userOverrides.containsKey(_activeSchoolId);

  String? get tagline    => _current.tagline;
  String? get logoBase64 => _current.logoBase64;

  ParentBrandingProvider() {
    _restoreFromCache();
  }

  // ── Restore on startup ───────────────────────────────────────────────────────

  Future<void> _restoreFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSchoolId = prefs.getString(_kActiveSchool);
    if (lastSchoolId == null) return;

    final adminHex = prefs.getString(_kAdminColor(lastSchoolId));
    Color adminColor = const Color(0xFF14B8A6);
    if (adminHex != null) {
      try {
        adminColor = Color(
            int.parse('FF${adminHex.replaceFirst('#', '')}', radix: 16));
      } catch (_) {}
    }
    _adminColors[lastSchoolId] = adminColor;

    final userHex = prefs.getString(_kUserColor(lastSchoolId));
    if (userHex != null) {
      try {
        _userOverrides[lastSchoolId] = Color(
            int.parse('FF${userHex.replaceFirst('#', '')}', radix: 16));
      } catch (_) {}
    }

    final branding = SchoolBranding(
      primaryColor: _userOverrides[lastSchoolId] ?? adminColor,
      tagline:      prefs.getString(_kTaglineKey(lastSchoolId)),
      logoBase64:   prefs.getString(_kLogoKey(lastSchoolId)),
    );
    _cache[lastSchoolId]  = branding;
    _current              = branding;
    _activeSchoolId       = lastSchoolId;
    notifyListeners();
  }

  // ── Load from server ─────────────────────────────────────────────────────────

  Future<void> loadForSchool(String schoolId) async {
    // Apply cached immediately
    if (_cache.containsKey(schoolId)) {
      _current        = _cache[schoolId]!;
      _activeSchoolId = schoolId;
      notifyListeners();
    }
    try {
      final data = await ParentApiClient.getBranding(schoolId);
      await _applyAdmin(schoolId, data);
    } catch (_) {}
  }

  Future<void> _applyAdmin(
      String schoolId, Map<String, dynamic> data) async {
    final colorThemeEnabled = data['color_theme_enabled'] as bool? ?? true;
    Color adminColor = const Color(0xFF14B8A6);
    String? colorHex;

    if (colorThemeEnabled && data['primary_color'] != null) {
      colorHex = data['primary_color'] as String;
      try {
        adminColor = Color(
            int.parse('FF${colorHex.replaceFirst('#', '')}', radix: 16));
      } catch (_) {}
    }

    _adminColors[schoolId] = adminColor;
    final tagline    = data['tagline'] as String?;
    final logoBase64 = data['logo_base64'] as String?;

    // Effective colour = user override (if any) ?? admin colour
    final effective = _userOverrides[schoolId] ?? adminColor;
    final branding  = SchoolBranding(
        primaryColor: effective, tagline: tagline, logoBase64: logoBase64);
    _cache[schoolId] = branding;

    if (_activeSchoolId == schoolId || _activeSchoolId == null) {
      _current        = branding;
      _activeSchoolId = schoolId;
      notifyListeners();
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kActiveSchool, schoolId);
    if (colorHex != null) {
      await prefs.setString(_kAdminColor(schoolId), colorHex);
    } else {
      await prefs.remove(_kAdminColor(schoolId));
    }
    if (tagline != null) {
      await prefs.setString(_kTaglineKey(schoolId), tagline);
    } else {
      await prefs.remove(_kTaglineKey(schoolId));
    }
    if (logoBase64 != null) {
      await prefs.setString(_kLogoKey(schoolId), logoBase64);
    } else {
      await prefs.remove(_kLogoKey(schoolId));
    }
  }

  // ── User override ────────────────────────────────────────────────────────────

  Future<void> setUserOverride(Color color) async {
    final id = _activeSchoolId;
    if (id == null) return;
    _userOverrides[id] = color;
    // Rebuild current branding with new override
    _current = SchoolBranding(
        primaryColor: color,
        tagline:   _current.tagline,
        logoBase64: _current.logoBase64);
    _cache[id] = _current;
    notifyListeners();

    final hex  = '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserColor(id), hex);
  }

  Future<void> clearUserOverride() async {
    final id = _activeSchoolId;
    if (id == null) return;
    _userOverrides.remove(id);
    final adminColor = _adminColors[id] ?? const Color(0xFF14B8A6);
    _current = SchoolBranding(
        primaryColor: adminColor,
        tagline:    _current.tagline,
        logoBase64:  _current.logoBase64);
    _cache[id] = _current;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUserColor(id));
  }

  // ── Full reset (on logout) ───────────────────────────────────────────────────

  Future<void> reset() async {
    _adminColors.clear();
    _userOverrides.clear();
    _cache.clear();
    _current        = SchoolBranding.defaults();
    _activeSchoolId = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys()
        .where((k) => k.startsWith('parent_branding_'))
        .toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}
