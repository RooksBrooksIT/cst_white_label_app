import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:demo_cst/services/payu_service.dart';
import 'package:demo_cst/widgets/glass_scaffold.dart';
import 'package:url_launcher/url_launcher.dart';

class PayUCheckoutScreen extends StatefulWidget {
  final PayUParams params;

  const PayUCheckoutScreen({
    super.key,
    required this.params,
  });

  @override
  State<PayUCheckoutScreen> createState() => _PayUCheckoutScreenState();
}

class _PayUCheckoutScreenState extends State<PayUCheckoutScreen> {
  WebViewController? _controller;
  bool _isLoading = true;
  bool _hasSubmitted = false;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  Future<void> _initWebView() async {
    final postDataMap = await PayUService.buildPostDataAsync(widget.params);

    // Build self-submitting HTML form for PayU POST request
    final String htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>PayU Checkout</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      height: 100vh;
      margin: 0;
      background-color: #ffffff;
      color: #0a183d;
    }
    .spinner {
      border: 4px solid rgba(11, 25, 66, 0.1);
      width: 44px;
      height: 44px;
      border-radius: 50%;
      border-left-color: #1e88e5;
      animation: spin 1s linear infinite;
    }
    @keyframes spin {
      0% { transform: rotate(0deg); }
      100% { transform: rotate(360deg); }
    }
    .text {
      margin-top: 18px;
      font-size: 15px;
      font-weight: 700;
      color: #0a183d;
    }
    .subtext {
      margin-top: 6px;
      font-size: 13px;
      color: #5a759e;
    }
  </style>
</head>
<body>
  <div class="spinner"></div>
  <div class="text">Connecting securely to PayU Gateway...</div>
  <div class="subtext">Please do not refresh or press back</div>
  <form id="payu_form" action="${widget.params.payUrl}" method="post">
    ${postDataMap.entries.map((e) => '<input type="hidden" name="${e.key}" value="${_escapeHtml(e.value)}" />').join('\n')}
  </form>
  <script type="text/javascript">
    document.getElementById('payu_form').submit();
  </script>
</body>
</html>
''';

    final String contentBase64 = base64Encode(const Utf8Encoder().convert(htmlContent));

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..addJavaScriptChannel(
        'PayUBridge',
        onMessageReceived: (JavaScriptMessage message) {
          _handleBridgeData(message.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) setState(() => _isLoading = true);
            _checkUrlNavigation(url);
          },
          onPageFinished: (String url) {
            if (mounted) setState(() => _isLoading = false);
            _injectResponseExtractor();
            _checkUrlNavigation(url);
          },
          onNavigationRequest: (NavigationRequest request) {
            return _checkUrlNavigation(request.url);
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('PayU WebView Error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse('data:text/html;base64,$contentBase64'));

    if (mounted) {
      setState(() {});
    }
  }

  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  void _injectResponseExtractor() {
    _controller?.runJavaScript('''
      try {
        const url = window.location.href;
        const lowerUrl = url.toLowerCase();
        
        // Guard: Do not extract on initial data URIs or while loading payment page
        if (url.startsWith('data:') || lowerUrl.includes('_payment')) {
          return;
        }

        const data = {};
        
        // 1. URL search params
        const searchParams = new URLSearchParams(window.location.search);
        searchParams.forEach((v, k) => data[k] = v);

        // 2. URL hash params
        if (window.location.hash) {
          const hashClean = window.location.hash.replace(/^#\\/?/, '').replace(/^.*\\?/, '');
          const hashParams = new URLSearchParams(hashClean);
          hashParams.forEach((v, k) => data[k] = v);
        }

        // 3. Form input values (PayU POST response body inputs on callback page)
        const inputs = document.querySelectorAll('input');
        inputs.forEach(i => {
          if (i.name && i.value) {
            data[i.name] = i.value;
          }
        });

        data['_pageUrl'] = url;
        data['_title'] = document.title || '';

        const hasExplicitStatus = data.status || data.unmappedstatus || data.error_Message;
        const isCallbackPage = lowerUrl.includes('payuresponse') || lowerUrl.includes('/success') || lowerUrl.includes('#/success') || lowerUrl.includes('/failure') || lowerUrl.includes('#/failure') || lowerUrl.includes('test_response.php');

        if ((hasExplicitStatus || isCallbackPage) && window.PayUBridge) {
          window.PayUBridge.postMessage(JSON.stringify(data));
        }
      } catch(e) {}
    ''');
  }

  void _handleBridgeData(String jsonString) {
    if (_hasSubmitted) return;
    try {
      final Map<String, dynamic> parsed = jsonDecode(jsonString);
      final String pageUrl = (parsed['_pageUrl']?.toString() ?? '').toLowerCase();

      // Guard: Ignore if bridge data is from initial data url or payment loading page
      if (pageUrl.startsWith('data:') || pageUrl.contains('_payment')) {
        return;
      }

      final Map<String, String> rawData = parsed.map((k, v) => MapEntry(k, v.toString()));
      final String statusLower = (rawData['status'] ?? rawData['unmappedstatus'] ?? '').toLowerCase();
      final String? mihpayid = rawData['mihpayid'] ?? rawData['payuMoneyId'];
      final bool hasPayuId = mihpayid != null && mihpayid.trim().isNotEmpty && mihpayid != 'null' && mihpayid != '0';

      // Confirmed SUCCESS: Status is success or callback url reached with success
      final bool isExplicitSuccess = statusLower == 'success' ||
          ((pageUrl.contains('/success') ||
                  pageUrl.contains('#/success') ||
                  pageUrl.contains('payuresponse') ||
                  pageUrl.contains('payuwebhook')) &&
              (hasPayuId || statusLower == 'success'));

      // Confirmed FAILURE: Explicit failure status or on failure URL or has error message
      final bool isExplicitFailure = statusLower == 'failure' ||
          statusLower == 'failed' ||
          statusLower == 'cancel' ||
          statusLower == 'cancelled' ||
          statusLower == 'user_cancelled' ||
          pageUrl.contains('/failure') ||
          pageUrl.contains('#/failure') ||
          pageUrl.contains('status=failure') ||
          pageUrl.contains('status=failed') ||
          pageUrl.contains('status=cancel') ||
          (rawData['error_Message'] != null && rawData['error_Message']!.isNotEmpty && rawData['error_Message'] != 'No Error');

      if (isExplicitSuccess && !_hasSubmitted) {
        _hasSubmitted = true;
        debugPrint('\n=================== PAYU BRIDGE SUCCESS DETECTED ===================');
        debugPrint('PayU Money ID: $mihpayid');
        debugPrint('Extracted Data: $rawData');
        debugPrint('===================================================================\n');

        final result = PayUResult(
          isSuccess: true,
          txnid: rawData['txnid'] ?? widget.params.txnid,
          payuMoneyId: mihpayid,
          rawData: rawData,
        );
        Navigator.pop(context, result);
      } else if (isExplicitFailure && !_hasSubmitted) {
        _hasSubmitted = true;
        debugPrint('\n=================== PAYU BRIDGE FAILURE DETECTED ===================');
        debugPrint('Extracted Data: $rawData');
        debugPrint('===================================================================\n');

        final errorMsg = rawData['error_Message'] ??
            rawData['field9'] ??
            rawData['errorMessage'] ??
            'Payment failed or was cancelled.';

        final result = PayUResult(
          isSuccess: false,
          txnid: rawData['txnid'] ?? widget.params.txnid,
          errorMessage: errorMsg,
          rawData: rawData,
        );
        Navigator.pop(context, result);
      }
    } catch (e) {
      debugPrint('PayU Bridge parsing exception: $e');
    }
  }

  NavigationDecision _checkUrlNavigation(String url) {
    debugPrint('PayU Navigated URL: $url');

    final String lowerUrl = url.toLowerCase();

    // Guard: Allow initial data URI and PayU checkout pages to load unrestricted
    if (lowerUrl.startsWith('data:') ||
        lowerUrl.contains('secure.payu.in') ||
        lowerUrl.contains('test.payu.in') ||
        lowerUrl.contains('api.payu.in')) {
      return NavigationDecision.navigate;
    }

    // Intercept native Android UPI Intent & deep-link schemes
    if (lowerUrl.startsWith('upi://') ||
        lowerUrl.startsWith('intent://') ||
        lowerUrl.startsWith('tez://') ||
        lowerUrl.startsWith('phonepe://') ||
        lowerUrl.startsWith('paytmmp://') ||
        lowerUrl.startsWith('gpay://')) {
      _handleUpiIntentLaunch(url);
      return NavigationDecision.prevent;
    }

    final uri = Uri.parse(url);
    final String queryStatus = (uri.queryParameters['status'] ?? '').toLowerCase();
    final String? mihpayid = uri.queryParameters['mihpayid'] ?? uri.queryParameters['payuMoneyId'];
    final bool hasPayuId = mihpayid != null && mihpayid.trim().isNotEmpty && mihpayid != 'null' && mihpayid != '0';

    // Intercept confirmed query params with PayU ID
    final bool isSuccessUrl = (lowerUrl.contains('payuresponse') ||
            lowerUrl.contains('payuwebhook') ||
            lowerUrl.contains('/success') ||
            lowerUrl.contains('#/success') ||
            queryStatus == 'success') &&
        hasPayuId;

    if (isSuccessUrl) {
      if (!_hasSubmitted) {
        _hasSubmitted = true;
        debugPrint('\n=================== PAYU PAYMENT SUCCESS CALLBACK ===================');
        debugPrint('Navigated URL: $url');
        debugPrint('PayU Money ID: $mihpayid');
        debugPrint('Raw Parameters: ${uri.queryParameters}');
        debugPrint('=====================================================================\n');

        final result = PayUResult(
          isSuccess: true,
          txnid: uri.queryParameters['txnid'] ?? widget.params.txnid,
          payuMoneyId: mihpayid,
          rawData: uri.queryParameters,
        );
        Navigator.pop(context, result);
      }
      return NavigationDecision.prevent;
    }

    // Intercept explicit failure parameters in query or URL
    final bool isFailureUrl = lowerUrl.contains('/failure') ||
        lowerUrl.contains('#/failure') ||
        queryStatus == 'failure' ||
        queryStatus == 'failed' ||
        queryStatus == 'cancel' ||
        queryStatus == 'cancelled' ||
        lowerUrl.contains('status=failure') ||
        lowerUrl.contains('status=failed') ||
        lowerUrl.contains('status=cancel');

    if (isFailureUrl) {
      if (!_hasSubmitted) {
        _hasSubmitted = true;
        debugPrint('\n=================== PAYU PAYMENT FAILURE CALLBACK ===================');
        debugPrint('Navigated URL: $url');
        debugPrint('Raw Parameters: ${uri.queryParameters}');
        debugPrint('=====================================================================\n');

        final errorMsg = uri.queryParameters['error_Message'] ??
            uri.queryParameters['field9'] ??
            'Payment failed or was cancelled by user.';

        final result = PayUResult(
          isSuccess: false,
          txnid: uri.queryParameters['txnid'] ?? widget.params.txnid,
          errorMessage: errorMsg,
          rawData: uri.queryParameters,
        );
        Navigator.pop(context, result);
      }
      return NavigationDecision.prevent;
    }

    return NavigationDecision.navigate;
  }

  Future<void> _handleUpiIntentLaunch(String rawUrl) async {
    debugPrint('\n=================== UPI INTENT LAUNCH DETECTED ===================');
    debugPrint('Raw Intent URL: $rawUrl');
    debugPrint('=================================================================\n');

    try {
      final Uri uri = Uri.parse(rawUrl);
      final bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        debugPrint('PayUCheckoutScreen: Could not launch intent URL directly, showing dialog...');
        _showNoUpiAppDialog();
      }
    } catch (e) {
      debugPrint('PayUCheckoutScreen: Exception launching UPI intent: $e');
      _showNoUpiAppDialog();
    }
  }

  void _showNoUpiAppDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 10),
            Text('No UPI App Found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'No compatible UPI application (Google Pay, PhonePe, Paytm, etc.) was found on your device.\n\nPlease install a UPI application or choose Card / NetBanking to complete payment.',
          style: TextStyle(fontSize: 14, color: Color(0xFF5A759E)),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0B1942),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _completeTestSuccess() {
    if (_hasSubmitted) return;
    _hasSubmitted = true;
    final testData = PayUService.createTestResponseData(
      params: widget.params,
      isSuccess: true,
    );
    debugPrint('\n=================== SANDBOX QUICK TEST SUCCESS ===================');
    debugPrint('Test Response Payload: $testData');
    debugPrint('==================================================================\n');

    final result = PayUResult(
      isSuccess: true,
      txnid: widget.params.txnid,
      payuMoneyId: testData['mihpayid'],
      rawData: testData,
    );
    Navigator.pop(context, result);
  }

  void _completeTestFailure() {
    if (_hasSubmitted) return;
    _hasSubmitted = true;
    final testData = PayUService.createTestResponseData(
      params: widget.params,
      isSuccess: false,
    );
    debugPrint('\n=================== SANDBOX QUICK TEST FAILURE ===================');
    debugPrint('Test Response Payload: $testData');
    debugPrint('==================================================================\n');

    final result = PayUResult(
      isSuccess: false,
      txnid: widget.params.txnid,
      errorMessage: 'Test payment was cancelled by user.',
      rawData: testData,
    );
    Navigator.pop(context, result);
  }

  void _showTestInfoDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.developer_mode_rounded, color: Color(0xFF1E88E5), size: 26),
            SizedBox(width: 10),
            Text('Sandbox Test Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTestInfoRow('Environment', 'Sandbox (Test Mode)'),
            _buildTestInfoRow('Merchant Key', widget.params.merchantKey),
            _buildTestInfoRow('Merchant ID', widget.params.merchantId ?? '9193759'),
            _buildTestInfoRow('Test UPI VPA', 'success@payu'),
            _buildTestInfoRow('Test Card Number', '4012 0000 0000 0001'),
            _buildTestInfoRow('Test Card Expiry/CVV', '12/30 • 123'),
            const SizedBox(height: 10),
            const Text(
              'Use "Quick Test Success" to simulate successful test gateway callbacks immediately without waiting for web responses.',
              style: TextStyle(fontSize: 12, color: Color(0xFF5A759E)),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0B1942),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildTestInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF5A759E))),
          SelectableText(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0A183D))),
        ],
      ),
    );
  }

  Widget _buildSandboxToolbar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF93C5FD), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E40AF).withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF1D4ED8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'SANDBOX',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'PayU Sandbox Mode Active',
                  style: TextStyle(
                    color: Color(0xFF1E40AF),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.info_outline_rounded, color: Color(0xFF1D4ED8), size: 20),
                onPressed: _showTestInfoDialog,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _completeTestSuccess,
                  icon: const Icon(Icons.bolt_rounded, size: 16),
                  label: const Text(
                    'Quick Test Success',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _completeTestFailure,
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text(
                  'Cancel',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFDC2626),
                  side: const BorderSide(color: Color(0xFFFCA5A5)),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<bool> _onWillPop() async {
    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFCA5A5), width: 1.5),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFDC2626),
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Cancel Payment?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0A183D),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Are you sure you want to cancel your payment transaction?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF5A759E),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'YES, CANCEL',
                      style: TextStyle(
                        color: Color(0xFFDC2626),
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0B1942),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 4,
                      shadowColor: const Color(0xFF0B1942).withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'NO, CONTINUE',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (shouldPop == true && mounted) {
      Navigator.pop(
        context,
        PayUResult(
          isSuccess: false,
          txnid: widget.params.txnid,
          errorMessage: 'Payment cancelled by user.',
        ),
      );
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    const Color darkNavy = Color(0xFF0B1942);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _onWillPop();
      },
      child: GlassScaffold(
        padding: EdgeInsets.zero,
        body: SafeArea(
          child: Column(
            children: [
              // Custom Top Header Row
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: darkNavy,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: darkNavy.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        onPressed: () => _onWillPop(),
                      ),
                    ),
                    const Text(
                      'PayU Secure Checkout',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0A183D),
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),

              // SSL Encryption Badge
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: darkNavy,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: darkNavy.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shield_rounded,
                        color: Color(0xFF10B981),
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        '256-bit SSL Encrypted • PayU Gateway',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.params.isSandbox) _buildSandboxToolbar(),
              const SizedBox(height: 8),

              // Linear Progress Bar if Loading
              if (_isLoading)
                const LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E88E5)),
                  minHeight: 3,
                ),

              // WebView Container Card
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: darkNavy.withValues(alpha: 0.15),
                          blurRadius: 20,
                          spreadRadius: 1,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: _controller != null
                          ? WebViewWidget(controller: _controller!)
                          : const Center(
                              child: CircularProgressIndicator(
                                color: darkNavy,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
