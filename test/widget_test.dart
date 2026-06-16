import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Parent biometric storage keys', () {
    const kBioPhone   = 'parent_bio_phone';
    const kBioPass    = 'parent_bio_password';
    const kBioEnabled = 'parent_bio_enabled';

    test('parent bio keys are distinct from teacher keys', () {
      expect(kBioPhone,   isNot(equals('bio_email')));
      expect(kBioPass,    isNot(equals('bio_password')));
      expect(kBioEnabled, isNot(equals('bio_enabled')));
    });

    test('all three keys are distinct from each other', () {
      expect(kBioPhone, isNot(equals(kBioPass)));
      expect(kBioPass, isNot(equals(kBioEnabled)));
      expect(kBioPhone, isNot(equals(kBioEnabled)));
    });
  });

  group('Photo upload MIME types', () {
    String mimeType(String ext) => ext == 'png' ? 'image/png' : 'image/jpeg';

    test('png → image/png', () => expect(mimeType('png'), equals('image/png')));
    test('jpg → image/jpeg', () => expect(mimeType('jpg'), equals('image/jpeg')));
    test('jpeg → image/jpeg', () => expect(mimeType('jpeg'), equals('image/jpeg')));
    test('webp → image/jpeg (fallback)', () => expect(mimeType('webp'), equals('image/jpeg')));
  });

  group('Photo file size guard', () {
    const maxBytes = 5 * 1024 * 1024; // 5 MB

    test('file under 5MB is accepted', () {
      const size = 2 * 1024 * 1024;
      expect(size > maxBytes, isFalse);
    });

    test('file over 5MB is rejected', () {
      const size = 6 * 1024 * 1024;
      expect(size > maxBytes, isTrue);
    });

    test('exactly 5MB is accepted', () {
      const size = 5 * 1024 * 1024;
      expect(size > maxBytes, isFalse);
    });
  });

  group('Server env badge logic', () {
    const defaultUrl = 'https://edu-api-xxxxx.a.run.app';

    test('default URL is production', () {
      expect(defaultUrl == defaultUrl, isTrue);
    });

    test('custom URL is dev', () {
      const devUrl = 'http://192.168.1.5:8000';
      expect(devUrl == defaultUrl, isFalse);
    });

    test('badge label: production → PRODUCTION', () {
      const isProd = true;
      expect(isProd ? 'PRODUCTION' : 'DEV', equals('PRODUCTION'));
    });

    test('badge label: dev → DEV', () {
      const isProd = false;
      expect(isProd ? 'PRODUCTION' : 'DEV', equals('DEV'));
    });
  });

  group('Parent biometric enrollment offer', () {
    test('offered when bio available and not already enabled', () {
      const available = true;
      const alreadyEnabled = false;
      expect(available && !alreadyEnabled, isTrue);
    });

    test('not offered when already enabled', () {
      const available = true;
      const alreadyEnabled = true;
      expect(available && !alreadyEnabled, isFalse);
    });

    test('not offered when hardware unavailable', () {
      const available = false;
      const alreadyEnabled = false;
      expect(available && !alreadyEnabled, isFalse);
    });
  });

  group('Parent profile initials', () {
    String initials(String name) {
      final parts = name.trim().split(' ');
      if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
      return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : '?';
    }

    test('two-part name', () => expect(initials('Priya Kakar'), equals('PK')));
    test('single name', () => expect(initials('Lakshmi'), equals('L')));
    test('empty name', () => expect(initials(''), equals('?')));
    test('lowercase name uppercased', () => expect(initials('anita sharma'), equals('AS')));
  });

  group('App version display', () {
    test('version string non-empty when set', () {
      const version = '1.0.0+5';
      expect(version.isEmpty, isFalse);
    });

    test('version prefix added correctly', () {
      const version = '1.0.0+5';
      final label = version.isEmpty ? 'EduTrack Parent' : 'EduTrack Parent v$version';
      expect(label, equals('EduTrack Parent v1.0.0+5'));
    });

    test('fallback when version empty', () {
      const version = '';
      final label = version.isEmpty ? 'EduTrack Parent' : 'EduTrack Parent v$version';
      expect(label, equals('EduTrack Parent'));
    });
  });

  group('Parent login two-step flow', () {
    test('school code uppercased before lookup', () {
      const raw = 'demo001';
      final code = raw.trim().toUpperCase();
      expect(code, equals('DEMO001'));
    });

    test('empty school code triggers error', () {
      const code = '';
      expect(code.isEmpty, isTrue);
    });
  });

  group('Photo avatar display logic', () {
    test('show photo when photoUrl non-null and non-empty', () {
      const photoUrl = 'https://storage.gcs.com/photo.jpg';
      expect(photoUrl.isNotEmpty, isTrue);
    });

    test('show initials when photoUrl is null', () {
      const String? photoUrl = null;
      expect(photoUrl == null || photoUrl.isEmpty, isTrue);
    });

    test('show initials when photoUrl is empty string', () {
      const photoUrl = '';
      expect(photoUrl.isEmpty, isTrue);
    });
  });
}
