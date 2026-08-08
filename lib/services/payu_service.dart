import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

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
    this.surl = 'https://api.payu.in/public/#/success',
    this.furl = 'https://api.payu.in/public/#/failure',
    this.isSandbox = true,
  });

  String get payUrl => isSandbox
      ? 'https://test.payu.in/_payment'
      : 'https://secure.payu.in/_payment';
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
  // Set your PayU Merchant ID, Merchant Key and Merchant Salt here
  // For Production Mode: Set isProduction = true and provide live credentials
  // For Sandbox/Testing: Set isProduction = false (uses test merchant ID, key & salt)
  static bool isProduction = false; 

  static String productionMerchantId = 'YOUR_LIVE_MERCHANT_ID';
  static String productionMerchantKey = 'YOUR_LIVE_MERCHANT_KEY';
  static String productionMerchantSalt = 'YOUR_LIVE_MERCHANT_SALT';

  static String testMerchantId = '9193759'; // Merchant Test ID
  static String testMerchantKey = 'GZrAha'; // Default Test Key
  static String testMerchantSalt = 'xpfwrDGBXY4sR5Y8O4xU8OB0seurgJMi'; // Default Test Salt

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
