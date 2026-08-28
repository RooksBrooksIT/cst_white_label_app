import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';


class PayUParams {
  static const String defaultCallbackUrl =
      'https://us-central1-cst-whitelabel-app.cloudfunctions.net/payuWebhook';
  static const String defaultSuccessUrl =
      'https://us-central1-cst-whitelabel-app.cloudfunctions.net/payuWebhook';
  static const String defaultFailureUrl =
      'https://us-central1-cst-whitelabel-app.cloudfunctions.net/payuWebhook';

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
  final String? pg;
  final String? bankcode;

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
    bool? isSandbox,
    this.pg,
    this.bankcode,
  })  : isSandbox = isSandbox ?? !PayUService.isProduction,
        surl = surl ??
            dotenv.env['PAYU_SURL'] ??
            defaultSuccessUrl,
        furl = furl ??
            dotenv.env['PAYU_FURL'] ??
            defaultFailureUrl;

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
      dotenv.env['PAYU_PROD_MERCHANT_ID'] ?? '13573851';
  static String get productionMerchantKey =>
      dotenv.env['PAYU_PROD_KEY'] ?? 'a912BZ';
  static String get productionMerchantSalt =>
      dotenv.env['PAYU_PROD_SALT'] ?? 'jgo9fpvFX8DO2QtQDaWJHvz4JByS8ytC';

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

  /// Helper to sanitize product info for PayU
  static String sanitizeProductInfo(String rawInfo) {
    String clean = rawInfo.replaceAll(RegExp(r'[^a-zA-Z0-9_\- ]'), '').trim();
    if (clean.isEmpty) {
      clean = 'Subscription';
    }
    return clean;
  }

  /// Helper to sanitize customer email for PayU
  static String sanitizeEmail(String rawEmail) {
    String clean = rawEmail.trim().toLowerCase();
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(clean)) {
      clean = 'customer@example.com';
    }
    return clean;
  }

  /// Generate SHA-512 Hash required by PayU
  /// Formula: sha512(key|txnid|amount|productinfo|firstname|email|udf1|udf2|udf3|udf4|udf5||||||salt)
  static String generateHash(PayUParams params) {
    final String amountStr = params.amount.toStringAsFixed(2);
    final String sanitizedFirstName = sanitizeName(params.firstName);
    final String sanitizedProductInfo = sanitizeProductInfo(params.productInfo);
    final String sanitizedEmail = sanitizeEmail(params.email);

    final hashSequence =
        '${params.merchantKey}|${params.txnid}|$amountStr|$sanitizedProductInfo|$sanitizedFirstName|$sanitizedEmail|||||||||||${params.merchantSalt}';

    final bytes = utf8.encode(hashSequence);
    final digest = sha512.convert(bytes);
    final hash = digest.toString().toLowerCase();

    debugPrint('PayU Request Hash Sequence: $hashSequence');
    debugPrint('PayU Generated Request Hash: $hash');

    return hash;
  }

  /// Generate SHA-512 Hash for PayU Response Verification
  /// Formula: sha512(salt|status||||||udf5|udf4|udf3|udf2|udf1|email|firstname|productinfo|amount|txnid|key)
  static String generateResponseHash({
    required String merchantSalt,
    required String status,
    required String email,
    required String firstName,
    required String productInfo,
    required double amount,
    required String txnid,
    required String merchantKey,
    String udf1 = '',
    String udf2 = '',
    String udf3 = '',
    String udf4 = '',
    String udf5 = '',
    String? additionalCharges,
  }) {
    final amountStr = amount.toStringAsFixed(2);
    final cleanFirstName = sanitizeName(firstName);
    final cleanProductInfo = sanitizeProductInfo(productInfo);
    final cleanEmail = sanitizeEmail(email);
    final cleanStatus = status.toLowerCase();

    String hashSequence =
        '$merchantSalt|$cleanStatus||||||$udf5|$udf4|$udf3|$udf2|$udf1|$cleanEmail|$cleanFirstName|$cleanProductInfo|$amountStr|$txnid|$merchantKey';

    if (additionalCharges != null && additionalCharges.isNotEmpty) {
      hashSequence = '$additionalCharges|$hashSequence';
    }

    final bytes = utf8.encode(hashSequence);
    final digest = sha512.convert(bytes);
    final hash = digest.toString().toLowerCase();

    debugPrint('PayU Response Hash Sequence: $hashSequence');
    debugPrint('PayU Generated Response Hash: $hash');

    return hash;
  }

  /// Helper to build a complete test response payload with signature hash for Sandbox testing
  static Map<String, String> createTestResponseData({
    required PayUParams params,
    bool isSuccess = true,
  }) {
    final String status = isSuccess ? 'success' : 'failure';
    final String payuMoneyId = 'TEST_MIH_${DateTime.now().millisecondsSinceEpoch}';
    final String bankRefNo = 'TEST_BANK_REF_${DateTime.now().millisecondsSinceEpoch}';
    final String amountStr = params.amount.toStringAsFixed(2);

    final String hash = generateResponseHash(
      merchantSalt: params.merchantSalt,
      status: status,
      email: params.email,
      firstName: params.firstName,
      productInfo: params.productInfo,
      amount: params.amount,
      txnid: params.txnid,
      merchantKey: params.merchantKey,
    );

    return {
      'key': params.merchantKey,
      'txnid': params.txnid,
      'amount': amountStr,
      'productinfo': sanitizeProductInfo(params.productInfo),
      'firstname': sanitizeName(params.firstName),
      'email': sanitizeEmail(params.email),
      'status': status,
      'hash': hash,
      'mihpayid': payuMoneyId,
      'payuMoneyId': payuMoneyId,
      'bank_ref_no': bankRefNo,
      'mode': params.pg ?? 'UPI',
      'PG_TYPE': params.bankcode ?? 'INTENT',
      'error_Message': isSuccess ? 'No Error' : 'Test payment cancelled by user',
    };
  }

  /// Generate Form Data Map for PayU Hosted Payment Checkout synchronously (local)
  static Map<String, String> buildPostData(PayUParams params) {
    final hash = generateHash(params);
    final String amountStr = params.amount.toStringAsFixed(2);
    final String sanitizedFirstName = sanitizeName(params.firstName);
    final String sanitizedProductInfo = sanitizeProductInfo(params.productInfo);
    final String sanitizedEmail = sanitizeEmail(params.email);
    final String sanitizedPhone = sanitizePhone(params.phone);

    final map = {
      'key': params.merchantKey,
      'txnid': params.txnid,
      'amount': amountStr,
      'productinfo': sanitizedProductInfo,
      'firstname': sanitizedFirstName,
      'email': sanitizedEmail,
      'phone': sanitizedPhone,
      'surl': params.surl,
      'furl': params.furl,
      'hash': hash,
      'service_provider': 'payu_paisa',
    };

    if (params.pg != null) map['pg'] = params.pg!;
    if (params.bankcode != null) map['bankcode'] = params.bankcode!;

    return map;
  }

  /// Verify SHA-512 Hash of PayU Response
  static bool verifyResponseHash({
    required Map<String, String> responseData,
    required String merchantSalt,
    required String merchantKey,
  }) {
    final String? receivedHash = responseData['hash'];
    if (receivedHash == null || receivedHash.isEmpty) return false;

    final String status = responseData['status'] ?? '';
    final String email = responseData['email'] ?? '';
    final String firstname = responseData['firstname'] ?? '';
    final String productinfo = responseData['productinfo'] ?? '';
    final double amount = double.tryParse(responseData['amount'] ?? '0') ?? 0.0;
    final String txnid = responseData['txnid'] ?? '';
    final String? additionalCharges = responseData['additionalCharges'];

    final expectedHash = generateResponseHash(
      merchantSalt: merchantSalt,
      status: status,
      email: email,
      firstName: firstname,
      productInfo: productinfo,
      amount: amount,
      txnid: txnid,
      merchantKey: merchantKey,
      udf1: responseData['udf1'] ?? '',
      udf2: responseData['udf2'] ?? '',
      udf3: responseData['udf3'] ?? '',
      udf4: responseData['udf4'] ?? '',
      udf5: responseData['udf5'] ?? '',
      additionalCharges: additionalCharges,
    );

    final matches = receivedHash.toLowerCase() == expectedHash.toLowerCase();
    debugPrint('PayUService: Response Hash Validation -> (Received: $receivedHash vs Expected: $expectedHash) -> Match: $matches');
    return matches;
  }

  /// Cloud Functions Backend URL base (Can be updated via .env or cloud config)
  static String get cloudFunctionsBaseUrl =>
      dotenv.env['FIREBASE_FUNCTIONS_URL'] ??
      'https://us-central1-cst-whitelabel-app.cloudfunctions.net';

  /// Utility to check if native UPI apps can be launched
  static Future<Map<String, bool>> checkInstalledUpiApps() async {
    final Map<String, String> upiSchemes = {
      'GPay': 'tez://pay',
      'PhonePe': 'phonepe://pay',
      'Paytm': 'paytmmp://pay',
      'Generic UPI': 'upi://pay',
    };

    final Map<String, bool> results = {};
    for (final entry in upiSchemes.entries) {
      try {
        final canLaunch = await canLaunchUrl(Uri.parse(entry.value));
        results[entry.key] = canLaunch;
      } catch (_) {
        results[entry.key] = false;
      }
    }
    return results;
  }

  /// Asynchronously fetch hash & postData from Firebase Cloud Function
  /// Falls back to local hash generation if function is unreachable or returns mismatched key
  static Future<Map<String, String>> buildPostDataAsync(PayUParams params) async {
    final Map<String, dynamic> requestPayload = {
      'txnid': params.txnid,
      'amount': params.amount,
      'productInfo': params.productInfo,
      'firstName': params.firstName,
      'email': params.email,
      'phone': params.phone,
      'merchantKey': params.merchantKey,
      'environment': params.isSandbox ? 'sandbox' : 'production',
      if (params.pg != null) 'pg': params.pg,
      if (params.bankcode != null) 'bankcode': params.bankcode,
    };

    debugPrint('\n=================== PAYU REQUEST PAYLOAD ===================');
    debugPrint('PayUService: Sending request to Backend Cloud Function...');
    debugPrint(const JsonEncoder.withIndent('  ').convert(requestPayload));
    debugPrint('============================================================\n');

    try {
      final String endpointUrl = '$cloudFunctionsBaseUrl/generatePayUHash';

      final response = await http.post(
        Uri.parse(endpointUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'data': requestPayload}),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        debugPrint('\n=================== PAYU HASH RESPONSE PAYLOAD ===================');
        debugPrint(const JsonEncoder.withIndent('  ').convert(decoded));
        debugPrint('==================================================================\n');

        final resultData = decoded['result'] ?? decoded;
        if (resultData != null && resultData['postData'] != null) {
          final Map<String, String> serverPostData =
              Map<String, String>.from(resultData['postData']);
          // Ensure the returned key matches our intended merchant key and is not sandbox
          if (serverPostData['key'] == params.merchantKey && (serverPostData['hash'] ?? '').isNotEmpty) {
            return serverPostData;
          } else {
            debugPrint('PayUService: Server returned key (${serverPostData['key']}) != expected key (${params.merchantKey}). Falling back to local hash.');
          }
        }
      }
      debugPrint('PayUService: Backend returned HTTP ${response.statusCode}, using local hash fallback.');
    } catch (e) {
      debugPrint('PayUService: Cloud Function exception ($e), using local fallback.');
    }

    final localData = buildPostData(params);
    debugPrint('\n=================== PAYU LOCAL FALLBACK POST DATA ===================');
    debugPrint(const JsonEncoder.withIndent('  ').convert(localData));
    debugPrint('=====================================================================\n');
    return localData;
  }

  /// Asynchronously verify payment response & activate subscription via Cloud Function
  static Future<bool> verifyAndActivateSubscriptionOnBackend({
    required String orgId,
    required String txnid,
    String? payuMoneyId,
    Map<String, String>? rawData,
    Map<String, dynamic>? planDetails,
  }) async {
    final Map<String, dynamic> verifyRequestPayload = {
      'orgId': orgId,
      'txnid': txnid,
      'payuMoneyId': payuMoneyId,
      'rawData': rawData,
      'planDetails': planDetails,
      'environment': isProduction ? 'production' : 'sandbox',
      'merchantKey': activeMerchantKey,
    };

    debugPrint('\n=================== VERIFY SUBSCRIPTION REQUEST ===================');
    debugPrint(const JsonEncoder.withIndent('  ').convert(verifyRequestPayload));
    debugPrint('====================================================================\n');

    try {
      final String endpointUrl = '$cloudFunctionsBaseUrl/verifySubscription';

      final response = await http.post(
        Uri.parse(endpointUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'data': verifyRequestPayload}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        debugPrint('\n=================== VERIFY SUBSCRIPTION RESPONSE ===================');
        debugPrint(const JsonEncoder.withIndent('  ').convert(decoded));
        debugPrint('=====================================================================\n');

        final result = decoded['result'] ?? decoded;
        if (result != null && result['success'] == true) {
          return true;
        }
      }
      debugPrint('PayUService: Backend verification returned HTTP ${response.statusCode}');
    } catch (e) {
      debugPrint('PayUService: Cloud function subscription verification exception ($e)');
    }
    return false;
  }

  /// Helper to generate unique transaction ID
  static String generateTxnId() {
    return 'PAYU_${DateTime.now().millisecondsSinceEpoch}';
  }
}

