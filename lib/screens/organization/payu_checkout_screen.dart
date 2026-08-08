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
      background-color: #f8fafc;
      color: #334155;
    }
    .spinner {
      border: 4px solid rgba(0, 0, 0, 0.1);
      width: 40px;
      height: 40px;
      border-radius: 50%;
      border-left-color: #2563eb;
      animation: spin 1s linear infinite;
    }
    @keyframes spin {
      0% { transform: rotate(0deg); }
      100% { transform: rotate(360deg); }
    }
    .text {
      margin-top: 16px;
      font-size: 16px;
      font-weight: 500;
    }
  </style>
</head>
<body>
  <div class="spinner"></div>
  <div class="text">Connecting securely to PayU Payment Gateway...</div>
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
      ..setBackgroundColor(const Color(0xFFF8FAFC))
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
        title: const Text('Cancel Payment?'),
        content: const Text('Are you sure you want to cancel the payment process?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('NO, CONTINUE'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('YES, CANCEL'),
          ),
        ],
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _onWillPop();
      },
      child: GlassScaffold(
        title: 'PayU Secure Checkout',
        onBack: () => _onWillPop(),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading)
              const LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
          ],
        ),
      ),
    );
  }
}
