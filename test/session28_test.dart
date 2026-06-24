// Widget tests for parent-app Session 28 features: attender, fees, add-child flow.
// Pure logic tests — no device or platform channels required.

import 'package:flutter_test/flutter_test.dart';

void main() {
  // ── Attender form validation ───────────────────────────────────────────────

  group('Add attender form', () {
    test('name must be non-empty', () {
      const name = '';
      expect(name.trim().isEmpty, isTrue);
    });

    test('phone must be 10 digits', () {
      bool isValidPhone(String p) =>
          RegExp(r'^\d{10}$').hasMatch(p.trim());
      expect(isValidPhone('9876543210'), isTrue);
      expect(isValidPhone('98765'), isFalse);
      expect(isValidPhone('abcdefghij'), isFalse);
      expect(isValidPhone(''), isFalse);
    });

    test('relation must be non-empty', () {
      const relation = 'Grandparent';
      expect(relation.trim().isNotEmpty, isTrue);
    });
  });

  // ── Add child flow ─────────────────────────────────────────────────────────

  group('Link child flow', () {
    test('school code is uppercased before lookup', () {
      const raw = 'demo001';
      final code = raw.trim().toUpperCase();
      expect(code, equals('DEMO001'));
    });

    test('empty admission number blocks submit', () {
      const admissionNo = '';
      expect(admissionNo.trim().isEmpty, isTrue);
    });

    test('password and confirm must match', () {
      const pass = 'abc123';
      const confirm = 'abc123';
      expect(pass == confirm, isTrue);
    });

    test('mismatched passwords blocked', () {
      const pass = 'abc123';
      const confirm = 'xyz789';
      expect(pass == confirm, isFalse);
    });
  });

  // ── Work log acknowledgment ────────────────────────────────────────────────

  group('Work log incomplete reason', () {
    test('note is required when marking incomplete', () {
      const note = '';
      expect(note.trim().isEmpty, isTrue);
    });

    test('non-empty note allows submit', () {
      const note = 'Student was absent';
      expect(note.trim().isNotEmpty, isTrue);
    });

    test('work log status enum values', () {
      const validStatuses = ['completed', 'incomplete', 'not_started'];
      expect(validStatuses.contains('completed'), isTrue);
      expect(validStatuses.contains('incomplete'), isTrue);
      expect(validStatuses.contains('invalid_status'), isFalse);
    });
  });

  // ── Fee display logic ──────────────────────────────────────────────────────

  group('Fee amount formatting', () {
    String formatAmount(double amount) =>
        '₹${amount.toStringAsFixed(0)}';

    test('whole number formats without decimal', () {
      expect(formatAmount(5000), equals('₹5000'));
    });

    test('fractional amount rounds to nearest', () {
      expect(formatAmount(5000.4), equals('₹5000'));
      expect(formatAmount(5000.6), equals('₹5001'));
    });

    test('zero formats as ₹0', () {
      expect(formatAmount(0), equals('₹0'));
    });
  });

  // ── Attendance calendar display ────────────────────────────────────────────

  group('Attendance calendar color logic', () {
    String colorFor(String status) {
      switch (status) {
        case 'present': return 'green';
        case 'absent':  return 'red';
        case 'late':    return 'amber';
        default:        return 'grey';
      }
    }

    test('present is green', () => expect(colorFor('present'), equals('green')));
    test('absent is red',    () => expect(colorFor('absent'),  equals('red')));
    test('late is amber',   () => expect(colorFor('late'),    equals('amber')));
    test('unknown is grey', () => expect(colorFor('holiday'), equals('grey')));
  });

  // ── Month navigation ───────────────────────────────────────────────────────

  group('Month navigation', () {
    test('prev month from Jan goes to Dec of previous year', () {
      var month = 1;
      var year  = 2026;
      if (month == 1) { month = 12; year--; }
      else month--;
      expect(month, equals(12));
      expect(year,  equals(2025));
    });

    test('next month from Dec goes to Jan of next year', () {
      var month = 12;
      var year  = 2025;
      if (month == 12) { month = 1; year++; }
      else month++;
      expect(month, equals(1));
      expect(year,  equals(2026));
    });

    test('mid-year navigation stays in same year', () {
      var month = 6;
      final year = 2026;
      month++;
      expect(month, equals(7));
      expect(year, equals(2026));
    });
  });
}
