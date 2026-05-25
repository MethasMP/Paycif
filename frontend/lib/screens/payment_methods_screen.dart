import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/payment_method_tile.dart';
import '../factories/payment_logo_factory.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// PAYMENT METHODS SCREEN - Tourist-First Design
/// ─────────────────────────────────────────────────────────────────────────────
/// World-class payment method selection optimized for foreign tourists.
///
/// UX Principles (NON-NEGOTIABLE):
/// - Default-first UX (Recommended section)
/// - 3-second selection target
/// - Zero decision fatigue
/// - Trust before delight
///
/// Sections:
/// 1. Recommended (context-aware single method)
/// 2. Cards (Visa, Mastercard, JCB, UnionPay)
/// 3. Digital Wallets (Apple Pay, Google Pay, PayPal, Alipay, WeChat Pay, KakaoPay)
/// ─────────────────────────────────────────────────────────────────────────────

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  String _selectedMethodId = '';

  @override
  void initState() {
    super.initState();
    // Context-aware default selection
    _selectedMethodId = _getRecommendedMethod();
  }

  /// Determines the recommended payment method based on device/region.
  String _getRecommendedMethod() {
    try {
      if (Platform.isIOS) return 'apple_pay';
      if (Platform.isAndroid) return 'google_pay';
    } catch (_) {
      // Platform not available (web)
    }
    return 'card_visa'; // Fallback
  }

  void _selectMethod(String methodId) {
    HapticFeedback.selectionClick();
    setState(() => _selectedMethodId = methodId);
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
        title: const Text(
          'Select Payment',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.close_rounded,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── RECOMMENDED SECTION ────
            _buildSectionLabel('Recommended for you', isDark),
            const SizedBox(height: 12),
            _buildRecommendedCard(recommended, isDark),

            const SizedBox(height: 28),

            // ─── CARDS SECTION ────
            _buildSectionLabel('Cards', isDark),
            const SizedBox(height: 12),
            _buildCardsSection(isDark),

            const SizedBox(height: 28),

            // ─── DIGITAL WALLETS SECTION ────
            _buildSectionLabel('Digital Wallets', isDark),
            const SizedBox(height: 12),
            _buildWalletsSection(isDark),

            const SizedBox(height: 40),

            // ─── TRUST FOOTER ────
            _buildTrustFooter(isDark),
          ],
        ),
      ),

      // ─── CONTINUE BUTTON ────
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: ElevatedButton(
            onPressed: _selectedMethodId.isNotEmpty
                ? () {
                    HapticFeedback.mediumImpact();
                    Navigator.pop(context, _selectedMethodId);
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              disabledBackgroundColor: Colors.grey[300],
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Continue',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        color: isDark ? Colors.white70 : const Color(0xFF64748B),
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildRecommendedCard(String recommended, bool isDark) {
    final isApple = recommended == 'apple_pay';
    final title = isApple ? 'Apple Pay' : 'Google Pay';
    // Use Factory here
    final logo = PaymentLogoFactory.create(recommended);

    return RecommendedMethodCard(
      logo: logo,
      title: title,
      trustText: 'Fastest and widely accepted',
      isSelected: _selectedMethodId == recommended,
      onTap: () => _selectMethod(recommended),
    );
  }

  Widget _buildCardsSection(bool isDark) {
    final cards = [
      {'id': 'card_visa', 'name': 'Visa', 'sub': 'Credit or Debit'},
      {'id': 'card_mastercard', 'name': 'Mastercard', 'sub': 'Credit or Debit'},
      {'id': 'card_jcb', 'name': 'JCB', 'sub': 'Credit Card'},
      {'id': 'card_unionpay', 'name': 'UnionPay', 'sub': 'Credit or Debit'},
    ];

    return Column(
      children: cards.map((card) {
        return PaymentMethodTile(
          logo: PaymentLogoFactory.create(card['id']!),
          title: card['name']!,
          subtitle: card['sub']!,
          isSelected: _selectedMethodId == card['id'],
          onTap: () => _selectMethod(card['id']!),
        );
      }).toList(),
    );
  }

  Widget _buildWalletsSection(bool isDark) {
    // Order by global familiarity
    // Hide based on platform availability
    final wallets = <Map<String, dynamic>>[
      if (_isPlatformAvailable('apple_pay'))
        {'id': 'apple_pay', 'name': 'Apple Pay', 'sub': 'Fast & Secure'},
      if (_isPlatformAvailable('google_pay'))
        {'id': 'google_pay', 'name': 'Google Pay', 'sub': 'Fast & Secure'},
      {'id': 'paypal', 'name': 'PayPal', 'sub': 'Global Reach'},
      {'id': 'alipay', 'name': 'Alipay', 'sub': 'China\'s #1 Wallet'},
      {'id': 'wechat_pay', 'name': 'WeChat Pay', 'sub': 'Popular in Asia'},
      {'id': 'kakao_pay', 'name': 'KakaoPay', 'sub': 'Korea\'s Choice'},
    ];

    return Column(
      children: wallets.map((wallet) {
        return PaymentMethodTile(
          logo: PaymentLogoFactory.create(wallet['id'] as String),
          title: wallet['name'] as String,
          subtitle: wallet['sub'] as String,
          isSelected: _selectedMethodId == wallet['id'],
          onTap: () => _selectMethod(wallet['id'] as String),
        );
      }).toList(),
    );
  }

  bool _isPlatformAvailable(String walletId) {
    try {
      if (walletId == 'apple_pay') return Platform.isIOS;
      if (walletId == 'google_pay') return Platform.isAndroid;
    } catch (_) {
      return true; // Web: show all
    }
    return true;
  }

  Widget _buildTrustFooter(bool isDark) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_rounded, size: 14, color: Colors.grey[500]),
            const SizedBox(width: 6),
            Text(
              'We never store your card details',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Secured and encrypted payments',
          style: TextStyle(color: Colors.grey[400], fontSize: 11),
        ),
      ],
    );
  }
}
