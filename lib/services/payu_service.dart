import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PayUParams {
  final String? merchantId;
  final String merchantKey;
  final String merchantSalt;
  final String txnid;
  final double amount;
  final String productInfo;
  final String firstName;
  final String email;
  final String phone;
  final String surl;
  final String furl;
  final bool isSandbox;

  PayUParams({
    this.merchantId,
    required this.merchantKey,
    required this.merchantSalt,
    required this.txnid,
    required this.amount,
    required this.productInfo,
    required this.firstName,
    required this.email,
    required this.phone,
    String? surl,
    String? furl,
    this.isSandbox = true,
  })  : surl = surl ?? dotenv.env['PAYU_SURL'] ?? 'https://api.payu.in/public/#/success',
        furl = furl ?? dotenv.env['PAYU_FURL'] ?? 'https://api.payu.in/public/#/failure';

  String get payUrl => isSandbox
      ? (dotenv.env['PAYU_TEST_PAY_URL'] ?? 'https://test.payu.in/_payment')
      : (dotenv.env['PAYU_PROD_PAY_URL'] ?? 'https://secure.payu.in/_payment');
}

class PayUResult {
  final bool isSuccess;
  final String txnid;
  final String? payuMoneyId;
  final String? errorMessage;
  final Map<String, String>? rawData;

  PayUResult({
    required this.isSuccess,
    required this.txnid,
    this.payuMoneyId,
    this.errorMessage,
    this.rawData,
  });
}

class PayUService {
  // Check environment from .env file (PAYU_ENVIRONMENT=sandbox or production)
  static bool get isProduction =>
      (dotenv.env['PAYU_ENVIRONMENT'] ?? 'sandbox').trim().toLowerCase() == 'production';

  static String get productionMerchantId =>
      dotenv.env['PAYU_PROD_MERCHANT_ID'] ?? 'YOUR_LIVE_MERCHANT_ID';
  static String get productionMerchantKey =>
      dotenv.env['PAYU_PROD_KEY'] ?? 'YOUR_LIVE_MERCHANT_KEY';
  static String get productionMerchantSalt =>
      dotenv.env['PAYU_PROD_SALT'] ?? 'YOUR_LIVE_MERCHANT_SALT';

  static String get testMerchantId =>
      dotenv.env['PAYU_TEST_MERCHANT_ID'] ?? '9193759'; // Merchant Test ID
  static String get testMerchantKey =>
      dotenv.env['PAYU_TEST_KEY'] ?? 'GZrAha'; // Test Key
  static String get testMerchantSalt =>
      dotenv.env['PAYU_TEST_SALT'] ?? 'xpfwrDGBXY4sR5Y8O4xU8OB0seurgJMi'; // Test Salt

  static String get activeMerchantId =>
      isProduction ? productionMerchantId : testMerchantId;

  static String get activeMerchantKey =>
      isProduction ? productionMerchantKey : testMerchantKey;

  static String get activeMerchantSalt =>
      isProduction ? productionMerchantSalt : testMerchantSalt;

  /// Helper to sanitize phone number for PayU (exact 10 digits)
  static String sanitizePhone(String rawPhone) {
    String clean = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.length > 10) {
      clean = clean.substring(clean.length - 10);
    }
    if (clean.length < 10) {
      clean = '9999999999';
    }
    return clean;
  }

  /// Helper to sanitize customer name for PayU
  static String sanitizeName(String rawName) {
    String clean = rawName.replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '').trim();
    if (clean.isEmpty) {
      clean = 'Customer';
    }
    return clean;
  }

  /// Generate SHA-512 Hash required by PayU
  /// Formula: sha512(key|txnid|amount|productinfo|firstname|email|udf1|udf2|udf3|udf4|udf5||||||salt)
  static String generateHash(PayUParams params) {
    final String amountStr = params.amount.toStringAsFixed(2);
    final String sanitizedFirstName = sanitizeName(params.firstName);
    final String sanitizedProductInfo = params.productInfo.replaceAll(RegExp(r'[^a-zA-Z0-9_\- ]'), '');

    final hashSequence =
        '${params.merchantKey}|${params.txnid}|$amountStr|$sanitizedProductInfo|$sanitizedFirstName|${params.email}|||||||||||${params.merchantSalt}';

    final bytes = utf8.encode(hashSequence);
    final digest = sha512.convert(bytes);
    final hash = digest.toString().toLowerCase();

    debugPrint('PayU Hash Sequence: $hashSequence');
    debugPrint('PayU Generated Hash: $hash');

    return hash;
  }

  /// Generate Form Data Map for PayU Hosted Payment Checkout
  static Map<String, String> buildPostData(PayUParams params) {
    final hash = generateHash(params);
    final String amountStr = params.amount.toStringAsFixed(2);
    final String sanitizedFirstName = sanitizeName(params.firstName);
    final String sanitizedProductInfo = params.productInfo.replaceAll(RegExp(r'[^a-zA-Z0-9_\- ]'), '');
    final String sanitizedPhone = sanitizePhone(params.phone);

    return {
      'key': params.merchantKey,
      'txnid': params.txnid,
      'amount': amountStr,
      'productinfo': sanitizedProductInfo,
      'firstname': sanitizedFirstName,
      'email': params.email,
      'phone': sanitizedPhone,
      'surl': params.surl,
      'furl': params.furl,
      'hash': hash,
      'service_provider': 'payu_paisa',
    };
  }

  /// Helper to generate unique transaction ID
  static String generateTxnId() {
    return 'PAYU_${DateTime.now().millisecondsSinceEpoch}';
  }
}
