import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:frontend/core/l10n/generated/app_localizations.dart';
import 'package:frontend/core/widgets/premium_scanner_overlay.dart';
import 'package:frontend/features/payment/data/qr_aggregator_service.dart';
import 'package:frontend/core/widgets/kyc/unified_payment_sheet.dart';
import 'package:frontend/core/widgets/kyc/kyc_required_sheet.dart';
import 'package:frontend/core/network/api_service.dart';
import 'package:frontend/features/dashboard/presentation/dashboard_controller.dart';
import 'package:frontend/core/utils/pay_notify.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SCAN PAGE v2 — Redesigned from first principles
//
// UX Brief context:
//   • Tourist, outdoor, bright sun, one hand, hurried, unstable signal
//   • 3-tap maximum. Large text. High contrast. Clear loading state.
//   • Branded: Teal (trust) + Gold (value, Thai cultural) on near-black
//   • Inspiration: Wise (transparency) + GrabPay (SE Asia simplicity)
//   → But with Paycif's own identity: "Safe. Pay. Fast."
// ─────────────────────────────────────────────────────────────────────────────

class ScanPage extends StatefulWidget {
  final VoidCallback? onBack;
  const ScanPage({super.key, this.onBack});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> with TickerProviderStateMixin {
  final MobileScannerController _cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    returnImage: false,
    formats: [BarcodeFormat.qrCode],
  );

  final ImagePicker _picker = ImagePicker();
  bool _isFlashOn = false;
  bool _isProcessing = false;
  bool _hasCameraError = false;

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  // ── QR Detection ────────────────────────────────────────────────────────────

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    for (final barcode in capture.barcodes) {
      if (barcode.rawValue != null) {
        _handleCode(barcode.rawValue!);
        break;
      }
    }
  }

  void _handleCode(String code) {
    if (_isProcessing) return;
    final paymentContext = QrAggregatorService.aggregate(code);
    if (paymentContext.isSafe) {
      HapticFeedback.mediumImpact();
      Future.delayed(
          const Duration(milliseconds: 100), HapticFeedback.heavyImpact);
    } else {
      HapticFeedback.vibrate();
    }
    setState(() => _isProcessing = true);
    _cameraController.stop();
    if (!mounted) return;
    _handleValidPayment(paymentContext);
  }

  void _resumeScanning() {
    setState(() {
      _isProcessing = false;
      _hasCameraError = false;
    });
    _cameraController.start();
  }

  Future<void> _pickFromGallery() async {
    final l10n = AppLocalizations.of(context)!;
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final BarcodeCapture? capture =
          await _cameraController.analyzeImage(image.path);
      if (capture != null && capture.barcodes.isNotEmpty) {
        final barcode = capture.barcodes.first;
        if (barcode.rawValue != null) {
          _handleCode(barcode.rawValue!);
        } else {
          _showError(l10n.scanNoQrFound);
        }
      } else {
        _showError(l10n.commonError);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    PayNotify.error(context, message);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _resumeScanning();
    });
  }

  void _handleValidPayment(PaymentContext payContext) async {
    if (!mounted) return;
    if (!payContext.isSafe && payContext.title == 'Unknown QR') {
      _showError(AppLocalizations.of(context)!.scanUnknownRecipient);
      return;
    }

    // ── KYC GATE ────────────────────────────────────────────────────────────
    // Block unverified users at the moment of payment instead of letting the
    // request fail at settlement. If the user is not VERIFIED, show a sheet that
    // routes them into the KYC flow; only continue into payment once they verify.
    final canProceed = await _ensureKycVerified();
    if (!mounted || !canProceed) {
      if (mounted) _resumeScanning();
      return;
    }

    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (c) => UnifiedPaymentSheet(payContext: payContext),
    );

    if (mounted) {
      if (result == true) {
        HapticFeedback.heavyImpact();
      }
      _resumeScanning();
    }
  }

  /// Returns `true` if the user may proceed into the payment flow.
  ///
  /// Reads KYC status from the already-fetched DashboardController state when
  /// available (no extra network round-trip); otherwise falls back to a fresh
  /// fetch. Any status other than 'VERIFIED' (case-insensitive) triggers the
  /// verification gate sheet, which routes to the `/kyc` flow.
  Future<bool> _ensureKycVerified() async {
    // Always start with the dashboard's cached value for zero-latency check.
    String? cachedStatus;
    try {
      cachedStatus = context.read<DashboardController>().state.kycTier;
    } catch (_) {}

    // Cache is authoritative only when it's already VERIFIED — avoids
    // a network round-trip on every scan for verified users.
    if (cachedStatus?.toUpperCase() == 'VERIFIED') return true;

    // Otherwise, fresh-fetch to get the true current status.
    try {
      final data = await ApiService.getKycStatus();
      final freshStatus = (data['kyc_status'] as String?)?.toUpperCase();
      if (freshStatus == 'VERIFIED') return true;
    } catch (e) {
      // Fail-open: backend still rejects unverified users at settlement.
      debugPrint('⚠️ [ScanPage] KYC status fetch failed, allowing through: $e');
      return true;
    }

    // Not verified — present the gate.
    if (!mounted) return false;
    final wantsToVerify = await KycRequiredSheet.show(context);
    if (wantsToVerify != true || !mounted) return false;

    final verified = await context.push<bool>('/kyc');

    // Refresh dashboard so subsequent scans don't re-gate a now-verified user.
    if (verified == true && mounted) {
      try {
        context.read<DashboardController>().refresh();
      } catch (_) {}
    }

    return verified == true;
  }

  // ── BUILD ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screenWidth = mq.size.width;
    final frameSize = screenWidth * 0.72;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ── Full-screen camera ─────────────────────────────────────────
            MobileScanner(
              controller: _cameraController,
              onDetect: _onDetect,
              errorBuilder: (context, error) {
                if (!_hasCameraError) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() => _hasCameraError = true);
                    }
                  });
                }
                return const _CameraErrorPlaceholder();
              },
            ),

            // ── Scanner overlay: corner brackets + scan beam ───────────────
            if (!_hasCameraError)
              PremiumScannerOverlay(frameSize: frameSize),

            // ── UI Shell ──────────────────────────────────────────────────
            SafeArea(
              child: Column(
                children: [
                  _TopBar(
                    isFlashOn: _isFlashOn,
                    onClose: () {
                      if (widget.onBack != null) {
                        widget.onBack!();
                      } else {
                        Navigator.of(context).maybePop();
                      }
                    },
                    onFlash: () async {
                      await _cameraController.toggleTorch();
                      setState(() => _isFlashOn = !_isFlashOn);
                      HapticFeedback.selectionClick();
                    },
                  ),

                   // Instruction text below the scan frame
                  _ScanInstruction(),

                  const SizedBox(height: 12),


                  const SizedBox(height: 16),

                  // Actions bar
                  _BottomActionsBar(
                    onUpload: _pickFromGallery,
                    onHelp: _showHelpModal,
                  ),

                  SizedBox(height: mq.padding.bottom + 20),
                ],
              ),
            ),

            // ── Processing overlay ─────────────────────────────────────────
            if (_isProcessing)
              _ProcessingOverlay(),
          ],
        ),
      ),
    );
  }

  Future<void> _showHelpModal() async {
    _cameraController.stop();
    final l10n = AppLocalizations.of(context)!;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _HelpSheet(l10n: l10n),
    );
    if (mounted) _resumeScanning();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOP BAR — glass surface, "Scan to Pay" title, close + torch
// ─────────────────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final bool isFlashOn;
  final VoidCallback onClose;
  final VoidCallback onFlash;

  const _TopBar({
    required this.isFlashOn,
    required this.onClose,
    required this.onFlash,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        children: [
          // Close button — glassy circle
          _GlassCircleButton(
            icon: PhosphorIcons.x,
            onTap: onClose,
          ),

          // "Scan to Pay" — centered, always visible
          Expanded(
            child: Text(
              'Scan to Pay',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
                shadows: [
                  Shadow(
                    color: Colors.black,
                    blurRadius: 12,
                  ),
                ],
              ),
            ),
          ),

          // Torch button — glassy circle, gold when active
          _GlassCircleButton(
            icon: isFlashOn
                ? PhosphorIcons.lightning
                : PhosphorIcons.lightningSlash,
            onTap: onFlash,
            isActive: isFlashOn,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GLASS CIRCLE BUTTON — icon inside frosted glass pill
// ─────────────────────────────────────────────────────────────────────────────
class _GlassCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isActive;

  const _GlassCircleButton({
    required this.icon,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? AppTheme.accentGold.withValues(alpha: 0.20)
                  : Colors.white.withValues(alpha: 0.10),
              border: Border.all(
                color: isActive
                    ? AppTheme.accentGold.withValues(alpha: 0.50)
                    : Colors.white.withValues(alpha: 0.15),
                width: 1.0,
              ),
            ),
            child: Icon(
              icon,
              color: isActive ? AppTheme.accentGold : Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCAN INSTRUCTION — two-line copy below the frame
// Large, high-contrast for outdoor readability
// ─────────────────────────────────────────────────────────────────────────────
class _ScanInstruction extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Point at any Thai PromptPay QR',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.92),
            fontSize: 15,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
            shadows: const [
              Shadow(color: Colors.black, blurRadius: 10),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Merchant QR  •  PromptPay Supported',
          style: TextStyle(
            color: AppTheme.primaryTeal.withValues(alpha: 0.90),
            fontSize: 12,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.5,
            shadows: const [
              Shadow(color: Colors.black, blurRadius: 8),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM ACTIONS BAR — frosted glass pill with Upload / Help
// Touch targets: minimum 44px. Separated by thin dividers.
// ─────────────────────────────────────────────────────────────────────────────
class _BottomActionsBar extends StatelessWidget {
  final VoidCallback onUpload;
  final VoidCallback onHelp;

  const _BottomActionsBar({
    required this.onUpload,
    required this.onHelp,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1.0,
            ),
          ),
          child: IntrinsicWidth(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ActionChip(
                  icon: PhosphorIcons.image,
                  label: l10n.commonUpload,
                  onTap: onUpload,
                ),
                _VerticalDivider(),
                _ActionChip(
                  icon: PhosphorIcons.question,
                  label: l10n.commonHelp,
                  onTap: onHelp,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 22,
      color: Colors.white.withValues(alpha: 0.14),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        splashColor: Colors.white.withValues(alpha: 0.08),
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: Colors.white.withValues(alpha: 0.85),
                size: 17,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROCESSING OVERLAY — shown while QR is being validated
// Provides clear "system is working" feedback (UX brief requirement)
// ─────────────────────────────────────────────────────────────────────────────
class _ProcessingOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Container(
        color: Colors.black.withValues(alpha: 0.55),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 52,
                height: 52,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppTheme.accentGold),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Reading QR…',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CAMERA ERROR PLACEHOLDER
// ─────────────────────────────────────────────────────────────────────────────
class _CameraErrorPlaceholder extends StatelessWidget {
  const _CameraErrorPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0B0F0E),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              PhosphorIcons.cameraSlash,
              color: Colors.white.withValues(alpha: 0.25),
              size: 52,
            ),
            const SizedBox(height: 20),
            Text(
              AppLocalizations.of(context)!.scanErrorCamera,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELP SHEET — clean dark bottom sheet with 3 key facts
// ─────────────────────────────────────────────────────────────────────────────
class _HelpSheet extends StatelessWidget {
  final AppLocalizations l10n;
  const _HelpSheet({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
        decoration: const BoxDecoration(
          color: Color(0xF00B0F0E), // near-black, 94% opaque
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              const SizedBox(height: 14),
              Center(
                child: Container(
                  width: 36,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 36),

              // Title
              const Text(
                'Thai QR Payment Guide',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 28),

              _HelpRow(
                icon: PhosphorIcons.qrCode,
                iconColor: AppTheme.primaryTeal,
                title: l10n.scanGuidePromptPayTitle,
                desc: l10n.scanGuidePromptPayDesc,
              ),
              _HelpRow(
                icon: PhosphorIcons.shieldCheck,
                iconColor: AppTheme.successGreen,
                title: l10n.scanGuideSafeTitle,
                desc: l10n.scanGuideSafeDesc,
              ),
              _HelpRow(
                icon: PhosphorIcons.currencyCircleDollar,
                iconColor: AppTheme.accentGold,
                title: l10n.scanGuideCurrencyTitle,
                desc: l10n.scanGuideCurrencyDesc,
              ),

              const SizedBox(height: 32),

              // Got it — wide white CTA
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0B0F0E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    l10n.commonGotIt,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _HelpRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String desc;

  const _HelpRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon in a tinted container
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.48),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
