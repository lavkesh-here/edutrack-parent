import 'dart:convert';
import 'cache.dart';

/// Typed accessor for school feature flags.
/// Defaults to `true` (enabled) for any unknown key — new features are on by default.
class FeatureFlags {
  final Map<String, bool> _flags;

  const FeatureFlags(this._flags);

  /// All features enabled — used before flags are loaded.
  factory FeatureFlags.defaults() => const FeatureFlags({});

  factory FeatureFlags.fromJson(Map<String, dynamic> j) => FeatureFlags(
        Map<String, bool>.fromEntries(
          j.entries.map((e) => MapEntry(e.key, (e.value as bool?) ?? true)),
        ),
      );

  // ── Teacher feature accessors ──────────────────────────────────────────────

  bool get aiGenerate => _flags['feature.ai_generate'] ?? true;
  bool get aiAnalysis => _flags['feature.ai_analysis'] ?? true;
  bool get pdfExport => _flags['feature.pdf_export'] ?? true;
  bool get diksha => _flags['feature.diksha'] ?? true;
  bool get payroll => _flags['feature.payroll'] ?? true;
  bool get visitorLog => _flags['feature.visitor_log'] ?? true;
  bool get announcements => _flags['feature.announcements'] ?? true;
  bool get circulars => _flags['feature.circulars'] ?? true;
  bool get fees => _flags['feature.parent_fees'] ?? true;
  bool get transport => _flags['feature.transport'] ?? true;
  bool get workLogs => _flags['feature.work_logs'] ?? true;

  bool operator [](String key) => _flags[key] ?? true;

  Map<String, dynamic> toJson() => Map<String, dynamic>.from(_flags);

  // ── Cache helpers ──────────────────────────────────────────────────────────

  static const _cacheKey = 'feature_flags';
  static const _cacheTtl = Duration(minutes: 30);

  static Future<FeatureFlags?> fromCache() async {
    final cached = await CacheService.getMap(_cacheKey, maxAge: _cacheTtl);
    if (cached == null) return null;
    return FeatureFlags.fromJson(cached);
  }

  Future<void> saveToCache() async {
    await CacheService.set(_cacheKey, toJson());
  }

  static Future<void> clearCache() async {
    await CacheService.remove(_cacheKey);
  }
}
