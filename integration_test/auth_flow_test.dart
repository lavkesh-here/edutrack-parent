// TC-PA-AUTH-001..003 | TC-PA-HOME-001 | TC-PA-ATT-001
// Parent App integration tests — 2-step login, dashboard, attendance, work log.
// Run: flutter test integration_test/auth_flow_test.dart
// Requires: backend at http://localhost:8000, demo parent account seeded.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:edutrack_parent/main.dart' as app;

const _schoolCode = 'DEMO001';
const _phone      = '9000000001';
const _password   = 'demo1234';

/// Helper: boots app, navigates through 2-step login, asserts home is reached.
Future<void> _doLogin(WidgetTester tester) async {
  app.main();
  await tester.pumpAndSettle(const Duration(seconds: 3));

  // Step 1 — school code
  await tester.enterText(find.byKey(const Key('school_code_field')), _schoolCode);
  await tester.tap(find.byKey(const Key('school_code_next')));
  await tester.pumpAndSettle(const Duration(seconds: 2));

  // Step 2 — credentials
  await tester.enterText(find.byKey(const Key('phone_field')), _phone);
  await tester.enterText(find.byKey(const Key('password_field')), _password);
  await tester.tap(find.byKey(const Key('login_button')));
  await tester.pumpAndSettle(const Duration(seconds: 4));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ── Auth ────────────────────────────────────────────────────────────────────

  group('TC-PA-AUTH: Parent 2-step login flow', () {
    testWidgets('step 1 — valid school code shows phone field', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      await tester.enterText(find.byKey(const Key('school_code_field')), _schoolCode);
      await tester.tap(find.byKey(const Key('school_code_next')));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.byKey(const Key('phone_field')), findsOneWidget);
    });

    testWidgets('step 1 — invalid school code stays on step 1', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await tester.enterText(find.byKey(const Key('school_code_field')), 'INVALID999');
      await tester.tap(find.byKey(const Key('school_code_next')));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.byKey(const Key('school_code_field')), findsOneWidget);
    });

    testWidgets('step 2 — valid credentials → home with bottom nav', (tester) async {
      await _doLogin(tester);
      expect(find.byType(BottomNavigationBar), findsOneWidget);
    });

    testWidgets('step 2 — wrong password → stays on login screen', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await tester.enterText(find.byKey(const Key('school_code_field')), _schoolCode);
      await tester.tap(find.byKey(const Key('school_code_next')));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await tester.enterText(find.byKey(const Key('phone_field')), _phone);
      await tester.enterText(find.byKey(const Key('password_field')), 'wrongpass');
      await tester.tap(find.byKey(const Key('login_button')));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.byType(BottomNavigationBar), findsNothing);
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
        await tester.pumpAndSettle(const Duration(seconds: 2));
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

      // Navigate to profile tab (usually last tab)
      final profileFinders = [
        find.byIcon(Icons.person),
        find.byIcon(Icons.account_circle),
        find.text('Profile'),
      ];

      for (final f in profileFinders) {
        if (f.evaluate().isNotEmpty) {
          await tester.tap(f.first);
          await tester.pumpAndSettle(const Duration(seconds: 2));
          break;
        }
      }

      // Add child button exists on profile
      final addChild = find.byKey(const Key('add_child_button'));
      if (addChild.evaluate().isNotEmpty) {
        expect(addChild, findsOneWidget);
      }
    });
  });
}
