import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:frontend/core/network/api_service.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/l10n/generated/app_localizations.dart';
import 'package:frontend/features/payment/presentation/payment_controller.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:frontend/core/widgets/app_icon.dart';

class PaymentSettingsScreen extends StatefulWidget {
  const PaymentSettingsScreen({super.key});

  @override
  State<PaymentSettingsScreen> createState() => _PaymentSettingsScreenState();
}

class _PaymentSettingsScreenState extends State<PaymentSettingsScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late AnimationController _animController;
  bool _isLoadingApplePay = false;
  bool _isLoadingCard = false;
  bool _isLoadingBank = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !MediaQuery.of(context).disableAnimations) {
        _animController.forward();
      } else {
        _animController.value = 1.0;
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleManageWidget(String type) async {
    if (_isLoadingApplePay || _isLoadingCard || _isLoadingBank) return;
    
    HapticFeedback.mediumImpact();
    setState(() {
      if (type == 'apple') _isLoadingApplePay = true;
      if (type == 'card') _isLoadingCard = true;
      if (type == 'bank') _isLoadingBank = true;
    });

    try {
      final url = await _api.fetchManageUrl().timeout(const Duration(seconds: 15));
      if (!mounted) return;

      if (url == null) {
        _showErrorSnackBar(AppLocalizations.of(context)?.paymentSettingsOpenFailed ?? "Failed to open gateway");
        return;
      }

      final uri = Uri.parse(url);

      if (kIsWeb) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (Platform.isAndroid) {
        final canLaunch = await canLaunchUrl(uri);
        if (canLaunch) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          _showErrorSnackBar("No compatible browser found on this device.");
        }
      } else {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => _AchManagePage(uri: uri)),
        );
        if (mounted) context.read<PaymentController>().fetchData(silent: true);
      }
    } on TimeoutException {
      _showErrorSnackBar("Connection timed out. Please try again.");
    } catch (e) {
      _showErrorSnackBar("A network error occurred. Please check your connection.");
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingApplePay = false;
          _isLoadingCard = false;
          _isLoadingBank = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red.shade800,
      ),
    );
  }

  Widget _buildStaggeredItem({
    required int index,
    required Widget child,
  }) {
    // If animations are done or disabled, return the child directly to save tree depth
    if (_animController.isCompleted) return child;

    final start = (index * 0.1).clamp(0.0, 1.0);
    final end = (start + 0.4).clamp(0.0, 1.0);
    final animation = CurvedAnimation(
      parent: _animController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - animation.value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Semantics(
      header: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Payment Methods", // TODO: Move to AppLocalizations
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -1.0,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Manage how you pay and receive funds securely.", // TODO: Move to AppLocalizations
            style: theme.textTheme.bodyLarge?.copyWith(
              color: isDark ? Colors.white54 : Colors.black54,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSectionTitle(String title, bool isDark) {
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: isDark ? Colors.white60 : Colors.black54, // WCAG Compliant Contrast
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final canPop = Navigator.of(context).canPop();

    // Only select the required state to prevent full-page rebuilds
    final hasLinked = context.select<PaymentController, bool>((c) => c.hasValidAchToken);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: canPop
            ? IconButton(
                icon: Semantics(
                  label: "Back",
                  child: AppIcon(
                    PhosphorIcons.caretLeft,
                    color: AppTheme.textPrimaryColor(context),
                    size: AppIconSize.sm,
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Text(
          AppLocalizations.of(context)?.paymentSettingsTitle ?? "Payment Settings",
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimaryColor(context),
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        children: [
          _buildStaggeredItem(
            index: 0,
            child: _buildHeader(context),
          ),
          const SizedBox(height: 48),
          
          _buildStaggeredItem(
            index: 1,
            child: _buildSectionTitle("DIGITAL WALLET", isDark),
          ),
          
          _buildStaggeredItem(
            index: 2,
            child: _ApplePayPremiumButton(
              hasLinked: hasLinked,
              isLoading: _isLoadingApplePay,
              onTap: () => _handleManageWidget('apple'),
            ),
          ),
          
          const SizedBox(height: 32),
          
          _buildStaggeredItem(
            index: 3,
            child: _buildSectionTitle("MANUAL ENTRY", isDark),
          ),
          
          _buildStaggeredItem(
            index: 4,
            child: _PremiumOptionRow(
              icon: PhosphorIcons.creditCard,
              title: "Credit or Debit Card",
              subtitle: "Add a card for seamless transactions",
              isLoading: _isLoadingCard,
              onTap: () => _handleManageWidget('card'),
            ),
          ),
          const SizedBox(height: 12),
          
          _buildStaggeredItem(
            index: 5,
            child: _PremiumOptionRow(
              icon: PhosphorIcons.bank,
              title: "Bank Account",
              subtitle: "Link an account for direct transfers",
              isLoading: _isLoadingBank,
              onTap: () => _handleManageWidget('bank'),
            ),
          ),
          
          const SizedBox(height: 48),
          _buildStaggeredItem(
            index: 6,
            child: Text(
              AppLocalizations.of(context)?.paymentSettingsFootnote ?? "Transactions are securely encrypted.",
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? Colors.white30 : Colors.black38,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Premium Components
// ─────────────────────────────────────────────────────────────────────────────

class _ApplePayPremiumButton extends StatefulWidget {
  final bool hasLinked;
  final bool isLoading;
  final VoidCallback onTap;

  const _ApplePayPremiumButton({
    required this.hasLinked,
    required this.isLoading,
    required this.onTap,
  });

  @override
  State<_ApplePayPremiumButton> createState() => _ApplePayPremiumButtonState();
}

class _ApplePayPremiumButtonState extends State<_ApplePayPremiumButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isIOS = !kIsWeb && Platform.isIOS;
    final buttonText = isIOS ? "Apple Pay" : "Google Pay";
    // Using a more distinct google icon fallback if possible, or standard.
    final iconData = isIOS ? PhosphorIcons.appleLogo : PhosphorIcons.googleLogo;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Absolute contrast
    final bgColor = isDark ? Colors.white : Colors.black;
    final fgColor = isDark ? Colors.black : Colors.white;

    return Semantics(
      button: true,
      enabled: !widget.isLoading,
      label: widget.hasLinked ? "Manage $buttonText" : "Set up with $buttonText",
      child: GestureDetector(
        onTapDown: widget.isLoading ? null : (_) => setState(() => _isPressed = true),
        onTapUp: widget.isLoading ? null : (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              // Replaced cheap shadow with solid structure
              border: Border.all(color: isDark ? Colors.transparent : Colors.black12, width: 1),
            ),
            child: widget.isLoading 
              ? Center(
                  child: SizedBox(
                    height: 22, 
                    width: 22, 
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: fgColor)
                  )
                )
              : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(iconData, color: fgColor, size: 22),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      widget.hasLinked ? "Manage $buttonText" : "Set up with $buttonText",
                      style: TextStyle(
                        color: fgColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumOptionRow extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isLoading;
  final VoidCallback onTap;

  const _PremiumOptionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isLoading,
    required this.onTap,
  });

  @override
  State<_PremiumOptionRow> createState() => _PremiumOptionRowState();
}

class _PremiumOptionRowState extends State<_PremiumOptionRow> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final borderColor = isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08);
    final bgColor = isDark ? const Color(0xFF161618) : Colors.white;
    final iconColor = isDark ? Colors.white : Colors.black87;

    return Semantics(
      button: true,
      enabled: !widget.isLoading,
      label: "${widget.title}. ${widget.subtitle}",
      child: GestureDetector(
        onTapDown: widget.isLoading ? null : (_) => setState(() => _isPressed = true),
        onTapUp: widget.isLoading ? null : (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 1),
            ),
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(widget.icon, color: iconColor, size: 26),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.white54 : Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.isLoading)
                  const SizedBox(
                    height: 20, 
                    width: 20, 
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryTeal)
                  )
                else
                  Icon(
                    PhosphorIcons.caretRight,
                    color: isDark ? Colors.white24 : Colors.black26,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// In-app WebView for iOS
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
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if(mounted) setState(() { _loading = true; _hasError = false; });
        },
        onPageFinished: (_) {
          if(mounted) setState(() => _loading = false);
        },
        onWebResourceError: (error) {
          if(mounted) setState(() { _loading = false; _hasError = true; });
        },
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
        title: Text(
          AppLocalizations.of(context)?.paymentSettingsWebviewTitle ?? "Secure Checkout",
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const AppIcon(PhosphorIcons.x),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          
          if (_loading)
            Container(
              color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.8),
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.primaryTeal),
              ),
            ),

          if (_hasError)
            Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(PhosphorIcons.warningCircle, size: 48, color: Colors.red.shade400),
                    const SizedBox(height: 16),
                    const Text("Failed to load secure payment page.", style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor(context),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _controller.reload(),
                      child: const Text("Try Again"),
                    )
                  ],
                ),
              ),
            )
        ],
      ),
    );
  }
}
