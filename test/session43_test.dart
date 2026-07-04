// Pure logic tests for Session 43 feature packaging in parent app.
// No device or platform channels required.

import 'package:flutter_test/flutter_test.dart';

// ── FeatureFlags logic (replicated inline) ────────────────────────────────────

class _FeatureFlags {
  final Map<String, bool> _flags;
  const _FeatureFlags(this._flags);

  factory _FeatureFlags.fromJson(Map<String, dynamic> j) => _FeatureFlags(
        Map<String, bool>.fromEntries(
          j.entries.map((e) => MapEntry(e.key, (e.value as bool?) ?? true)),
        ),
      );

  bool get fees => (_flags['feature.parent_fees'] ?? true) && (_flags['sa.fees_module'] ?? true);
  bool get transport => (_flags['feature.transport'] ?? true) && (_flags['sa.transport_module'] ?? true);
  bool get circulars => _flags['feature.circulars'] ?? true;
  bool get workLogs => _flags['feature.work_logs'] ?? true;
  bool get announcements => _flags['feature.announcements'] ?? true;
}

// ── Dynamic nav index logic (replicated inline) ────────────────────────────────

int profileIdx(bool showWorkLog) => showWorkLog ? 4 : 3;

List<String> buildScreenNames(bool showWorkLog) => [
      'Home',
      'Attendance',
      'Tests',
      if (showWorkLog) 'WorkLog',
      'Profile',
    ];

void main() {
  // ── Dynamic bottom nav ──────────────────────────────────────────────────────

  group('Dynamic bottom nav (workLogs gate)', () {
    test('workLogs enabled → 5 screens, Profile at index 4', () {
      final screens = buildScreenNames(true);
      expect(screens.length, 5);
      expect(screens[3], 'WorkLog');
      expect(screens[4], 'Profile');
      expect(profileIdx(true), 4);
    });

    test('workLogs disabled → 4 screens, Profile at index 3', () {
      final screens = buildScreenNames(false);
      expect(screens.length, 4);
      expect(screens.contains('WorkLog'), isFalse);
      expect(screens[3], 'Profile');
      expect(profileIdx(false), 3);
    });

    test('profileIdx: workLogs=true → 4', () => expect(profileIdx(true), 4));
    test('profileIdx: workLogs=false → 3', () => expect(profileIdx(false), 3));
  });

  // ── work_log deep-link fallback ─────────────────────────────────────────────

  group('work_log notification deep-link', () {
    int resolveNavIndex(String notifType, bool workLogsEnabled) {
      if (notifType == 'work_log' && workLogsEnabled) return 3;
      if (notifType == 'work_log' && !workLogsEnabled) return 0; // fallback to Home
      if (notifType == 'attendance_absent') return 1;
      if (notifType == 'test_result') return 2;
      return 0;
    }

    test('work_log notif with workLogs enabled → tab 3', () {
      expect(resolveNavIndex('work_log', true), 3);
    });

    test('work_log notif with workLogs disabled → tab 0 (Home)', () {
      expect(resolveNavIndex('work_log', false), 0);
    });

    test('attendance notif always → tab 1', () {
      expect(resolveNavIndex('attendance_absent', true), 1);
      expect(resolveNavIndex('attendance_absent', false), 1);
    });

    test('test_result notif always → tab 2', () {
      expect(resolveNavIndex('test_result', true), 2);
    });
  });

  // ── FeatureFlags: plan-gated accessors ─────────────────────────────────────

  group('FeatureFlags accessors with plan ceiling', () {
    test('basic plan: workLogs=true, fees=false', () {
      final flags = _FeatureFlags.fromJson({
        'feature.work_logs': true,
        'feature.parent_fees': false,
        'sa.fees_module': true,
      });
      expect(flags.workLogs, isTrue);
      expect(flags.fees, isFalse);
    });

    test('standard plan: fees=true when both layers agree', () {
      final flags = _FeatureFlags.fromJson({
        'feature.parent_fees': true,
        'sa.fees_module': true,
      });
      expect(flags.fees, isTrue);
    });

    test('fees=false when SA disables fees_module even if plan allows', () {
      final flags = _FeatureFlags.fromJson({
        'feature.parent_fees': true,
        'sa.fees_module': false,
      });
      expect(flags.fees, isFalse);
    });

    test('transport=false when plan disables it', () {
      final flags = _FeatureFlags.fromJson({
        'feature.transport': false,
        'sa.transport_module': true,
      });
      expect(flags.transport, isFalse);
    });

    test('transport=true only when both layers true', () {
      final flags = _FeatureFlags.fromJson({
        'feature.transport': true,
        'sa.transport_module': true,
      });
      expect(flags.transport, isTrue);
    });

    test('circulars default true when missing', () {
      final flags = _FeatureFlags.fromJson({});
      expect(flags.circulars, isTrue);
    });

    test('announcements=false hides forum tile', () {
      final flags = _FeatureFlags.fromJson({'feature.announcements': false});
      expect(flags.announcements, isFalse);
    });
  });

  // ── OTHERS section visibility ───────────────────────────────────────────────

  group('OTHERS section empty-state logic', () {
    List<String> otherTiles(bool transportEnabled) =>
        [if (transportEnabled) 'Transport'];

    test('transport disabled → OTHERS section has no tiles → section hidden', () {
      expect(otherTiles(false).isEmpty, isTrue);
    });

    test('transport enabled → OTHERS section has tiles → section shown', () {
      expect(otherTiles(true).isNotEmpty, isTrue);
      expect(otherTiles(true), contains('Transport'));
    });
  });

  // ── PARENT CORNER section ───────────────────────────────────────────────────

  group('PARENT CORNER tile gating', () {
    List<String> parentCornerTiles(bool feesEnabled) =>
        [if (feesEnabled) 'Fees', 'Attender'];

    test('fees disabled → only Attender shown', () {
      final tiles = parentCornerTiles(false);
      expect(tiles, ['Attender']);
      expect(tiles.contains('Fees'), isFalse);
    });

    test('fees enabled → both shown', () {
      final tiles = parentCornerTiles(true);
      expect(tiles, containsAll(['Fees', 'Attender']));
    });
  });
}
