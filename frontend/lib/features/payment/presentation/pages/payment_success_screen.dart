import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:frontend/features/dashboard/presentation/dashboard_controller.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/paycif_text.dart';
import 'package:frontend/core/widgets/paycif_button.dart';
import 'package:frontend/core/l10n/generated/app_localizations.dart';
import 'package:frontend/core/widgets/app_icon.dart';

class PaymentSuccessScreen extends StatefulWidget {
  final String transactionId;
  final double amount;

  /// What the card was actually charged, in USD — shown on the slip so the
  /// user can reconcile their card statement without remembering it.
  final double? totalUsd;
  final String recipientName;
  final String? promptPayId;

  const PaymentSuccessScreen({
    super.key,
    required this.transactionId,
    required this.amount,
    this.totalUsd,
    required this.recipientName,
    this.promptPayId,
  });

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen> {
  @override
  void initState() {
    super.initState();
    // Play success notification haptic (heavyImpact + lightImpact 100ms apart)
    // as per paycif-motion-spec-v1.md section 5
    _triggerSuccessHaptics();
  }

  void _triggerSuccessHaptics() {
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 100), () {
      HapticFeedback.lightImpact();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 48),
                  Text(
                    l10n.successAppBarTitle,
                    style: TextStyle(
                      color: AppTheme.textPrimaryColor(context),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    icon: AppIcon(PhosphorIcons.x, color: AppTheme.textPrimaryColor(context)),
                    onPressed: () => _navigateToHome(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: _buildSolidSlip(context, isDark),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: PaycifButton(
                      text: l10n.successBackToHome,
                      onPressed: () => _navigateToHome(context),
                      variant: PaycifButtonVariant.primary,
                      size: PaycifButtonSize.lg,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSolidSlip(BuildContext context, bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.signalGreenSubtleDark : AppTheme.signalGreenSubtleLight,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppTheme.signalGreenSubtleDark : AppTheme.signalGreenSubtleLight,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AppIcon(
                  PhosphorIcons.shieldCheckFill,
                  color: AppTheme.signalGreen,
                  size: AppIconSize.xs,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.successVerifiedBadge,
                  style: const TextStyle(
                    color: AppTheme.successGreenText,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.signalGreen.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        // Animated drawing checkmark as per spec (300ms easeOut)
                        child: const AnimatedCheckmark(
                          size: 28.0,
                          color: AppTheme.signalGreen,
                        ),
                      ),
                      const SizedBox(height: 10),
                      PaycifText(
                        l10n.paymentSuccessTitle,
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
                  Column(
                    children: [
                      _buildParticipantRow(
                        label: l10n.successFromLabel,
                        name: l10n.successYourWallet,
                        subtext: Supabase.instance.client.auth.currentUser?.email ?? '',
                        icon: PhosphorIcons.creditCard,
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
                        label: l10n.successToLabel,
                        name: widget.recipientName,
                        subtext: widget.promptPayId != null ? 'PromptPay: ${widget.promptPayId}' : l10n.successMerchantLabel,
                        icon: PhosphorIcons.storefront,
                        textColor: textColor,
                        textMuted: textMuted,
                        isDark: isDark,
                      ),
                    ],
                  ),
                  Divider(color: isDark ? Colors.white.withValues(alpha: 0.1) : AppTheme.borderGrey, height: 1),
                  Column(
                    children: [
                      Text(
                        l10n.payAmountLabel,
                        style: TextStyle(color: textMuted, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      // Animated Count-Up text (280ms) with tabular figures
                      AnimatedAmount(
                        amount: widget.amount,
                        textColor: textColor,
                        textMuted: textMuted,
                      ),
                      if (widget.totalUsd != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          l10n.successChargedUsd(widget.totalUsd!.toStringAsFixed(2)),
                          style: TextStyle(
                            color: textMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ],
                  ),
                  Divider(color: isDark ? Colors.white.withValues(alpha: 0.1) : AppTheme.borderGrey, height: 1),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.successRefIdLabel,
                              style: TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.transactionId,
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
                                const AppIcon(PhosphorIcons.checkCircleFill, color: AppTheme.signalGreen, size: AppIconSize.xs),
                                const SizedBox(width: 4),
                                Text(
                                  l10n.successVerifiedLabel,
                                  style: const TextStyle(
                                    color: AppTheme.successGreenText,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.borderGrey),
                        ),
                        child: QrImageView(
                          data: 'PAYCIF:TXN:${widget.transactionId}:AMT:${widget.amount}',
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
          child: AppIcon(icon, color: textColor, size: AppIconSize.sm),
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

// ─────────────────────────────────────────────────────────────────────────────
// ANIMATED CHECKMARK — Draws the path over 300ms using Curves.easeOutCubic
// ─────────────────────────────────────────────────────────────────────────────
class AnimatedCheckmark extends StatefulWidget {
  final double size;
  final Color color;
  final Duration duration;

  const AnimatedCheckmark({
    super.key,
    this.size = 28.0,
    required this.color,
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  State<AnimatedCheckmark> createState() => _AnimatedCheckmarkState();
}

class _AnimatedCheckmarkState extends State<AnimatedCheckmark> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(widget.size, widget.size),
      painter: _CheckmarkPainter(
        progress: _animation,
        color: widget.color,
      ),
    );
  }
}

class _CheckmarkPainter extends CustomPainter {
  final Animation<double> progress;
  final Color color;

  _CheckmarkPainter({required this.progress, required this.color}) : super(repaint: progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final start = Offset(size.width * 0.22, size.height * 0.52);
    final mid = Offset(size.width * 0.44, size.height * 0.72);
    final end = Offset(size.width * 0.78, size.height * 0.32);

    path.moveTo(start.dx, start.dy);
    path.lineTo(mid.dx, mid.dy);
    path.lineTo(end.dx, end.dy);

    final t = progress.value;
    final animatedPath = Path();
    animatedPath.moveTo(start.dx, start.dy);

    // Segment 1 (start -> mid): ~0.35 of animation
    // Segment 2 (mid -> end): ~0.65 of animation
    if (t < 0.35) {
      final t1 = t / 0.35;
      final currentMid = Offset.lerp(start, mid, t1)!;
      animatedPath.lineTo(currentMid.dx, currentMid.dy);
    } else {
      animatedPath.lineTo(mid.dx, mid.dy);
      final t2 = (t - 0.35) / 0.65;
      final currentEnd = Offset.lerp(mid, end, t2)!;
      animatedPath.lineTo(currentEnd.dx, currentEnd.dy);
    }

    canvas.drawPath(animatedPath, paint);
  }

  @override
  bool shouldRepaint(covariant _CheckmarkPainter oldDelegate) {
    return oldDelegate.progress.value != progress.value || oldDelegate.color != color;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ANIMATED AMOUNT — Interpolates double amount over 280ms
// ─────────────────────────────────────────────────────────────────────────────
class AnimatedAmount extends StatefulWidget {
  final double amount;
  final Color textColor;
  final Color textMuted;

  const AnimatedAmount({
    super.key,
    required this.amount,
    required this.textColor,
    required this.textMuted,
  });

  @override
  State<AnimatedAmount> createState() => _AnimatedAmountState();
}

class _AnimatedAmountState extends State<AnimatedAmount> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280), // motion.number = 280ms
    );
    _animation = Tween<double>(begin: 0.0, end: widget.amount).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return RichText(
          text: TextSpan(
            style: TextStyle(
              color: widget.textColor,
              fontFamily: Theme.of(context).textTheme.displayMedium?.fontFamily,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            children: [
              TextSpan(
                text: NumberFormat('#,##0.00').format(_animation.value),
                style: AppTheme.amountTextStyle(context, color: widget.textColor),
              ),
              const TextSpan(text: ' '),
              TextSpan(
                text: 'THB',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: widget.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
