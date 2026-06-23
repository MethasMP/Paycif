import 'dart:io' show Platform;
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:frontend/core/l10n/generated/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:frontend/features/profile/domain/saved_card.dart';
import 'package:frontend/features/payment/presentation/payment_controller.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'dart:ui' as ui;

/// ─────────────────────────────────────────────────────────────────────────────
/// REDESIGNED PAYMENT SETTINGS SCREEN
/// - Interactive 3D Card Pager Carousel
/// - Pure Design Aesthetics: No noise, high tactility, mesh gradients
/// - Dynamic Details Panel: Showcases Card Health Score & quick controls
/// - Premium Micro-interactions and Haptic Feedback
/// ─────────────────────────────────────────────────────────────────────────────

class PaymentSettingsScreen extends StatefulWidget {
  const PaymentSettingsScreen({super.key});

  @override
  State<PaymentSettingsScreen> createState() => _PaymentSettingsScreenState();
}

class _PaymentSettingsScreenState extends State<PaymentSettingsScreen> {
  late PageController _pageController;
  double _currentPage = 0.0;
  bool _isEditMode = false;
  bool _isProcessing = false;
  bool _hasInitializedPage = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.82)
      ..addListener(_onPageScroll);

    // 🚀 Proactive Fetch: Ensure we have the latest defaults immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<PaymentController>().fetchData(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageScroll() {
    if (mounted) {
      setState(() {
        _currentPage = _pageController.page ?? 0.0;
      });
    }
  }

  /// ─── ID NORMALIZATION ───
  String _normalizeId(String id, String? type) {
    if (id == 'apple_pay') return id;
    if (type == 'card' && !id.startsWith('card_')) return 'card_$id';
    return id;
  }

  Future<void> _selectMethod(String methodId) async {
    final l10n = AppLocalizations.of(context)!;
    if (_isProcessing) return;

    final controller = context.read<PaymentController>();
    if (controller.preferredMethodId == methodId) return;

    setState(() => _isProcessing = true);
    HapticFeedback.selectionClick();

    try {
      String type = 'card';
      String realId = methodId;

      if (methodId.startsWith('card_')) {
        final strippedOnce = methodId.replaceFirst('card_', '');
        realId = strippedOnce;
        type = 'card';
      } else {
        type = methodId;
      }

      await controller.updatePreference(realId, type);

      if (mounted) {
        setState(() => _isProcessing = false);
      }
    } catch (e) {
      debugPrint("Failed to update preference: $e");
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.paymentFailedSetDefault)));
      }
    }
  }

  Future<void> _navigateToAddCard() async {
    HapticFeedback.mediumImpact();
    await context.push('/add_card');
  }

  void _toggleEditMode() {
    HapticFeedback.selectionClick();
    setState(() => _isEditMode = !_isEditMode);
  }

  Future<bool?> _confirmDeleteCard(SavedCard card) async {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      PhosphorIcons.trash,
                      color: Colors.redAccent,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.cardDeleteTitle,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.cardDeleteConfirm(card.lastDigits),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondaryColor(context),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: isDark ? Colors.white24 : Colors.black12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            l10n.commonCancel,
                            style: TextStyle(
                              color: AppTheme.textPrimaryColor(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                          ),
                          child: Text(
                            l10n.commonDelete,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteCard(String cardId) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await context.read<PaymentController>().deleteCard(cardId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.cardDeleteSuccess)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paymentController = context.watch<PaymentController>();

    final savedCards = paymentController.savedCards;
    final isLoading = paymentController.isLoading;

    // Determine Apple Pay eligibility
    final isApplePayAvailable = (Platform.isIOS || Platform.isMacOS);

    // Build standard list of methods for selection resolution
    final prefType = paymentController.preferredMethodType;
    final prefId = paymentController.preferredMethodId;

    String effectiveType;
    String? effectiveCardId;

    final exactCardIndex = savedCards.indexWhere(
      (c) =>
          prefType == 'card' &&
          (_normalizeId(prefId ?? '', 'card') == _normalizeId(c.id, 'card') ||
              prefId == c.id),
    );

    if (prefType == 'apple_pay') {
      effectiveType = 'apple_pay';
    } else if (exactCardIndex != -1) {
      effectiveType = 'card';
      effectiveCardId = savedCards[exactCardIndex].id;
    } else {
      if (isApplePayAvailable) {
        effectiveType = 'apple_pay';
      } else if (savedCards.isNotEmpty) {
        effectiveType = 'card';
        effectiveCardId = savedCards.first.id;
      } else {
        effectiveType = 'none';
      }
    }

    // Convert savedCards to interactive method models
    final List<_PaymentMethodItem> items = [];
    if (isApplePayAvailable) {
      items.add(_PaymentMethodItem(
        id: 'apple_pay',
        type: 'apple_pay',
        brand: 'apple_pay',
        lastDigits: '',
        expiry: '',
        healthScore: 100,
      ));
    }
    for (final card in savedCards) {
      items.add(_PaymentMethodItem(
        id: card.id,
        type: 'card',
        brand: card.brand,
        lastDigits: card.lastDigits,
        expiry: card.formattedExpiry,
        healthScore: card.healthScore,
        cardObject: card,
      ));
    }

    // Initialize carousel page matching current default
    if (!isLoading && !_hasInitializedPage && items.isNotEmpty) {
      _hasInitializedPage = true;
      int defaultIdx = 0;
      for (int i = 0; i < items.length; i++) {
        if (items[i].type == effectiveType) {
          if (effectiveType == 'apple_pay' || items[i].id == effectiveCardId) {
            defaultIdx = i;
            break;
          }
        }
      }
      _currentPage = defaultIdx.toDouble();
      _pageController = PageController(
        viewportFraction: 0.82,
        initialPage: defaultIdx,
      )..addListener(_onPageScroll);
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.paymentSettingsTitle),
        actions: [
          if (savedCards.isNotEmpty)
            TextButton(
              onPressed: _toggleEditMode,
              child: Text(
                _isEditMode ? l10n.commonDone : l10n.commonEdit,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: isDark ? Colors.white70 : AppTheme.infoBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: isLoading && savedCards.isEmpty
          ? _buildSkeletonLoader(isDark)
          : Stack(
              children: [
                // Subtle Ambient Background Glow in dark mode
                if (isDark)
                  Positioned(
                    top: -100,
                    right: -50,
                    child: Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppTheme.primaryColor(context).withValues(alpha: 0.08),
                            AppTheme.primaryColor(context).withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Main Scrollable Area
                SafeArea(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        
                        // 1. Horizontal Carousel Pager
                        SizedBox(
                          height: 220,
                          child: PageView.builder(
                            controller: _pageController,
                            itemCount: items.length + 1, // Last item is "Add Card"
                            clipBehavior: Clip.none,
                            physics: const BouncingScrollPhysics(),
                            itemBuilder: (context, index) {
                              // 3D Perspective Scale & Opacity & Rotation Calculations
                              final double difference = index - _currentPage;
                              final double scale = (1.0 - (difference.abs() * 0.12)).clamp(0.8, 1.0);
                              final double opacity = (1.0 - (difference.abs() * 0.4)).clamp(0.5, 1.0);
                              final double rotation = (difference * 0.06).clamp(-0.15, 0.15);
                              final double translationX = difference * -16.0;

                              final isCurrent = index == _currentPage.round();

                              // Case: "Add Card" placeholder card at the end
                              if (index == items.length) {
                                return Transform.translate(
                                  offset: Offset(translationX, 0),
                                  child: Transform.rotate(
                                    angle: rotation,
                                    child: Transform.scale(
                                      scale: scale,
                                      child: Opacity(
                                        opacity: opacity,
                                        child: _buildAddCardPlaceholder(isDark),
                                      ),
                                    ),
                                  ),
                                );
                              }

                              final item = items[index];
                              final isDefault = item.type == effectiveType &&
                                  (item.type == 'apple_pay' || item.id == effectiveCardId);

                              return GestureDetector(
                                onTap: () {
                                  if (!isCurrent) {
                                    HapticFeedback.selectionClick();
                                    _pageController.animateToPage(
                                      index,
                                      duration: const Duration(milliseconds: 350),
                                      curve: Curves.easeOutCubic,
                                    );
                                  }
                                },
                                child: Transform.translate(
                                  offset: Offset(translationX, 0),
                                  child: Transform.rotate(
                                    angle: rotation,
                                    child: Transform.scale(
                                      scale: scale,
                                      child: Opacity(
                                        opacity: opacity,
                                        child: _PremiumCardWidget(
                                          item: item,
                                          isDefault: isDefault,
                                          isDark: isDark,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Page Dots Indicator
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(items.length + 1, (index) {
                              final isCurrent = index == _currentPage.round();
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                width: isCurrent ? 18 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: isCurrent
                                      ? (isDark ? AppTheme.primaryColor(context) : AppTheme.primaryTeal)
                                      : (isDark ? Colors.white24 : Colors.black12),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              );
                            }),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // 2. Focused Method Details Container
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0.0, 0.05),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              );
                            },
                            child: _buildDetailsPanel(
                              items,
                              _currentPage.round(),
                              effectiveType,
                              effectiveCardId,
                              isDark,
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),

                        // 3. Secure Footnotes
                        _buildTrustFooter(isDark),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // Add Card Carousel Item
  Widget _buildAddCardPlaceholder(bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black12,
          style: BorderStyle.solid,
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _navigateToAddCard,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    PhosphorIcons.plus,
                    color: isDark ? AppTheme.primaryColor(context) : AppTheme.primaryTeal,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.sheetAddPayment,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Focused Details Panel below the cards
  Widget _buildDetailsPanel(
    List<_PaymentMethodItem> items,
    int activeIndex,
    String effectiveType,
    String? effectiveCardId,
    bool isDark,
  ) {
    final l10n = AppLocalizations.of(context)!;

    // Case: Carousel is currently focused on "Add Card"
    if (activeIndex >= items.length) {
      return Container(
        key: const ValueKey('add_card_details'),
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? Theme.of(context).colorScheme.surface : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
          ),
        ),
        child: Column(
          children: [
            Text(
              l10n.paymentEmptyTitle,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.paymentEmptyDesc,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondaryColor(context),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _navigateToAddCard,
                icon: const Icon(PhosphorIcons.plus, size: 20),
                label: Text(l10n.paymentAddMethod),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final item = items[activeIndex];
    final isDefault = item.type == effectiveType &&
        (item.type == 'apple_pay' || item.id == effectiveCardId);

    final idToSelect = _normalizeId(item.id, item.type);

    return Container(
      key: ValueKey(item.id),
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Brand details and Default badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.type == 'apple_pay'
                        ? 'Apple Pay'
                        : '${item.brand.toUpperCase()} •••• ${item.lastDigits}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.type == 'apple_pay'
                        ? l10n.paymentReliable
                        : 'Expires ${item.expiry}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondaryColor(context),
                    ),
                  ),
                ],
              ),
              if (isDefault)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.successGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppTheme.successGreen.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(PhosphorIcons.checkCircle, color: AppTheme.successGreen, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        l10n.commonDefault,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.successGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(height: 1, thickness: 0.5, color: Colors.white10),
          const SizedBox(height: 20),

          // Row 2: Card Health Score widget
          _buildHealthMeter(item.healthScore, isDark),

          const SizedBox(height: 24),

          // Row 3: Action CTAs
          Row(
            children: [
              if (!isDefault)
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _selectMethod(idToSelect),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? AppTheme.accentGoldDisabled : AppTheme.accentGold,
                      foregroundColor: AppTheme.accentGoldDark,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    child: Text(
                      l10n.commonApply,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              if (!isDefault) const SizedBox(width: 12),
              
              // Deletion Action
              if (item.type != 'apple_pay')
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      if (item.cardObject != null) {
                        _confirmDeleteCard(item.cardObject!).then((confirmed) {
                          if (confirmed == true) {
                            _deleteCard(item.id);
                          }
                        });
                      }
                    },
                    icon: const Icon(PhosphorIcons.trash, size: 18),
                    label: Text(l10n.commonDelete),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent, width: 1.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // Health Score Meter with customizable circular indicator
  Widget _buildHealthMeter(int score, bool isDark) {
    Color indicatorColor;
    String title;
    String description;

    if (score == 100) {
      indicatorColor = AppTheme.successGreen; // Emerald
      title = "Card Status: Perfect";
      description = "Ready for all international payments. 0% historic latency.";
    } else if (score >= 75) {
      indicatorColor = AppTheme.warningAmber; // Amber
      title = "Card Status: Good";
      description = "Slight processing latency. May occasionally prompt manual 3DS.";
    } else {
      indicatorColor = AppTheme.errorRed; // Red
      title = "Card Status: Attention";
      description = "High rate of network rejections. We recommend checking with bank.";
    }

    return Row(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                value: score / 100,
                strokeWidth: 4.5,
                backgroundColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                valueColor: AlwaysStoppedAnimation<Color>(indicatorColor),
              ),
            ),
            Text(
              "$score%",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: indicatorColor,
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  color: AppTheme.textSecondaryColor(context),
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrustFooter(bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                PhosphorIcons.lock,
                size: 14,
                color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.7),
              ),
              const SizedBox(width: 6),
              Text(
                l10n.biometricLogin,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "PCI-DSS Level 1 Encrypted Vault",
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }

  // Premium Shimmering Skeleton Loader mapping the carousel design
  Widget _buildSkeletonLoader(bool isDark) {
    final baseColor = isDark ? Theme.of(context).colorScheme.surfaceContainerHighest : Colors.grey[200];
    final highlightColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.white.withValues(alpha: 0.5);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          // 1. Shimmer Card shape
          Container(
            height: 200,
            margin: const EdgeInsets.symmetric(horizontal: 32),
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(20),
            ),
          )
              .animate(onPlay: (controller) => controller.repeat())
              .shimmer(duration: 1200.ms, color: highlightColor),
          
          const SizedBox(height: 48),

          // 2. Shimmer details panel
          Container(
            height: 260,
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? Theme.of(context).colorScheme.surface : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? Colors.white10 : Colors.grey[100]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 140,
                  height: 20,
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                )
                    .animate(onPlay: (controller) => controller.repeat())
                    .shimmer(duration: 1200.ms, color: highlightColor),
                
                const SizedBox(height: 8),

                Container(
                  width: 80,
                  height: 12,
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                )
                    .animate(onPlay: (controller) => controller.repeat())
                    .shimmer(duration: 1200.ms, color: highlightColor),

                const SizedBox(height: 24),
                const Divider(height: 1, color: Colors.white10),
                const SizedBox(height: 24),

                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: baseColor,
                        shape: BoxShape.circle,
                      ),
                    )
                        .animate(onPlay: (controller) => controller.repeat())
                        .shimmer(duration: 1200.ms, color: highlightColor),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 100,
                            height: 14,
                            decoration: BoxDecoration(
                              color: baseColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          )
                              .animate(onPlay: (controller) => controller.repeat())
                              .shimmer(duration: 1200.ms, color: highlightColor),
                          const SizedBox(height: 8),
                          Container(
                            width: 160,
                            height: 10,
                            decoration: BoxDecoration(
                              color: baseColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          )
                              .animate(onPlay: (controller) => controller.repeat())
                              .shimmer(duration: 1200.ms, color: highlightColor),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INDIVIDUAL PREMIUM CREDIT CARD CANVAS WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class _PremiumCardWidget extends StatelessWidget {
  final _PaymentMethodItem item;
  final bool isDefault;
  final bool isDark;

  const _PremiumCardWidget({
    required this.item,
    required this.isDefault,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    // 🎨 Curate luxurious mesh card gradient based on brand
    LinearGradient cardGradient;
    Color textColor = Colors.white;
    Color cardBorder = Colors.white.withValues(alpha: 0.12);

    switch (item.brand.toLowerCase()) {
      case 'apple_pay':
        // High-Tech obsidian carbon look
        cardGradient = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F1211),
            Color(0xFF232B29),
            Color(0xFF131716),
          ],
        );
        cardBorder = Colors.white.withValues(alpha: 0.15);
        break;

      case 'visa':
        // Premium Oceanic Sapphire gradient
        cardGradient = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E3C72),
            Color(0xFF2A5298),
            Color(0xFF1A305B),
          ],
        );
        break;

      case 'mastercard':
        // Elegant Carbon/Sunset Coral split glow
        cardGradient = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1F2022),
            Color(0xFF333538),
            Color(0xFF2B1615),
          ],
        );
        break;

      case 'amex':
      case 'american_express':
        // Champagne bronze metallic gradient
        cardGradient = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFDFBA73),
            Color(0xFFC5A059),
            Color(0xFF9E7831),
          ],
        );
        textColor = const Color(0xFF3C2E11);
        cardBorder = Colors.black.withValues(alpha: 0.1);
        break;

      default:
        // Forest green / dark brand theme
        cardGradient = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryTeal,
            AppTheme.primaryTealDark,
            Color(0xFF032D24),
          ],
        );
        break;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        gradient: cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder, width: 1.2),
        boxShadow: [
          // Subtle glow shadow for default or active card
          BoxShadow(
            color: isDefault
                ? AppTheme.primaryColor(context).withValues(alpha: isDark ? 0.16 : 0.12)
                : Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            spreadRadius: isDefault ? 2 : 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // MasterCard design background circles overlay
            if (item.brand.toLowerCase() == 'mastercard')
              Positioned(
                bottom: -20,
                right: -20,
                child: Opacity(
                  opacity: 0.15,
                  child: Row(
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: const BoxDecoration(
                          color: AppTheme.errorRed,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Transform.translate(
                        offset: const Offset(-30, 0),
                        child: Container(
                          width: 90,
                          height: 90,
                          decoration: const BoxDecoration(
                            color: AppTheme.warningAmber,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Visa branding wave watermark overlay
            if (item.brand.toLowerCase() == 'visa')
              Positioned(
                top: -50,
                right: -50,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.03), width: 30),
                  ),
                ),
              ),

            // Content padding
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Row 1: Chip visual and Default active badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Contact chip visual (for standard cards)
                      if (item.type != 'apple_pay')
                        Container(
                          width: 42,
                          height: 32,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: item.brand.toLowerCase() == 'amex'
                                  ? [const Color(0xFFE5D3B3), const Color(0xFFB5A28A)]
                                  : [const Color(0xFFF3E5AB), const Color(0xFFD4AF37)],
                            ),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.black12, width: 0.5),
                          ),
                        )
                      else
                        Icon(PhosphorIcons.appleLogo, color: textColor, size: 28),

                      // Selection LED badge (Glowing)
                      if (isDefault)
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: AppTheme.successGreen,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.successGreen,
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  // Row 2: Card Number
                  if (item.type != 'apple_pay')
                    Text(
                      '••••  ••••  ••••  ${item.lastDigits}',
                      style: TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.0,
                        color: textColor.withValues(alpha: 0.9),
                        shadows: const [
                          Shadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 1.5),
                          ),
                        ],
                      ),
                    )
                  else
                    Text(
                      'Tokenized Payment',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                        color: textColor.withValues(alpha: 0.7),
                      ),
                    ),

                  // Row 3: Holder name & Expiry
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.type == 'apple_pay' ? 'DEVICE ACCOUNT' : 'PAYCIF MEMBER',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: textColor.withValues(alpha: 0.65),
                        ),
                      ),
                      if (item.type != 'apple_pay')
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'EXPIRES',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: textColor.withValues(alpha: 0.5),
                              ),
                            ),
                            Text(
                              item.expiry,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PAYMENT METHOD ITEM VIEWMODEL
// ─────────────────────────────────────────────────────────────────────────────

class _PaymentMethodItem {
  final String id;
  final String type;
  final String brand;
  final String lastDigits;
  final String expiry;
  final int healthScore;
  final SavedCard? cardObject;

  _PaymentMethodItem({
    required this.id,
    required this.type,
    required this.brand,
    required this.lastDigits,
    required this.expiry,
    required this.healthScore,
    this.cardObject,
  });
}
