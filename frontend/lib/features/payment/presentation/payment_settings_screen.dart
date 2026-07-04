import 'dart:io';
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:frontend/core/network/api_service.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/paycif_button.dart';
import 'package:frontend/core/l10n/generated/app_localizations.dart';
import 'package:frontend/features/payment/presentation/payment_controller.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PaymentSettingsScreen extends StatefulWidget {
  const PaymentSettingsScreen({super.key});

  @override
  State<PaymentSettingsScreen> createState() => _PaymentSettingsScreenState();
}

class _PaymentSettingsScreenState extends State<PaymentSettingsScreen> {
  final _api = ApiService();
  bool _loadingUrl = false;

  Future<void> _openManageWidget() async {
    setState(() => _loadingUrl = true);
    final url = await _api.fetchManageUrl();
    if (!mounted) return;
    setState(() => _loadingUrl = false);

    if (url == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.paymentSettingsOpenFailed)),
      );
      return;
    }

    final uri = Uri.parse(url);

    if (Platform.isAndroid) {
      // Google Pay requires real browser
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // iOS: in-app WebView for Apple Pay camera access
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => _AchManagePage(uri: uri)),
      );
      // Refresh token status after returning
      if (mounted) context.read<PaymentController>().fetchData(silent: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final controller = context.watch<PaymentController>();
    final hasLinked = controller.hasValidAchToken;
    final Color mutedColor = AppTheme.textSecondaryColor(context);
    final Color primary = AppTheme.primaryColor(context);

    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: canPop
            ? IconButton(
                icon: Icon(
                  PhosphorIcons.caretLeft,
                  color: AppTheme.textPrimaryColor(context),
                  size: 20,
                ),
                onPressed: () => Navigator.of(context).pop(),
              )
            : (GoRouterState.of(context).uri.path == '/payment_settings'
                ? IconButton(
                    icon: Icon(
                      PhosphorIcons.house,
                      color: AppTheme.textPrimaryColor(context),
                      size: 20,
                    ),
                    onPressed: () => context.go('/main'),
                  )
                : null),
        title: Text(
          l10n.paymentSettingsTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimaryColor(context),
          ),
        ),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Icon(PhosphorIcons.vault, size: 56, color: primary),
                const SizedBox(height: 16),
                Text(
                  l10n.paymentSettingsHeroLabel,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            l10n.paymentSettingsSectionTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.paymentSettingsDescription,
            style: theme.textTheme.bodyMedium?.copyWith(color: mutedColor, height: 1.5),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: PaycifButton(
              text: hasLinked ? l10n.paymentSettingsManageCta : l10n.paymentSettingsSetupCta,
              icon: PhosphorIcons.gearSix,
              isLoading: _loadingUrl,
              onPressed: _openManageWidget,
              variant: PaycifButtonVariant.primary,
              size: PaycifButtonSize.lg,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.paymentSettingsFootnote,
            style: theme.textTheme.bodySmall?.copyWith(color: mutedColor),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// In-app WebView for iOS (Apple Pay needs camera access via WebView)
// ─────────────────────────────────────────────────────────────────────────────

class _AchManagePage extends StatefulWidget {
  final Uri uri;
  const _AchManagePage({required this.uri});

  @override
  State<_AchManagePage> createState() => _AchManagePageState();
}

class _AchManagePageState extends State<_AchManagePage> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _loading = true),
        onPageFinished: (_) => setState(() => _loading = false),
        onNavigationRequest: (req) {
          if (req.url.startsWith('paycif://')) {
            Navigator.of(context).pop();
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
        title: Text(AppLocalizations.of(context)!.paymentSettingsWebviewTitle),
        leading: IconButton(
          icon: const Icon(PhosphorIcons.x),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(child: CircularProgressIndicator(color: AppTheme.primaryTeal)),
        ],
      ),
    );
  }
}
