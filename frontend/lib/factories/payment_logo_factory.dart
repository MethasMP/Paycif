import 'package:flutter/material.dart';

/// 🏭 [PaymentLogoFactory]
/// Centralized factory for creating payment method brand logos.
/// Adheres to the Factory Pattern to decouple logo creation from UI logic.
class PaymentLogoFactory {
  // Private constructor to prevent instantiation
  PaymentLogoFactory._();

  static Widget create(String methodId) {
    switch (methodId) {
      // Wallets
      case 'apple_pay':
        return _buildApplePayLogo();
      case 'google_pay':
        return _buildGooglePayLogo();
      case 'paypal':
        return _buildTextLogo('PP', const Color(0xFF003087));
      case 'alipay':
        return _buildTextLogo('A', const Color(0xFF1677FF), size: 20);
      case 'wechat_pay':
        return _buildTextLogo('WC', const Color(0xFF07C160));
      case 'kakao_pay':
        return _buildTextLogo(
          'K',
          const Color(0xFF3C1E1E),
          bgAlpha: 0.3,
          bgColor: const Color(0xFFFFE812),
        );

      // Cards
      case 'card_visa':
        return _buildVisaLogo();
      case 'card_mastercard':
        return _buildMastercardLogo();
      case 'card_jcb':
        return _buildJcbLogo();
      case 'card_unionpay':
        return _buildTextLogo('UP', const Color(0xFF002B5C));

      // Default
      default:
        return _buildDefaultIcon();
    }
  }

  static Widget _buildApplePayLogo() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.apple, color: Colors.white, size: 26),
    );
  }

  static Widget _buildGooglePayLogo() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildGoogleDot(const Color(0xFF4285F4)),
          _buildGoogleDot(const Color(0xFFEA4335)),
          _buildGoogleDot(const Color(0xFFFBBC05)),
          _buildGoogleDot(const Color(0xFF34A853)),
        ],
      ),
    );
  }

  static Widget _buildGoogleDot(Color color) {
    return Container(
      width: 6,
      height: 6,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  static Widget _buildVisaLogo() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F71).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Text(
          'VISA',
          style: TextStyle(
            color: Color(0xFF1A1F71),
            fontWeight: FontWeight.w900,
            fontSize: 10,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  static Widget _buildMastercardLogo() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: const BoxDecoration(
                color: Color(0xFFEB001B),
                shape: BoxShape.circle,
              ),
            ),
            Transform.translate(
              offset: const Offset(-5, 0),
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFFF79E1B).withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildJcbLogo() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF003087), Color(0xFF009A44), Color(0xFFE30613)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Text(
          'JCB',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  static Widget _buildTextLogo(
    String text,
    Color color, {
    double size = 16,
    double bgAlpha = 0.1,
    Color? bgColor,
  }) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: (bgColor ?? color).withValues(alpha: bgAlpha),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: size,
          ),
        ),
      ),
    );
  }

  static Widget _buildDefaultIcon() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.credit_card, color: Colors.grey),
    );
  }
}
