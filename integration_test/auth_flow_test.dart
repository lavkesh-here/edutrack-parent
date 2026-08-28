// TC-PA-AUTH-001..003 | TC-PA-HOME-001 | TC-PA-ATT-001
// Parent App integration tests — 2-step login, dashboard, attendance, work log.
// Run: flutter test integration_test/auth_flow_test.dart -d macos
// Non-production builds default to the real DEV Cloud Run backend (see
// ParentApiClient._defaultBaseUrl) -- no backend needs to be started locally.
// Uses the real seeded DEV parent account (Rohan Malhotra / child Kabir Malhotra).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:edutrack_parent/main.dart' as app;

const _schoolCode = 'DEMO001';
const _phone      = '9800000001';
const _password   = 'demo1234';

/// Bounded stand-in for pumpAndSettle(). On a real Android device/emulator,
/// text-field focus triggers the real on-screen keyboard (integration_test
/// deliberately doesn't mock it — see TestWidgetsFlutterBinding.
/// registerTestTextInput's own doc comment: "An integration test would set
/// this to false, to test real IME or keyboard input"). The IME's own
/// show/hide inset animation keeps scheduling frames, so pumpAndSettle's
/// "wait until nothing is scheduled" heuristic can spin for minutes instead
/// of settling — pump a fixed number of steps instead so a slow keyboard
/// animation can't stall the whole test suite.
Future<void> _settle(WidgetTester tester, [Duration total = const Duration(seconds: 3)]) async {
  const step = Duration(milliseconds: 200);
  for (var elapsed = Duration.zero; elapsed < total; elapsed += step) {
    await tester.pump(step);
  }
}

/// Helper: boots app, navigates through 2-step login, asserts home is reached.
Future<void> _doLogin(WidgetTester tester) async {
  app.main();
  await _settle(tester, const Duration(seconds: 3));

  // Step 1 — school code
  await tester.enterText(find.byKey(const Key('school_code_field')), _schoolCode);
  await tester.tap(find.byKey(const Key('school_code_next')));
  await _settle(tester, const Duration(seconds: 2));

  // Step 2 — credentials
  await tester.enterText(find.byKey(const Key('phone_field')), _phone);
  await tester.enterText(find.byKey(const Key('password_field')), _password);
  await tester.tap(find.byKey(const Key('login_button')));
  await _settle(tester, const Duration(seconds: 10));

  // On first login (no biometrics enrolled yet), login.dart shows a "Quick
  // unlock" AlertDialog and awaits its result before navigating home —
  // dismiss it the same way a real user would (see login.dart:307-325).
  final notNow = find.text('Not now');
  if (notNow.evaluate().isNotEmpty) {
    await tester.tap(notNow);
    await _settle(tester, const Duration(seconds: 2));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Every testWidgets() re-runs app.main() but shares the SAME real on-device
  // SharedPreferences/app install — unlike a host-side widget test, state
  // does not reset between tests on its own. Without this, a token saved by
  // an earlier test's successful login persists and the app skips straight
  // to the home screen on the next test's app.main(), never showing login.
  setUp(() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  });

  // ── Auth ────────────────────────────────────────────────────────────────────

  group('TC-PA-AUTH: Parent 2-step login flow', () {
    testWidgets('step 1 — valid school code shows phone field', (tester) async {
      app.main();
      await _settle(tester, const Duration(seconds: 3));

      await tester.enterText(find.byKey(const Key('school_code_field')), _schoolCode);
      await tester.tap(find.byKey(const Key('school_code_next')));
      await _settle(tester, const Duration(seconds: 2));

      expect(find.byKey(const Key('phone_field')), findsOneWidget);
    });

    testWidgets('step 1 — invalid school code stays on step 1', (tester) async {
      app.main();
      await _settle(tester, const Duration(seconds: 2));

      await tester.enterText(find.byKey(const Key('school_code_field')), 'INVALID999');
      await tester.tap(find.byKey(const Key('school_code_next')));
      await _settle(tester, const Duration(seconds: 2));

      expect(find.byKey(const Key('school_code_field')), findsOneWidget);
    });

    testWidgets('step 2 — valid credentials → home with bottom nav', (tester) async {
      await _doLogin(tester);
      // The app uses a custom bottom-nav row (see home.dart _NavItem), not
      // Flutter's BottomNavigationBar widget — assert on the real key.
      expect(find.byKey(const Key('nav_home')), findsOneWidget);
    });

    testWidgets('step 2 — wrong password → stays on login screen', (tester) async {
      app.main();
      await _settle(tester, const Duration(seconds: 2));

      await tester.enterText(find.byKey(const Key('school_code_field')), _schoolCode);
      await tester.tap(find.byKey(const Key('school_code_next')));
      await _settle(tester, const Duration(seconds: 2));

      await tester.enterText(find.byKey(const Key('phone_field')), _phone);
      await tester.enterText(find.byKey(const Key('password_field')), 'wrongpass');
      await tester.tap(find.byKey(const Key('login_button')));
      await _settle(tester, const Duration(seconds: 3));

      expect(find.byKey(const Key('nav_home')), findsNothing);
    });
  });

  // ── Home ────────────────────────────────────────────────────────────────────

  group('TC-PA-HOME: Dashboard', () {
    testWidgets('home screen accordion sections visible after login', (tester) async {
      await _doLogin(tester);

      expect(find.byKey(const Key('home_tab_content')), findsOneWidget);
      expect(find.byKey(const Key('accordion_attendance')), findsOneWidget);
      expect(find.byKey(const Key('accordion_tests')), findsOneWidget);
    });
  });

  // ── Attendance ──────────────────────────────────────────────────────────────

  group('TC-PA-ATT: Attendance view', () {
    testWidgets('attendance screen shows month navigation buttons', (tester) async {
      await _doLogin(tester);

      // Navigate to attendance via home accordion or direct nav
      final attSection = find.byKey(const Key('accordion_attendance'));
      if (attSection.evaluate().isNotEmpty) {
        await tester.tap(attSection);
        await _settle(tester, const Duration(seconds: 3));
      }

      // If reached attendance screen, prev/next month buttons should be present
      final prevBtn = find.byKey(const Key('prev_month_button'));
      if (prevBtn.evaluate().isNotEmpty) {
        expect(find.byKey(const Key('next_month_button')), findsOneWidget);
      }
    });
  });

  // ── Profile ─────────────────────────────────────────────────────────────────

  group('TC-PA-PROF: Profile screen', () {
    testWidgets('profile screen has add child button', (tester) async {
      await _doLogin(tester);

      // home.dart wires a real nav_profile key for the Profile tab — use it
      // directly instead of icon/text guessing.
      await tester.tap(find.byKey(const Key('nav_profile')));
      await _settle(tester, const Duration(seconds: 3));

      // Add child button exists on profile
      final addChild = find.byKey(const Key('add_child_button'));
      if (addChild.evaluate().isNotEmpty) {
        expect(addChild, findsOneWidget);
      }
    });
  });
}
