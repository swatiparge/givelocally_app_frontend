import 'package:flutter_test/flutter_test.dart';
import 'package:givelocally_app/utils/input_sanitizer.dart';

void main() {
  group('InputSanitizer', () {
    group('phone validation', () {
      test('valid phone number should pass', () {
        expect(InputSanitizer.isValidPhone('+919876543210'), true);
        expect(InputSanitizer.isValidPhone('+919998877665'), true);
      });

      test('invalid phone number should fail', () {
        expect(InputSanitizer.isValidPhone('+91987654321'), false);
        expect(InputSanitizer.isValidPhone('9876543210'), false);
        expect(InputSanitizer.isValidPhone('+1234567890'), false);
        expect(InputSanitizer.isValidPhone(''), false);
      });

      test('sanitize phone removes non-digits', () {
        expect(
          InputSanitizer.sanitizePhone('+91 98765 43210'),
          '+919876543210',
        );
        expect(
          InputSanitizer.sanitizePhone('+91-98765-43210'),
          '+919876543210',
        );
      });
    });

    group('name validation', () {
      test('valid name should pass', () {
        expect(InputSanitizer.isValidName('Rajesh'), true);
        expect(InputSanitizer.isValidName('John Doe'), true);
        expect(InputSanitizer.isValidName('Priya Sharma'), true);
      });

      test('invalid name should fail', () {
        expect(InputSanitizer.isValidName(''), false);
        expect(InputSanitizer.isValidName('J'), false);
      });

      test('name with special characters should fail', () {
        expect(InputSanitizer.isValidName('John@Doe'), false);
        expect(InputSanitizer.isValidName('John123'), false);
      });
    });

    group('text sanitization', () {
      test('removes HTML tags', () {
        expect(
          InputSanitizer.sanitizeText('<script>alert(1)</script>'),
          'alert(1)',
        );
        expect(InputSanitizer.sanitizeText('<b>Hello</b>'), 'Hello');
      });

      test('truncates long text', () {
        expect(InputSanitizer.truncate('Hello World', 8), 'Hello...');
        expect(InputSanitizer.truncate('Hi', 8), 'Hi');
      });

      test('cleans search query', () {
        expect(InputSanitizer.cleanSearchQuery('hello!@#world'), 'helloworld');
        expect(InputSanitizer.cleanSearchQuery('test  query'), 'test  query');
      });
    });
  });
}
