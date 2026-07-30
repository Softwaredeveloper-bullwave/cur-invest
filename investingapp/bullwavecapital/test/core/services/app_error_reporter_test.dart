import 'package:bullwave_invest/core/services/app_error_reporter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sanitizes personal and secret values', () {
    final message = AppErrorReporter.sanitize(
      'User 9876543210 person@example.com ABCDE1234F failed',
    );
    expect(message, isNot(contains('9876543210')));
    expect(message, isNot(contains('person@example.com')));
    expect(message, isNot(contains('ABCDE1234F')));

    final context = AppErrorReporter.sanitizeMap({
      'password': 'secret',
      'accessToken': 'token',
      'screen': 'wallet',
    });
    expect(context['password'], '[redacted]');
    expect(context['accessToken'], '[redacted]');
    expect(context['screen'], 'wallet');
  });

  test('deduplicates fingerprints for one minute', () {
    final reporter = AppErrorReporter.instance;
    final now = DateTime(2026, 7, 28, 12);
    expect(reporter.registerFingerprint('unique-test-error', now), isTrue);
    expect(
      reporter.registerFingerprint(
        'unique-test-error',
        now.add(const Duration(seconds: 30)),
      ),
      isFalse,
    );
    expect(
      reporter.registerFingerprint(
        'unique-test-error',
        now.add(const Duration(minutes: 2)),
      ),
      isTrue,
    );
  });

  test('skips the reporting endpoint to prevent loops', () {
    expect(AppErrorReporter.isReportingLocation('/client-errors/'), isTrue);
    expect(AppErrorReporter.isReportingLocation('/wallet/'), isFalse);
  });
}
