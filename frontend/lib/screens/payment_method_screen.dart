import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'add_card_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/saved_card.dart';
import '../services/api_service.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// PAYMENT METHOD SCREEN
/// Refactored for flat hierarchy, swipe-to-delete, and visual consistency
/// ─────────────────────────────────────────────────────────────────────────────

class PaymentMethodScreen extends StatefulWidget {
  const PaymentMethodScreen({super.key});

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  String? _selectedMethodId;
  String? _preferredMethodId;
  String? _preferredMethodType;
  List<SavedCard> _savedCards = [];
  bool _isLoading = true;
  bool _isEditMode = false;
  bool _isProcessing = false; // Guard for rapid clicks
  final ApiService _apiService = ApiService();

  // ─── DESIGN CONSTANTS ───
  static const double _iconSize = 40.0;
  static const double _iconRadius = 10.0;
  static const double _radioSize = 22.0;
  static const double _itemSpacing = 14.0;
  static const double _tilePadding = 14.0;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    // 1. Optimistic Check: If we already have cached cards, show them immediately!
    final cachedCards = ApiService.getCachedCards();
    if (cachedCards != null && cachedCards.isNotEmpty) {
      setState(() {
        _savedCards = cachedCards;
        _isLoading = false; // "Instant Load" experience
      });
      debugPrint('🚀 Instant Load from Frontend Cache');
    } else {
      setState(() => _isLoading = true);
    }

    try {
      // 2. Fetch both Profile and Saved Cards in parallel
      // getSavedCards will return data from PostgreSQL Cache (<10ms) if available
      final results = await Future.wait([
        _apiService.getUserProfile(),
        _apiService.getSavedCards(),
      ]);

      final profile = results[0] as Map<String, dynamic>?;
      final cards = results[1] as List<SavedCard>;

      if (profile != null) {
        _preferredMethodId = profile['preferred_payment_method_id'];
        _preferredMethodType = profile['preferred_payment_method_type'];
      }

      if (mounted) {
        setState(() {
          _savedCards = cards;
          _isLoading = false;
          _selectedMethodId = _preferredMethodId;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint('Error fetching data: $e');
    }
  }

  void _selectMethod(String methodId) {
    if (_isProcessing) return;
    _isProcessing = true;

    HapticFeedback.selectionClick();
    setState(() => _selectedMethodId = methodId);
    debugPrint('Selected payment method: $methodId');

    // Reset processing shortly after to allow new selection if needed,
    // or keep locked if you're navigating away.
    if (methodId == 'add_new_card') {
      Future.delayed(const Duration(milliseconds: 200), () {
        _isProcessing = false;
        _navigateToAddCard();
      });
    } else {
      // In a real flow, you might wait for a "Continue" button,
      // but if selection triggers an action, keep it guarded.
      Future.delayed(const Duration(milliseconds: 300), () {
        _isProcessing = false;
      });
    }
  }

  Future<void> _navigateToAddCard() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddCardScreen()),
    );
    if (result != null) {
      final cards = await _apiService.getSavedCards(forceRefresh: true);
      if (mounted) setState(() => _savedCards = cards);
    }
  }

  void _toggleEditMode() {
    HapticFeedback.selectionClick();
    setState(() => _isEditMode = !_isEditMode);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Payment Method'),
        centerTitle: true,
        actions: [
          if (_savedCards.isNotEmpty)
            TextButton(
              onPressed: _toggleEditMode,
              child: Text(
                _isEditMode ? 'Done' : 'Edit',
                style: TextStyle(
                  color: isDark ? Colors.white70 : const Color(0xFF3B82F6),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading && _savedCards.isEmpty
          ? _buildSkeletonLoader(isDark)
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: _buildPaymentList(isDark),
            ),
    );
  }

  List<Widget> _buildPaymentList(bool isDark) {
    final List<Widget> items = [];

    // 1. Apple Pay (iOS only)
    if (Platform.isIOS) {
      items.add(
        _buildMethodTile(
          id: 'apple_pay',
          icon: Icons.apple,
          title: 'Apple Pay',
          subtitle: 'Fast and secure',
          isDark: isDark,
          isRecommended: _preferredMethodId == 'apple_pay',
        ),
      );
      items.add(_buildDivider(isDark));
    }

    // 2. Saved Cards (Swipeable)
    for (int i = 0; i < _savedCards.length; i++) {
      final card = _savedCards[i];
      items.add(_buildSwipeableCardTile(card, isDark));
      if (i < _savedCards.length - 1 || true) {
        items.add(_buildDivider(isDark));
      }
    }

    // 3. Digital Wallets
    items.add(
      _buildMethodTile(
        id: 'paypal',
        icon: Icons.paypal_outlined,
        title: 'PayPal',
        subtitle: 'Pay with balance or card',
        isDark: isDark,
        isRecommended: _preferredMethodId == 'paypal',
      ),
    );
    items.add(_buildDivider(isDark));

    items.add(
      _buildMethodTile(
        id: 'alipay',
        icon: Icons.account_balance_wallet_outlined,
        title: 'Alipay',
        subtitle: 'Popular in China',
        isDark: isDark,
        isRecommended: _preferredMethodId == 'alipay',
      ),
    );
    items.add(_buildDivider(isDark));

    items.add(
      _buildMethodTile(
        id: 'wechat_pay',
        icon: Icons.chat_bubble_outline,
        title: 'WeChat Pay',
        subtitle: 'Popular in Asia',
        isDark: isDark,
        isRecommended: _preferredMethodId == 'wechat_pay',
      ),
    );
    items.add(_buildDivider(isDark));

    items.add(
      _buildMethodTile(
        id: 'kakao_pay',
        icon: Icons.chat_rounded,
        title: 'KakaoPay',
        subtitle: 'Popular in Korea',
        isDark: isDark,
        isRecommended: _preferredMethodId == 'kakao_pay',
      ),
    );

    // 4. Add New Card (at the very bottom)
    items.add(const SizedBox(height: 24));
    items.add(_buildAddNewCardTile(isDark));

    // 5. Trust Footer
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

  Widget _buildSwipeableCardTile(SavedCard card, bool isDark) {
    final id = 'card_${card.id}';
    final isSelected = _selectedMethodId == id;
    final isRecommended =
        _preferredMethodId == id ||
        (_preferredMethodType == 'card' && _preferredMethodId == card.id);

    return Dismissible(
      key: Key(card.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDeleteCard(card),
      onDismissed: (_) {
        // Essential: Remove from local state IMMEDIATELY after dismissal
        // to prevent "A dismissed Dismissible widget is still part of the tree"
        setState(() {
          _savedCards.removeWhere((c) => c.id == card.id);
        });
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
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          child: Row(
            children: [
              // Icon Container
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
              // Title & Subtitle
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
                                0xFF3B82F6,
                              ).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Default',
                              style: TextStyle(
                                color: Color(0xFF3B82F6),
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
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
              // Edit Mode: Show Delete Icon
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
                _buildRadioIndicator(isSelected, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirmDeleteCard(SavedCard card) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Card'),
        content: Text(
          'Are you sure you want to delete the card ending in ${card.lastDigits}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCard(String cardId, {bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      await _apiService.deleteCard(cardId);

      // If NOT silent, we refresh everything.
      // If silent (from Dismissible), we already removed it from the list locally.
      if (!silent) {
        await _fetchInitialData();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Card deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        if (!silent) {
          setState(() => _isLoading = false);
          // If it failed on server, it might still be in our local list if we deleted it silently?
          // Actually if it failed, we should probably re-fetch to be safe.
          _fetchInitialData();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Widget _buildMethodTile({
    required String id,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
    bool isRecommended = false,
  }) {
    final isSelected = _selectedMethodId == id;

    return GestureDetector(
      onTap: () => _selectMethod(id),
      child: Container(
        padding: EdgeInsets.all(_tilePadding),
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        child: Row(
          children: [
            // Icon Container
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
            // Title & Subtitle
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
                              0xFF3B82F6,
                            ).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Default',
                            style: TextStyle(
                              color: Color(0xFF3B82F6),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
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
            _buildRadioIndicator(isSelected, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildRadioIndicator(bool isSelected, bool isDark) {
    return Container(
      width: _radioSize,
      height: _radioSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? const Color(0xFF3B82F6) : Colors.transparent,
        border: Border.all(
          color: isSelected
              ? const Color(0xFF3B82F6)
              : (isDark ? Colors.white30 : Colors.grey[300]!),
          width: 2,
        ),
      ),
      child: isSelected
          ? const Icon(Icons.check, color: Colors.white, size: 14)
          : null,
    );
  }

  Widget _buildAddNewCardTile(bool isDark) {
    return GestureDetector(
      onTap: _navigateToAddCard,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E293B).withValues(alpha: 0.5)
              : Colors.white,
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
              'Add New Card',
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock_outline, size: 14, color: Colors.grey[500]),
        const SizedBox(width: 6),
        Text(
          'Secure payment',
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
      ],
    );
  } // Added missing '}' here to close _buildTrustFooter

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
                color: isDark
                    ? const Color(0xFF0F172A)
                    : const Color(0xFFF8FAFC),
              ),
              child: Row(
                children: [
                  // Icon Placeholder
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
                  // Text Placeholder
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
                  // Radio Placeholder
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
