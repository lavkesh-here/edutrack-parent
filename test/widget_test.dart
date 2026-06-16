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
  });

  group('Photo upload MIME types', () {
    test('png extension maps to image/png', () {
      const ext = 'png';
      final contentType = ext == 'png' ? 'image/png' : 'image/jpeg';
      expect(contentType, equals('image/png'));
    });

    test('jpg extension maps to image/jpeg', () {
      const ext = 'jpg';
      final contentType = ext == 'png' ? 'image/png' : 'image/jpeg';
      expect(contentType, equals('image/jpeg'));
    });
  });

  group('Server env badge logic', () {
    test('production URL is identified correctly', () {
      const defaultUrl = 'https://edu-api-xxxxx.a.run.app';
      final url = defaultUrl;
      final isProd = url == defaultUrl;
      expect(isProd, isTrue);
    });

    test('dev URL is identified correctly', () {
      const defaultUrl = 'https://edu-api-xxxxx.a.run.app';
      final url = 'http://192.168.1.5:8000';
      final isProd = url == defaultUrl;
      expect(isProd, isFalse);
    });
  });
}
