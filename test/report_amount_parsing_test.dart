import 'package:flutter_test/flutter_test.dart';

num parseAmount(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v;
  if (v is String) {
    return num.tryParse(v.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
  }
  if (v is Map) {
    final inner = v['amount'] ??
        v['total'] ??
        v['totalAmount'] ??
        v['value'] ??
        v['billAmount'] ??
        v['paid'] ??
        v['totalContractorExpense'] ??
        v['totalIncentiveExpenses'];
    if (inner != null && inner is! Map) {
      return parseAmount(inner);
    }
    return 0;
  }
  if (v is List) {
    num sum = 0;
    for (final item in v) {
      sum += parseAmount(item);
    }
    return sum;
  }
  return 0;
}

void main() {
  group('Report Amount Parsing Tests', () {
    test('Handles null and primitive numbers', () {
      expect(parseAmount(null), 0);
      expect(parseAmount(0), 0);
      expect(parseAmount(150), 150);
      expect(parseAmount(250.75), 250.75);
    });

    test('Handles formatted and unformatted strings', () {
      expect(parseAmount('500'), 500);
      expect(parseAmount('₹ 1,250.50'), 1250.50);
      expect(parseAmount('12,000'), 12000);
      expect(parseAmount('invalid'), 0);
    });

    test('Handles Map payloads (LinkedMap<String, dynamic>)', () {
      final mapWithAmount = {'amount': 450};
      final mapWithTotal = {'totalAmount': '1,200.00'};
      final mapWithIncentive = {'totalIncentiveExpenses': 850};
      final nestedMap = {
        'value': 300,
      };

      expect(parseAmount(mapWithAmount), 450);
      expect(parseAmount(mapWithTotal), 1200);
      expect(parseAmount(mapWithIncentive), 850);
      expect(parseAmount(nestedMap), 300);
    });

    test('Handles List of amount items', () {
      final list = [
        {'amount': 100},
        {'amount': '250'},
        50,
      ];
      expect(parseAmount(list), 400);
    });

    test('Handles unexpected Map types without throwing TypeError', () {
      final complexDocData = {
        'unrelatedField': 'some text',
        'nested': {'deep': true},
      };
      expect(parseAmount(complexDocData), 0);
    });
  });
}
