import 'package:flutter_test/flutter_test.dart';
import 'package:ebricks/services/firestore_service.dart';

void main() {
  group('Username Caching & Quick Validation Tests', () {
    test('isUsernameCachedAsTaken returns false for unknown usernames', () {
      expect(FirestoreService.isUsernameCachedAsTaken('completely_random_user_99999'), isFalse);
      expect(FirestoreService.isUsernameCachedAsTaken(''), isFalse);
      expect(FirestoreService.isUsernameCachedAsTaken('   '), isFalse);
    });

    test('recordTakenUsername caches usernames in a case-insensitive manner', () {
      FirestoreService.recordTakenUsername('Sharan123');

      // Exact case
      expect(FirestoreService.isUsernameCachedAsTaken('Sharan123'), isTrue);
      // All lowercase
      expect(FirestoreService.isUsernameCachedAsTaken('sharan123'), isTrue);
      // All uppercase
      expect(FirestoreService.isUsernameCachedAsTaken('SHARAN123'), isTrue);
      // Mixed casing
      expect(FirestoreService.isUsernameCachedAsTaken('sHaRaN123'), isTrue);
      // With leading/trailing whitespace
      expect(FirestoreService.isUsernameCachedAsTaken('  Sharan123  '), isTrue);
    });

    test('Multiple usernames can be recorded and checked without interference', () {
      FirestoreService.recordTakenUsername('ManagerAlpha');
      FirestoreService.recordTakenUsername('SupervisorBeta');

      expect(FirestoreService.isUsernameCachedAsTaken('manageralpha'), isTrue);
      expect(FirestoreService.isUsernameCachedAsTaken('supervisorbeta'), isTrue);
      expect(FirestoreService.isUsernameCachedAsTaken('supervisoralpha'), isFalse);
    });
  });
}
