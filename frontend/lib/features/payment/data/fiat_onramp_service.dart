import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:frontend/core/network/api_service.dart';

/// Represents a single ACH-supported fiat payment method.
class AchFiatMethod {
  final String currency;
  final String country;
  final String countryName;
  final String payWayCode;
  final String payWayName;
  final double fixedFee;
  final double feeRate;
  final double payMin;
  final double payMax;

  const AchFiatMethod({
    required this.currency,
    required this.country,
    required this.countryName,
    required this.payWayCode,
    required this.payWayName,
    required this.fixedFee,
    required this.feeRate,
    required this.payMin,
    required this.payMax,
  });

  factory AchFiatMethod.fromJson(Map<String, dynamic> j) => AchFiatMethod(
        currency: j['currency'] as String? ?? '',
        country: j['country'] as String? ?? '',
        countryName: j['country_name'] as String? ?? '',
        payWayCode: j['pay_way_code'] as String? ?? '',
        payWayName: j['pay_way_name'] as String? ?? '',
        fixedFee: (j['fixed_fee'] as num?)?.toDouble() ?? 0,
        feeRate: (j['fee_rate'] as num?)?.toDouble() ?? 0,
        payMin: (j['pay_min'] as num?)?.toDouble() ?? 0,
        payMax: (j['pay_max'] as num?)?.toDouble() ?? 0,
      );

  /// Human-readable fee string, e.g. "1.9% + $0.30"
  String get feeLabel {
    final pct = '${(feeRate * 100).toStringAsFixed(1)}%';
    if (fixedFee > 0) return '$pct + \$${fixedFee.toStringAsFixed(2)}';
    return pct;
  }
}

/// Manages ACH on-ramp token refresh and fiat method queries.
class FiatOnRampService {
  final ApiService _api = ApiService();

  // ─── Token ───────────────────────────────────────────────────────────────

  /// Returns a valid ACH accessToken, fetching a fresh one if needed.
  /// Callers should pass the cached token from UserProfile if available.
  Future<String?> resolveToken({
    required bool hasValidCachedToken,
    required String? cachedToken,
  }) async {
    if (hasValidCachedToken && cachedToken != null) return cachedToken;
    return await _api.fetchAchToken();
  }

  // ─── Fiat Methods ─────────────────────────────────────────────────────────

  /// Fetches supported payment methods from Go backend (1-hour server cache).
  Future<List<AchFiatMethod>> fetchMethods() async {
    final raw = await _api.fetchFiatMethods();
    return raw.map(AchFiatMethod.fromJson).toList();
  }

  /// Filters methods to a given currency code (e.g. "USD").
  List<AchFiatMethod> methodsForCurrency(
    List<AchFiatMethod> all,
    String currency,
  ) =>
      all.where((m) => m.currency.toUpperCase() == currency.toUpperCase()).toList();

  // ─── Widget Launch ────────────────────────────────────────────────────────

  /// Opens the ACH widget using the right strategy per platform:
  /// - iOS: in-app WebView (required for Apple Pay camera KYC)
  /// - Android: external browser (required for Google Pay — WebView blocks popups)
  Future<void> launch(
    BuildContext context, {
    required String appId,
    required String fiat,
    required String crypto,
    required String network,
    required String merchantOrderNo,
    required String redirectUrl,
    required String callbackUrl,
    String? achToken,
    bool sandbox = true,
  }) async {
    final base = sandbox
        ? 'https://ramptest.alchemypay.org'
        : 'https://ramp.alchemypay.org';

    final params = <String, String>{
      'appId': appId,
      'fiat': fiat,
      'crypto': crypto,
      'network': network,
      'merchantOrderNo': merchantOrderNo,
      'redirectUrl': redirectUrl,
      'callbackUrl': callbackUrl,
      'showTable': 'buy',
    };
    if (achToken != null) params['token'] = achToken;

    final uri = Uri.parse(base).replace(queryParameters: params);

    if (Platform.isAndroid) {
      // Google Pay requires real browser — WebView popup blocker breaks it
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        debugPrint('❌ FiatOnRampService: could not launch external browser');
      }
      return;
    }

    // iOS: in-app WebView — needed for Apple Pay camera access (KYC)
    if (context.mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _AchWebViewPage(uri: uri, sandbox: sandbox),
        ),
      );
    }
  }
}

// ─── In-App WebView (iOS only) ────────────────────────────────────────────────

class _AchWebViewPage extends StatefulWidget {
  final Uri uri;
  final bool sandbox;

  const _AchWebViewPage({required this.uri, required this.sandbox});

  @override
  State<_AchWebViewPage> createState() => _AchWebViewPageState();
}

class _AchWebViewPageState extends State<_AchWebViewPage> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // Required for Apple Pay camera access in KYC flow
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _loading = true),
        onPageFinished: (_) => setState(() => _loading = false),
        onNavigationRequest: (req) {
          // Intercept redirectUrl to pop back into app
          if (req.url.startsWith('paycif://')) {
            Navigator.of(context).pop(req.url);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(widget.uri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.sandbox ? 'Pay via On-Ramp (Sandbox)' : 'Pay via On-Ramp'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
