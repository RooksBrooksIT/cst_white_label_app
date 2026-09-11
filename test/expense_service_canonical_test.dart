import 'package:flutter_test/flutter_test.dart';
import 'package:ebricks/services/expense_service.dart';

void main() {
  group('ExpenseService Canonical Site Document ID Formatting Tests', () {
    test('Formats Site Code + Site Name correctly (e.g. ST001 + Abinesh House -> ST001_AbineshHouse)', () {
      final docId = ExpenseService.formatCanonicalSiteDocId('ST001', 'Abinesh House');
      expect(docId, equals('ST001_AbineshHouse'));
    });

    test('Handles extra spaces in site code and site name', () {
      final docId = ExpenseService.formatCanonicalSiteDocId('  ST001  ', '  Abinesh   House  ');
      expect(docId, equals('ST001_AbineshHouse'));
    });

    test('Does not duplicate if site code already contains site name', () {
      final docId = ExpenseService.formatCanonicalSiteDocId('ST001_AbineshHouse', 'Abinesh House');
      expect(docId, equals('ST001_AbineshHouse'));
    });

    test('Handles already formatted doc ID in site code', () {
      final docId = ExpenseService.formatCanonicalSiteDocId('ST001_AbineshHouse', '');
      expect(docId, equals('ST001_AbineshHouse'));
    });

    test('Handles multiple words in site name without whitespace in output', () {
      final docId = ExpenseService.formatCanonicalSiteDocId('ST042', 'Green Valley Villa Phase 2');
      expect(docId, equals('ST042_GreenValleyVillaPhase2'));
    });

    test('formatCanonicalSiteId handles existing Code_Name format', () {
      final formatted = ExpenseService.formatCanonicalSiteId(rawId: 'ST001_AbineshHouse');
      expect(formatted, equals('ST001_AbineshHouse'));
    });

    test('formatCanonicalSiteId handles raw ID and site name', () {
      final formatted = ExpenseService.formatCanonicalSiteId(rawId: 'ST001', siteName: 'Abinesh House');
      expect(formatted, equals('ST001_AbineshHouse'));
    });

    test('sanitizeSiteIds filters out bare site name when canonical ID exists', () {
      final rawList = ['Abinesh House', 'ST001_AbineshHouse', 'ST002_SampleSite'];
      final sanitized = ExpenseService.sanitizeSiteIds(rawList);
      expect(sanitized, equals(['ST001_AbineshHouse', 'ST002_SampleSite']));
      expect(sanitized.contains('Abinesh House'), isFalse);
    });

    test('sanitizeSiteIds filters out multiple variants of bare site name and uninitialized', () {
      final rawList = [
        'Abinesh House',
        'AbineshHouse',
        'ST001_AbineshHouse',
        'uninitialized',
        '',
        '   ',
        'ST002_Villa',
      ];
      final sanitized = ExpenseService.sanitizeSiteIds(rawList);
      expect(sanitized, equals(['ST001_AbineshHouse', 'ST002_Villa']));
      expect(sanitized.contains('Abinesh House'), isFalse);
      expect(sanitized.contains('AbineshHouse'), isFalse);
      expect(sanitized.contains('uninitialized'), isFalse);
    });

    test('sanitizeSiteIds leaves standalone site ID intact if no canonical exists', () {
      final rawList = ['CustomSite', 'ST003_NewBuilding'];
      final sanitized = ExpenseService.sanitizeSiteIds(rawList);
      expect(sanitized, equals(['CustomSite', 'ST003_NewBuilding']));
    });

    test('formatCanonicalSiteId standardizes PR001_AbineshHouse to ST001_AbineshHouse', () {
      final formatted = ExpenseService.formatCanonicalSiteId(rawId: 'PR001_AbineshHouse');
      expect(formatted, equals('ST001_AbineshHouse'));
    });

    test('formatCanonicalSiteDocId converts PR project code to ST site code', () {
      final formatted = ExpenseService.formatCanonicalSiteDocId('PR001', 'Abinesh House');
      expect(formatted, equals('ST001_AbineshHouse'));
    });

    test('sanitizeSiteIds removes PR001_AbineshHouse duplicate and keeps only ST001_AbineshHouse', () {
      final rawList = ['PR001_AbineshHouse', 'ST001_AbineshHouse'];
      final sanitized = ExpenseService.sanitizeSiteIds(rawList);
      expect(sanitized, equals(['ST001_AbineshHouse']));
      expect(sanitized.contains('PR001_AbineshHouse'), isFalse);
    });

    test('sanitizeSiteIds converts standalone PR001_AbineshHouse and bare name to ST001_AbineshHouse', () {
      final rawList = ['PR001_AbineshHouse', 'Abinesh House'];
      final sanitized = ExpenseService.sanitizeSiteIds(rawList);
      expect(sanitized, equals(['ST001_AbineshHouse']));
      expect(sanitized.contains('PR001_AbineshHouse'), isFalse);
      expect(sanitized.contains('Abinesh House'), isFalse);
    });
  });
}

