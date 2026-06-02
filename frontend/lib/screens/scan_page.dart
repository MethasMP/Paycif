import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:frontend/l10n/generated/app_localizations.dart';
import 'package:frontend/widgets/premium_scanner_overlay.dart';
import 'package:frontend/services/qr_aggregator_service.dart';
import 'package:frontend/widgets/kyc/unified_payment_sheet.dart';
import '../utils/pay_notify.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DESIGN TOKENS
// First Principles: Minimalist, immersive, almost invisible UI.
// Let the camera and the luminous ring be the hero.
// ─────────────────────────────────────────────────────────────────────────────
const _kGold = Color(0xFFEF9F27);
const _kSurface = Color(0xFF0B0F0E);
const _kGlass = Color(0x14FFFFFF);      // ultra-light glass (8%)
const _kGlassBorder = Color(0x1EFFFFFF); // subtle border (12%)

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
    setState(() => _isProcessing = false);
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

  Future<void> _bypassScan() async {
    const path = '/Users/methas/Desktop/Paycif/my_qr.jpg';
    try {
      final BarcodeCapture? capture = await _cameraController.analyzeImage(path);
      if (capture != null && capture.barcodes.isNotEmpty) {
        final barcode = capture.barcodes.first;
        if (barcode.rawValue != null) {
          _handleCode(barcode.rawValue!);
          return;
        }
      }
    } catch (_) {}

    // Graceful fallback to developer PromptPay static mock QR if file access is sandboxed
    const fallbackQR = "00020101021129370016A000000677010111011300669692409255802TH530376463044DED";
    _handleCode(fallbackQR);
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

  // ── BUILD ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screenWidth = mq.size.width;
    // Frame Size proportional to screen
    final frameSize = screenWidth * 0.70;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ── Camera feed (full immersion) ───────────────────────────────
            MobileScanner(
              controller: _cameraController,
              onDetect: _onDetect,
              errorBuilder: (context, error) =>
                  _CameraErrorPlaceholder(onBypass: _bypassScan),
            ),

            // ── The Luminous Ring Overlay ──────────────────────────────────
            PremiumScannerOverlay(frameSize: frameSize),

            // ── Ultra-minimal floating UI ──────────────────────────────────
            SafeArea(
              child: Column(
                children: [
                  // Floating Top Controls (No bulky nav bar)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _FloatingIconButton(
                          icon: PhosphorIcons.x,
                          onTap: () {
                            if (widget.onBack != null) {
                              widget.onBack!();
                            } else {
                              Navigator.of(context).maybePop();
                            }
                          },
                        ),
                        _FloatingIconButton(
                          icon: _isFlashOn
                              ? PhosphorIcons.lightning
                              : PhosphorIcons.lightningSlash,
                          isActive: _isFlashOn,
                          onTap: () async {
                            await _cameraController.toggleTorch();
                            setState(() => _isFlashOn = !_isFlashOn);
                            HapticFeedback.selectionClick();
                          },
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Pure text instruction floating organically
                  Text(
                    AppLocalizations.of(context)!.scanGuideTitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.5,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Floating Pill for Actions (Gallery / Bypass / Help)
                  _MinimalBottomPill(
                    onUpload: _pickFromGallery,
                    onBypass: _bypassScan,
                    onHelp: _showHelpModal,
                  ),

                  SizedBox(height: mq.padding.bottom + 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHelpModal() {
    _cameraController.stop();
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MinimalHelpSheet(l10n: l10n),
    ).then((_) {
      if (mounted) _resumeScanning();
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FLOATING ICON BUTTON — pure glass circle
// ─────────────────────────────────────────────────────────────────────────────
class _FloatingIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isActive;

  const _FloatingIconButton({
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
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? _kGold.withValues(alpha: 0.15)
                  : _kGlass,
              border: Border.all(
                color: isActive
                    ? _kGold.withValues(alpha: 0.4)
                    : _kGlassBorder,
                width: 1.0,
              ),
            ),
            child: Icon(
              icon,
              color: isActive ? _kGold : Colors.white,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MINIMAL BOTTOM PILL
// Single floating pill containing minimal icons + text for actions.
// ─────────────────────────────────────────────────────────────────────────────
class _MinimalBottomPill extends StatelessWidget {
  final VoidCallback onUpload;
  final VoidCallback onBypass;
  final VoidCallback onHelp;

  const _MinimalBottomPill({
    required this.onUpload,
    required this.onBypass,
    required this.onHelp,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF000000).withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.0),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PillAction(
                icon: PhosphorIcons.image,
                label: l10n.commonUpload,
                onTap: onUpload,
              ),
              Container(
                width: 1,
                height: 24,
                color: Colors.white.withValues(alpha: 0.15),
                margin: const EdgeInsets.symmetric(horizontal: 8),
              ),
              _PillAction(
                icon: PhosphorIcons.qrCode,
                label: "Bypass",
                onTap: onBypass,
              ),
              Container(
                width: 1,
                height: 24,
                color: Colors.white.withValues(alpha: 0.15),
                margin: const EdgeInsets.symmetric(horizontal: 8),
              ),
              _PillAction(
                icon: PhosphorIcons.question,
                label: l10n.commonHelp,
                onTap: onHelp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PillAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      splashColor: Colors.white.withValues(alpha: 0.1),
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CAMERA ERROR PLACEHOLDER
// ─────────────────────────────────────────────────────────────────────────────
class _CameraErrorPlaceholder extends StatelessWidget {
  final VoidCallback onBypass;
  const _CameraErrorPlaceholder({required this.onBypass});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kSurface,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              PhosphorIcons.cameraSlash,
              color: Colors.white.withValues(alpha: 0.2),
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.scanErrorCamera,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onBypass,
              icon: Icon(PhosphorIcons.qrCode, color: Colors.black, size: 20),
              label: const Text("Simulate / Bypass Scan"),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kGold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MINIMAL HELP SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _MinimalHelpSheet extends StatelessWidget {
  final AppLocalizations l10n;
  const _MinimalHelpSheet({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0C0B).withValues(alpha: 0.85),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              
              Text(
                l10n.scanGuideTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w400,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 32),

              _HelpRow(
                icon: PhosphorIcons.qrCode,
                title: l10n.scanGuidePromptPayTitle,
                desc: l10n.scanGuidePromptPayDesc,
              ),
              _HelpRow(
                icon: PhosphorIcons.shieldCheck,
                title: l10n.scanGuideSafeTitle,
                desc: l10n.scanGuideSafeDesc,
              ),
              _HelpRow(
                icon: PhosphorIcons.currencyCircleDollar,
                title: l10n.scanGuideCurrencyTitle,
                desc: l10n.scanGuideCurrencyDesc,
              ),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
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
                      letterSpacing: 0.2,
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
  final String title;
  final String desc;

  const _HelpRow({
    required this.icon,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _kGold, size: 28),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 14,
                    height: 1.4,
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
