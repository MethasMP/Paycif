import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// DIGITAL WALLET BUTTON
/// ─────────────────────────────────────────────────────────────────────────────
/// Premium-styled buttons for Apple Pay and Google Pay.
/// Follows official brand guidelines for each platform.
/// ─────────────────────────────────────────────────────────────────────────────

enum DigitalWalletType { applePay, googlePay }

class DigitalWalletButton extends StatelessWidget {
  final DigitalWalletType type;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isLinked;

  const DigitalWalletButton({
    super.key,
    required this.type,
    this.onPressed,
    this.isLoading = false,
    this.isLinked = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: isLoading
          ? null
          : () {
              HapticFeedback.mediumImpact();
              onPressed?.call();
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: _getBackgroundColor(isDark),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _getBorderColor(isDark), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _getTextColor(),
                ),
              )
            else ...[
              _buildLogo(),
              const SizedBox(width: 10),
              Text(
                _getButtonText(),
                style: TextStyle(
                  color: _getTextColor(),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              if (isLinked) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 12,
                        color: Color(0xFF10B981),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Linked',
                        style: TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Color _getBackgroundColor(bool isDark) {
    switch (type) {
      case DigitalWalletType.applePay:
        return Colors.black;
      case DigitalWalletType.googlePay:
        return isDark ? const Color(0xFF1E293B) : Colors.white;
    }
  }

  Color _getBorderColor(bool isDark) {
    switch (type) {
      case DigitalWalletType.applePay:
        return Colors.black;
      case DigitalWalletType.googlePay:
        return isDark ? Colors.white24 : Colors.grey[300]!;
    }
  }

  Color _getTextColor() {
    switch (type) {
      case DigitalWalletType.applePay:
        return Colors.white;
      case DigitalWalletType.googlePay:
        return const Color(0xFF3C4043);
    }
  }

  String _getButtonText() {
    switch (type) {
      case DigitalWalletType.applePay:
        return 'Pay';
      case DigitalWalletType.googlePay:
        return 'Pay';
    }
  }

  Widget _buildLogo() {
    switch (type) {
      case DigitalWalletType.applePay:
        return const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.apple, color: Colors.white, size: 24),
            SizedBox(width: 2),
          ],
        );
      case DigitalWalletType.googlePay:
        // Google Pay uses their specific color scheme
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Simplified Google "G" logo representation
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(4)),
              child: Stack(
                children: [
                  // Blue
                  Positioned(
                    left: 0,
                    top: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4285F4),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  // Red
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEA4335),
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  // Yellow
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFBBC05),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  // Green
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Color(0xFF34A853),
                        borderRadius: BorderRadius.only(
                          bottomRight: Radius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
          ],
        );
    }
  }
}
