import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/l10n/generated/app_localizations.dart';
import 'add_card_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/saved_card.dart';
import '../controllers/payment_controller.dart';
import 'package:provider/provider.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// PAYMENT SETTINGS SCREEN
/// "Tap. Pay. Done." Philosophy
/// - Removed "Noise" (PayPal, Alipay, etc.)
/// - No Radio Buttons (Implicit selection via "Default" badge & Checkmark)
/// - Focus on Saved Cards & Apple/Google Pay
/// ─────────────────────────────────────────────────────────────────────────────

class PaymentSettingsScreen extends StatefulWidget {
  const PaymentSettingsScreen({super.key});

  @override
  State<PaymentSettingsScreen> createState() => _PaymentSettingsScreenState();
}

class _PaymentSettingsScreenState extends State<PaymentSettingsScreen> {
  bool _isEditMode = false;
  bool _isProcessing = false;

  // ─── DESIGN CONSTANTS ───
  static const double _iconSize = 40.0;
  static const double _iconRadius = 10.0;
  // static const double _radioSize = 22.0; // Removed in favor of checkmark
  static const double _itemSpacing = 14.0;
  static const double _tilePadding = 14.0;

  @override
  void initState() {
    super.initState();
    // 🚀 Proactive Fetch: Ensure we have the latest defaults immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<PaymentController>().fetchData(silent: true);
      }
    });
  }

  /// ─── ID NORMALIZATION ───
  /// Ensures consistent ID format for selection comparison.
  /// Prevents "double-prefixing" like card_card_test_...
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

    _isProcessing = true;
    HapticFeedback.selectionClick();

    try {
      String type = 'card';
      String realId = methodId;

      if (methodId.startsWith('card_')) {
        final strippedOnce = methodId.replaceFirst('card_', '');
        if (strippedOnce.startsWith('card_')) {
          realId = strippedOnce;
        } else {
          realId = strippedOnce;
        }
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
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddCardScreen()),
    );
    if (result != null) {
      // PaymentController handles refresh after add
    }
  }

  void _toggleEditMode() {
    HapticFeedback.selectionClick();
    setState(() => _isEditMode = !_isEditMode);
  }

  Future<bool?> _confirmDeleteCard(SavedCard card) async {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.cardDeleteTitle),
        content: Text(l10n.cardDeleteConfirm(card.lastDigits)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCard(String cardId, {bool silent = false}) async {
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

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.paymentSettingsTitle),
        centerTitle: true,
        actions: [
          if (savedCards.isNotEmpty)
            TextButton(
              onPressed: _toggleEditMode,
              child: Text(
                _isEditMode ? l10n.commonDone : l10n.commonEdit,
                style: TextStyle(
                  color: isDark ? Colors.white70 : const Color(0xFF3B82F6),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
      body: isLoading && savedCards.isEmpty
          ? _buildSkeletonLoader(isDark)
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: _buildPaymentList(isDark, paymentController),
            ),
    );
  }

  List<Widget> _buildPaymentList(bool isDark, PaymentController controller) {
    final l10n = AppLocalizations.of(context)!;
    final List<Widget> items = [];
    final prefType = controller.preferredMethodType;
    final prefId = controller.preferredMethodId;
    final savedCards = controller.savedCards;

    // 💎 World-Class Selection Resolver
    // 1. Apple Pay available?
    final isApplePayAvailable = (Platform.isIOS || Platform.isMacOS);

    // 2. Is anything explicitly set?
    final hasExactApplePay = prefType == 'apple_pay';
    final exactCardIndex = savedCards.indexWhere(
      (c) =>
          prefType == 'card' &&
          (_normalizeId(prefId ?? '', 'card') == _normalizeId(c.id, 'card') ||
              prefId == c.id),
    );

    // 3. Determine the "Effective" Selection
    String effectiveType;
    String? effectiveCardId;

    if (hasExactApplePay) {
      effectiveType = 'apple_pay';
    } else if (exactCardIndex != -1) {
      effectiveType = 'card';
      effectiveCardId = savedCards[exactCardIndex].id;
    } else {
      // 🔄 Fallback Logic (Matching TopUp View)
      if (isApplePayAvailable) {
        effectiveType = 'apple_pay';
      } else if (savedCards.isNotEmpty) {
        effectiveType = 'card';
        effectiveCardId = savedCards.first.id;
      } else {
        effectiveType = 'none';
      }
    }

    // 1. Apple/Google Pay Row
    if (isApplePayAvailable) {
      final isSelected = effectiveType == 'apple_pay';
      items.add(
        _buildMethodTile(
          id: 'apple_pay',
          icon: Icons.apple,
          title: 'Apple Pay',
          subtitle: l10n.paymentReliable,
          isDark: isDark,
          isRecommended: isSelected,
          isSelected: isSelected,
        ),
      );
      items.add(_buildDivider(isDark));
    }

    // 2. Saved Cards (Swipeable)
    for (int i = 0; i < savedCards.length; i++) {
      final card = savedCards[i];
      items.add(
        _buildSwipeableCardTile(
          card,
          isDark,
          controller,
          effectiveType,
          effectiveCardId,
        ),
      );
      if (i < savedCards.length - 1) {
        items.add(_buildDivider(isDark));
      }
    }

    // 3. Add New Card (at the very bottom)
    items.add(const SizedBox(height: 24));
    items.add(_buildAddNewCardTile(isDark));

    // 4. Trust Footer
    items.add(const SizedBox(height: 32));
    items.add(_buildTrustFooter(isDark));

    return items;
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 0.5,
      color: isDark ? Colors.white10 : Colors.grey[200],
    );
  }

  Widget _buildSwipeableCardTile(
    SavedCard card,
    bool isDark,
    PaymentController controller,
    String effectiveType,
    String? effectiveCardId,
  ) {
    final id = _normalizeId(card.id, 'card');
    final isSelected =
        effectiveType == 'card' &&
        (effectiveCardId == card.id ||
            _normalizeId(effectiveCardId ?? '', 'card') == id);
    final isRecommended = isSelected;

    return Dismissible(
      key: Key(card.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDeleteCard(card),
      onDismissed: (_) {
        _deleteCard(card.id, silent: true);
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.redAccent,
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
      ),
      child: GestureDetector(
        onTap: () => _selectMethod(id),
        child: Container(
          padding: EdgeInsets.all(_tilePadding),
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Row(
            children: [
              Container(
                width: _iconSize,
                height: _iconSize,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.grey[100],
                  borderRadius: BorderRadius.circular(_iconRadius),
                ),
                child: Icon(
                  Icons.credit_card,
                  color: isDark ? Colors.white70 : Colors.grey[700],
                  size: 22,
                ),
              ),
              SizedBox(width: _itemSpacing),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${card.brand} •••• ${card.lastDigits}',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                          ),
                        ),
                        if (isRecommended) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF10B981,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              AppLocalizations.of(context)!.commonDefault,
                              style: const TextStyle(
                                color: Color(0xFF10B981),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Expires ${card.formattedExpiry}',
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isEditMode)
                IconButton(
                  icon: const Icon(
                    Icons.remove_circle,
                    color: Colors.redAccent,
                    size: 22,
                  ),
                  onPressed: () {
                    if (_isProcessing) return;
                    _confirmDeleteCard(card).then((confirmed) {
                      if (confirmed == true) _deleteCard(card.id);
                    });
                  },
                )
              else
                _buildSelectionIndicator(isSelected, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMethodTile({
    required String id,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
    bool isRecommended = false,
    bool isSelected = false,
  }) {
    return GestureDetector(
      onTap: () => _selectMethod(id),
      child: Container(
        padding: EdgeInsets.all(_tilePadding),
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Row(
          children: [
            Container(
              width: _iconSize,
              height: _iconSize,
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey[100],
                borderRadius: BorderRadius.circular(_iconRadius),
              ),
              child: Icon(
                icon,
                color: isDark ? Colors.white70 : Colors.grey[700],
                size: 22,
              ),
            ),
            SizedBox(width: _itemSpacing),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                      if (isRecommended) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF10B981,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            AppLocalizations.of(context)!.commonDefault,
                            style: const TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            _buildSelectionIndicator(isSelected, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionIndicator(bool isSelected, bool isDark) {
    if (!isSelected) return const SizedBox(width: 26, height: 26);
    // 💎 World-Class Emerald Checkmark (Brand Signature)
    return Container(
      width: 26,
      height: 26,
      decoration: const BoxDecoration(
        color: Color(0xFF10B981),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
    );
  }

  Widget _buildAddNewCardTile(bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: _navigateToAddCard,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.grey[200]!,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_rounded,
              color: isDark ? Colors.white70 : Colors.grey[600],
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              l10n.sheetAddPayment,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.grey[800],
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrustFooter(bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock_outline, size: 14, color: Colors.grey[500]),
        const SizedBox(width: 6),
        Text(
          l10n.biometricLogin,
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSkeletonLoader(bool isDark) {
    final bgColor = isDark ? const Color(0xFF1E293B) : Colors.grey[200];
    final shimmerBase = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.white.withValues(alpha: 0.5);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Column(
          children: [
            Container(
              padding: EdgeInsets.all(_tilePadding),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
              ),
              child: Row(
                children: [
                  Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      )
                      .animate(onPlay: (controller) => controller.repeat())
                      .shimmer(duration: 1200.ms, color: shimmerBase),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                              width: 120,
                              height: 14,
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            )
                            .animate(
                              onPlay: (controller) => controller.repeat(),
                            )
                            .shimmer(
                              duration: 1200.ms,
                              delay: 100.ms,
                              color: shimmerBase,
                            ),
                        const SizedBox(height: 8),
                        Container(
                              width: 80,
                              height: 10,
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            )
                            .animate(
                              onPlay: (controller) => controller.repeat(),
                            )
                            .shimmer(
                              duration: 1200.ms,
                              delay: 200.ms,
                              color: shimmerBase,
                            ),
                      ],
                    ),
                  ),
                  Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: bgColor,
                          shape: BoxShape.circle,
                        ),
                      )
                      .animate(onPlay: (controller) => controller.repeat())
                      .shimmer(
                        duration: 1200.ms,
                        delay: 300.ms,
                        color: shimmerBase,
                      ),
                ],
              ),
            ),
            _buildDivider(isDark),
          ],
        );
      },
    );
  }
}
