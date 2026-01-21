import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'add_card_screen.dart';
import '../models/saved_card.dart';
import '../services/api_service.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// PAYMENT SELECTION SCREEN - Minimal Tourist-First Design
/// ─────────────────────────────────────────────────────────────────────────────

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  String? _selectedMethodId;
  List<SavedCard> _savedCards = [];
  bool _isLoadingCards = true;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _selectedMethodId = _getRecommendedMethod();
    _fetchSavedCards();
  }

  Future<void> _fetchSavedCards({bool forceRefresh = false}) async {
    if (!mounted) return;
    try {
      final cards = await _apiService.getSavedCards(forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          _savedCards = cards;
          _isLoadingCards = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingCards = false);
      }
      debugPrint('Error fetching cards: $e');
    }
  }

  String _getRecommendedMethod() {
    try {
      if (Platform.isIOS) return 'apple_pay';
      if (Platform.isAndroid) return 'google_pay';
    } catch (_) {}
    return 'card';
  }

  void _selectMethod(String methodId) {
    HapticFeedback.selectionClick();
    setState(() => _selectedMethodId = methodId);

    // Navigate immediately after selection
    Future.delayed(const Duration(milliseconds: 200), () {
      if (methodId == 'add_new_card') {
        _navigateToAddCard();
      } else if (methodId.startsWith('card_')) {
        // Selected a saved card - Proceed to payment logic
        // Navigator.push(context, MaterialPageRoute(builder: (_) => ProcessPaymentScreen(method: methodId)));
        debugPrint('Selected saved card: $methodId');
      } else {
        // Other methods
        // Navigator.push(context, MaterialPageRoute(builder: (_) => ProcessPaymentScreen(method: methodId)));
      }
    });
  }

  Future<void> _navigateToAddCard() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddCardScreen()),
    );
    if (result != null) {
      _fetchSavedCards(forceRefresh: true); // Refresh list if card added
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final recommended = _getRecommendedMethod();

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Payment Method'),
        automaticallyImplyLeading: false,
        // Style inherited from AppTheme.titleLarge via AppBarTheme.titleTextStyle
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          // ─── RECOMMENDED ────
          _buildSectionLabel('Recommended', isDark),
          const SizedBox(height: 10),
          _buildRecommendedTile(recommended, isDark),

          const SizedBox(height: 28),

          // ─── CARDS ────
          _buildSectionLabel('Payment Cards', isDark),
          const SizedBox(height: 10),

          if (_isLoadingCards)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_savedCards.isEmpty)
            // No cards -> "Add or Scan Card" style? Or just standard Tile
            _buildAddNewCardTile(isDark)
          else ...[
            // List saved cards
            ..._savedCards.map((card) => _buildSavedCardTile(card, isDark)),
            // Add new card option
            _buildAddNewCardTile(isDark, compact: true),
          ],

          const SizedBox(height: 28),

          // ─── DIGITAL WALLETS ────
          _buildSectionLabel('Digital Wallets', isDark),
          const SizedBox(height: 10),
          ..._buildWalletsList(recommended, isDark),

          const SizedBox(height: 40),

          // ─── TRUST INDICATOR ────
          _buildTrustFooter(isDark),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        color: isDark ? Colors.white60 : Colors.grey[600],
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildRecommendedTile(String methodId, bool isDark) {
    // ... (Keep existing implementation logic if needed, but for brevity using simplified version or assuming it exists)
    // Actually, I should keep the implementation.
    final info = _getMethodInfo(methodId);
    final isSelected = _selectedMethodId == methodId;

    return GestureDetector(
      onTap: () => _selectMethod(methodId),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E3A5F) : const Color(0xFF3B82F6),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                info['icon'] as IconData,
                color: Colors.black87,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        info['title'] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Recommended',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Fast and secure',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Colors.white, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedCardTile(SavedCard card, bool isDark) {
    final isSelected = _selectedMethodId == 'card_${card.id}';

    return GestureDetector(
      onTap: () => _selectMethod('card_${card.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF3B82F6)
                : (isDark ? Colors.white12 : Colors.grey[200]!),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.credit_card,
                color: isDark ? Colors.white70 : Colors.grey[700],
                size: 22,
              ),
            ),
            const SizedBox(width: 14),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${card.brand} •••• ${card.lastDigits}',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
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

            // Selection indicator
            if (isSelected)
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF3B82F6),
                  border: Border.all(color: const Color(0xFF3B82F6), width: 2),
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 14),
              )
            else
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? Colors.white30 : Colors.grey[300]!,
                    width: 2,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddNewCardTile(bool isDark, {bool compact = false}) {
    return GestureDetector(
      onTap: () => _navigateToAddCard(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E293B).withValues(alpha: 0.5)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.grey[200]!,
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? Colors.white24 : Colors.grey[300]!,
                  style: BorderStyle.none,
                ),
              ),
              child: Icon(
                Icons.add_rounded,
                color: isDark ? Colors.white70 : Colors.grey[600],
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
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

  Widget _buildMethodTile({
    required String id,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    final isSelected = _selectedMethodId == id;

    return GestureDetector(
      onTap: () => _selectMethod(id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF3B82F6)
                : (isDark ? Colors.white12 : Colors.grey[200]!),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isDark ? Colors.white70 : Colors.grey[700],
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
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
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? const Color(0xFF3B82F6)
                    : Colors.transparent,
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
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildWalletsList(String recommended, bool isDark) {
    // ... (Keep existing implementation)
    final wallets = <Map<String, dynamic>>[
      if (_isAvailable('apple_pay') && recommended != 'apple_pay')
        {
          'id': 'apple_pay',
          'icon': Icons.apple,
          'title': 'Apple Pay',
          'sub': 'Fast & secure',
        },
      if (_isAvailable('google_pay') && recommended != 'google_pay')
        {
          'id': 'google_pay',
          'icon': Icons.g_mobiledata_rounded,
          'title': 'Google Pay',
          'sub': 'Fast & secure',
        },
      {
        'id': 'paypal',
        'icon': Icons.paypal_outlined,
        'title': 'PayPal',
        'sub': 'Pay with balance or card',
      },
      {
        'id': 'alipay',
        'icon': Icons.account_balance_wallet_outlined,
        'title': 'Alipay',
        'sub': 'Popular in China',
      },
      {
        'id': 'wechat_pay',
        'icon': Icons.chat_bubble_outline,
        'title': 'WeChat Pay',
        'sub': 'Popular in Asia',
      },
      {
        'id': 'kakao_pay',
        'icon': Icons.chat_rounded,
        'title': 'KakaoPay',
        'sub': 'Popular in Korea',
      },
    ];

    return wallets
        .map(
          (w) => _buildMethodTile(
            id: w['id'] as String,
            icon: w['icon'] as IconData,
            title: w['title'] as String,
            subtitle: w['sub'] as String,
            isDark: isDark,
          ),
        )
        .toList();
  }

  bool _isAvailable(String walletId) {
    try {
      if (walletId == 'apple_pay') return Platform.isIOS;
      if (walletId == 'google_pay') return Platform.isAndroid;
    } catch (_) {
      return true;
    }
    return true;
  }

  Map<String, dynamic> _getMethodInfo(String methodId) {
    switch (methodId) {
      case 'apple_pay':
        return {'icon': Icons.apple, 'title': 'Apple Pay'};
      case 'google_pay':
        return {'icon': Icons.g_mobiledata_rounded, 'title': 'Google Pay'};
      case 'card':
        return {'icon': Icons.credit_card_rounded, 'title': 'Card'};
      default:
        return {'icon': Icons.payment, 'title': 'Payment'};
    }
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
  }
}
