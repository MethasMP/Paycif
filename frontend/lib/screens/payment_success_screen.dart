import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:provider/provider.dart';

import '../controllers/dashboard_controller.dart';
import 'package:frontend/theme/app_theme.dart';
import '../widgets/paycif_text.dart';

class PaymentSuccessScreen extends StatelessWidget {
  final String transactionId;
  final double amount;
  final String recipientName;
  final String? promptPayId;

  const PaymentSuccessScreen({
    super.key,
    required this.transactionId,
    required this.amount,
    required this.recipientName,
    this.promptPayId,
  });

  @override
  Widget build(BuildContext context) {
    // Using the default theme background
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: AppTheme.primaryTeal,
      body: SafeArea(
        child: Column(
          children: [
            // Top Nav
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 48), // Spacer
                  const Text(
                    'e-Slip',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(PhosphorIcons.x, color: Colors.white),
                    onPressed: () => _navigateToHome(context),
                  ),
                ],
              ),
            ),

            // 3. The Slip (Expanded to fill space, no scrolling)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: _buildSolidSlip(context, isDark),
              ),
            ),

            // 4. Save & Done Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => _navigateToHome(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primaryTeal,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Back to Home',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () {
                    },
                    icon: const Icon(PhosphorIcons.downloadSimple, color: Colors.white, size: 20),
                    label: const Text(
                      'Save to Gallery',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 14),
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSolidSlip(BuildContext context, bool isDark) {
    final now = DateTime.now();
    // Bilingual Date Format
    final enDate = DateFormat('dd MMM yyyy - HH:mm').format(now);

    final slipBgColor = isDark ? Theme.of(context).colorScheme.surfaceContainerHighest : Colors.white;
    final textColor = AppTheme.textPrimaryColor(context);
    final textMuted = AppTheme.textSecondaryColor(context);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: slipBgColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : AppTheme.borderGrey,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Security Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withValues(alpha: 0.25) : AppTheme.primaryTealLight,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : AppTheme.primaryTealLight,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  PhosphorIcons.shieldCheckFill,
                  color: AppTheme.primaryTeal,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Verified by Paycif Network',
                  style: TextStyle(
                    color: isDark ? AppTheme.primaryColor(context) : AppTheme.primaryTeal,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          // Main Slip Content (Expanded to distribute space evenly)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Success Icon & Title
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryTeal.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(PhosphorIcons.check, color: AppTheme.primaryTeal, size: 32),
                      ),
                      const SizedBox(height: 10),
                      PaycifText(
                        'โอนเงินสำเร็จ',
                        style: PaycifTextStyle.h1,
                        color: textColor,
                        fontWeight: FontWeight.bold,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        enDate,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: textMuted, fontSize: 12, height: 1.3),
                      ),
                    ],
                  ),

                  // Transfer Details
                  Column(
                    children: [
                      _buildParticipantRow(
                        label: 'From',
                        name: 'Google',
                        subtext: 'นาย เมธัส (Mr. Methas)',
                        icon: PhosphorIcons.wallet,
                        textColor: textColor,
                        textMuted: textMuted,
                        isDark: isDark,
                      ),
                      
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 20),
                        child: Row(
                          children: [
                            Container(width: 2, height: 12, color: isDark ? Colors.white.withValues(alpha: 0.1) : AppTheme.borderGrey),
                          ],
                        ),
                      ),

                      _buildParticipantRow(
                        label: 'ไปยัง To',
                        name: recipientName,
                        subtext: promptPayId != null ? 'PromptPay: $promptPayId' : 'Merchant',
                        icon: PhosphorIcons.storefront,
                        textColor: textColor,
                        textMuted: textMuted,
                        isDark: isDark,
                      ),
                    ],
                  ),

                  Divider(color: isDark ? Colors.white.withValues(alpha: 0.1) : AppTheme.borderGrey, height: 1),

                  // Amount
                  Column(
                    children: [
                      Text(
                        'Amount',
                        style: TextStyle(color: textMuted, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      RichText(
                        text: TextSpan(
                          style: TextStyle(
                            color: isDark ? AppTheme.primaryColor(context) : AppTheme.primaryTeal,
                            fontFamily: Theme.of(context).textTheme.displayMedium?.fontFamily,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                          children: [
                            TextSpan(
                              text: NumberFormat('#,##0.00').format(amount),
                              style: const TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1,
                              ),
                            ),
                            const TextSpan(text: ' '),
                            TextSpan(
                              text: 'THB',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: textMuted,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  Divider(color: isDark ? Colors.white.withValues(alpha: 0.1) : AppTheme.borderGrey, height: 1),

                  // Footer: Ref ID & QR Code
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ref ID',
                              style: TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              transactionId,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(PhosphorIcons.checkCircleFill, color: AppTheme.primaryTeal, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  'Verified',
                                  style: TextStyle(
                                    color: AppTheme.primaryTeal,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      // QR Code
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.borderGrey),
                        ),
                        child: QrImageView(
                          data: 'PAYCIF:TXN:$transactionId:AMT:$amount',
                          version: QrVersions.auto,
                          size: 60.0,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantRow({
    required String label,
    required String name,
    required String subtext,
    required IconData icon,
    required Color textColor,
    required Color textMuted,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : AppTheme.backgroundGrey,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: textColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PaycifText(
                label,
                style: PaycifTextStyle.caption,
                color: textMuted,
                fontWeight: FontWeight.w500,
              ),
              const SizedBox(height: 2),
              PaycifText(
                name,
                style: PaycifTextStyle.body,
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
              const SizedBox(height: 2),
              PaycifText(
                subtext,
                style: PaycifTextStyle.caption,
                color: textMuted,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _navigateToHome(BuildContext context) {
    try {
      context.read<DashboardController>().refresh();
    } catch (_) {}
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}
