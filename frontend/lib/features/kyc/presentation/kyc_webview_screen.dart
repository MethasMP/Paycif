import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Renders the Alchemy Pay KYC hosted page inside the app.
/// Pops automatically when Alchemy Pay signals completion via redirectUrl.
class KycWebViewScreen extends StatefulWidget {
  final String kycUrl;

  /// The URL prefix we told Alchemy Pay to redirect to when KYC is done.
  /// If the WebView navigates to a URL starting with this, KYC is complete.
  final String? completionUrlPrefix;

  const KycWebViewScreen({
    super.key,
    required this.kycUrl,
    this.completionUrlPrefix,
  });

  @override
  State<KycWebViewScreen> createState() => _KycWebViewScreenState();
}

class _KycWebViewScreenState extends State<KycWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _isLoading = true),
        onPageFinished: (_) => setState(() => _isLoading = false),
        onNavigationRequest: (request) {
          final prefix = widget.completionUrlPrefix;
          if (prefix != null && prefix.isNotEmpty && request.url.startsWith(prefix)) {
            // Alchemy Pay redirected to our redirect URL — KYC flow is complete.
            Navigator.of(context).pop(true);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
        onWebResourceError: (error) {
          debugPrint('KYC WebView error: ${error.description}');
        },
      ))
      ..loadRequest(Uri.parse(widget.kycUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: const Text(
          'Identity Verification',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
