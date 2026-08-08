import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:demo_cst/services/payu_service.dart';
import 'package:demo_cst/widgets/glass_scaffold.dart';

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
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasSubmitted = false;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    final postDataMap = PayUService.buildPostData(widget.params);

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
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) setState(() => _isLoading = true);
            _checkUrlNavigation(url);
          },
          onPageFinished: (String url) {
            if (mounted) setState(() => _isLoading = false);
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
  }

  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  NavigationDecision _checkUrlNavigation(String url) {
    debugPrint('PayU Navigated URL: $url');

    final uri = Uri.parse(url);

    // Check if redirect matches Success URL or contains success params
    if (url.startsWith(widget.params.surl) ||
        url.contains('/success') ||
        url.contains('status=success') ||
        uri.queryParameters['status'] == 'success') {
      if (!_hasSubmitted) {
        _hasSubmitted = true;
        final payuMoneyId = uri.queryParameters['mihpayid'] ?? uri.queryParameters['payuMoneyId'];
        final result = PayUResult(
          isSuccess: true,
          txnid: widget.params.txnid,
          payuMoneyId: payuMoneyId,
          rawData: uri.queryParameters,
        );
        Navigator.pop(context, result);
      }
      return NavigationDecision.prevent;
    }

    // Check if redirect matches Failure URL or contains failure params
    if (url.startsWith(widget.params.furl) ||
        url.contains('/failure') ||
        url.contains('status=failure') ||
        url.contains('status=failed') ||
        uri.queryParameters['status'] == 'failure') {
      if (!_hasSubmitted) {
        _hasSubmitted = true;
        final errorMsg = uri.queryParameters['error_Message'] ?? 'Payment failed or was cancelled by user.';
        final result = PayUResult(
          isSuccess: false,
          txnid: widget.params.txnid,
          errorMessage: errorMsg,
          rawData: uri.queryParameters,
        );
        Navigator.pop(context, result);
      }
      return NavigationDecision.prevent;
    }

    return NavigationDecision.navigate;
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
              const SizedBox(height: 10),

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
                      child: WebViewWidget(controller: _controller),
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
