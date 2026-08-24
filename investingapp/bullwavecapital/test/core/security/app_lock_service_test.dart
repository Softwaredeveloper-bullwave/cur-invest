import 'package:flutter_test/flutter_test.dart';

import 'package:bullwave_invest/core/security/app_lock_service.dart';

void main() {
  group('AppLockService', () {
    test('pinLength is four digits', () {
      expect(AppLockService.pinLength, 4);
      expect(AppLockService.maxAttempts, 5);
    });

    test('setupMpin rejects invalid length', () async {
      expect(
        () => AppLockService.setupMpin(pin: '12', userId: 'u1'),
        throwsA(isA<AppLockException>()),
      );
    });

    test('hash is deterministic for same salt and pin', () {
      final first = AppLockService.hashPinForTest('1234', 'salt-a');
      final second = AppLockService.hashPinForTest('1234', 'salt-a');
      final different = AppLockService.hashPinForTest('5678', 'salt-a');

      expect(first, second);
      expect(first, isNot(different));
    });
  });
}
