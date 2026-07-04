import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/core/theme/app_theme.dart';

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
          color: _getBackgroundColor(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _getBorderColor(context), width: 1),
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
                  color: _getTextColor(context),
                ),
              )
            else ...[
              _buildLogo(),
              SizedBox(width: 10),
              Text(
                _getButtonText(),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: _getTextColor(context),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
              ),
              if (isLinked) ...[
                SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.successGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        PhosphorIcons.checkCircle,
                        size: 12,
                        color: AppTheme.successGreen,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Linked',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppTheme.successGreen,
                              fontWeight: FontWeight.w600,
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

  Color _getBackgroundColor(BuildContext context) {
    switch (type) {
      case DigitalWalletType.applePay:
        return Colors.black;
      case DigitalWalletType.googlePay:
        return Theme.of(context).brightness == Brightness.dark ? Theme.of(context).cardColor : Colors.white;
    }
  }

  Color _getBorderColor(BuildContext context) {
    switch (type) {
      case DigitalWalletType.applePay:
        return Colors.black;
      case DigitalWalletType.googlePay:
        return Theme.of(context).brightness == Brightness.dark ? Colors.white24 : AppTheme.borderGrey;
    }
  }

  Color _getTextColor(BuildContext context) {
    switch (type) {
      case DigitalWalletType.applePay:
        return Colors.white;
      case DigitalWalletType.googlePay:
        return AppTheme.textSecondaryColor(context);
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
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(PhosphorIcons.appleLogo, color: Colors.white, size: 24),
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
                        color: AppTheme.infoBlue,
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
                        color: AppTheme.errorRed,
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
                        color: AppTheme.warningAmber,
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
                        color: AppTheme.successGreen,
                        borderRadius: BorderRadius.only(
                          bottomRight: Radius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 4),
          ],
        );
    }
  }
}
