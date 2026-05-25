import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:frontend/l10n/generated/app_localizations.dart';
import 'package:frontend/utils/emv_parser.dart';
import 'package:frontend/widgets/premium_scanner_overlay.dart';
import 'package:frontend/services/qr_aggregator_service.dart';
import 'package:frontend/widgets/kyc/payment_preview_sheet.dart';

import 'package:frontend/screens/amount_entry_screen.dart';
import '../utils/pay_notify.dart';
import 'pay_screen.dart';

// ──────────────────────────────────────────────────────────────────────────────
// SCAN PAGE - Premium UX (Scan → Enter Amount → Pay)
// ──────────────────────────────────────────────────────────────────────────────

class ScanPage extends StatefulWidget {
  final VoidCallback? onBack;

  const ScanPage({super.key, this.onBack});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
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

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        _handleCode(barcode.rawValue!);
        break;
      }
    }
  }

  void _handleCode(String code) {
    if (_isProcessing) return;

    final paymentContext = QrAggregatorService.aggregate(code);

    // "Tactile Luxury" UX
    if (paymentContext.isSafe) {
      // High-precision haptic sequence
      HapticFeedback.mediumImpact();
      Future.delayed(const Duration(milliseconds: 100), () {
        HapticFeedback.heavyImpact();
      });
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
      final BarcodeCapture? capture = await _cameraController.analyzeImage(
        image.path,
      );
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

    // High-End Preview Ritual
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (c) => PaymentPreviewBottomSheet(
        context: payContext,
        onConfirm: () => Navigator.pop(c, true),
        onCancel: () => Navigator.pop(c, false),
      ),
    );

    if (confirm != true) {
      _resumeScanning();
      return;
    }

    final hasAmount = (payContext.amount ?? 0) > 0;

    if (!mounted) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (c) => hasAmount
            ? PayScreen(
                amount: payContext.amount!,
                merchantName: payContext.title,
                promptPayId: payContext.accountId,
                billerId: payContext.billerId,
                reference1: payContext.reference1,
                reference2: payContext.reference2,
              )
            : AmountEntryScreen(
                data: EMVCoParser.parse(payContext.metadata['raw'] ?? ''),
              ),
      ),
    );

    if (mounted) {
      if (result == true) {
        HapticFeedback.heavyImpact();
      }
      _resumeScanning();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Camera Base
          MobileScanner(
            controller: _cameraController,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _buildCameraError(),
          ),

          // 2. High-End Animated Overlay
          PremiumScannerOverlay(frameSize: screenWidth * 0.7),

          // 3. UI Layer (Glassmorphic Controls)
          SafeArea(
            child: Column(
              children: [
                _buildPremiumTopBar(),
                const Spacer(),
                _buildInstructionText(),
                const SizedBox(height: 32),
                _buildGlassActionButtons(),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.videocam_off_rounded,
            color: Colors.white38,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.scanErrorCamera,
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionText() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            border: Border.all(color: Colors.white10),
          ),
          child: Text(
            AppLocalizations.of(context)!.scanGuideTitle,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildGlassIconButton(
            icon: Icons.close_rounded,
            onTap: () {
              if (widget.onBack != null) {
                widget.onBack!();
              } else {
                Navigator.of(context).maybePop();
              }
            },
          ),
          _buildGlassIconButton(
            icon: _isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
            isSelected: _isFlashOn,
            onTap: () async {
              await _cameraController.toggleTorch();
              setState(() => _isFlashOn = !_isFlashOn);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGlassActionButtons() {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLongGlassButton(
          Icons.photo_library_rounded,
          l10n.commonUpload,
          _pickFromGallery,
        ),
        const SizedBox(width: 20),
        _buildLongGlassButton(
          Icons.help_outline_rounded,
          l10n.commonHelp,
          () => _showHelpModal(),
        ),
      ],
    );
  }

  Widget _buildGlassIconButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFF59E0B) : Colors.white12,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white10),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }

  Widget _buildLongGlassButton(
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
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
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Theme.of(context).canvasColor.withValues(alpha: 0.9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                l10n.scanGuideTitle,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              _buildHelpItem(
                '📱',
                l10n.scanGuidePromptPayTitle,
                l10n.scanGuidePromptPayDesc,
              ),
              _buildHelpItem(
                '🔒',
                l10n.scanGuideSafeTitle,
                l10n.scanGuideSafeDesc,
              ),
              _buildHelpItem(
                '💱',
                l10n.scanGuideCurrencyTitle,
                l10n.scanGuideCurrencyDesc,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    l10n.commonGotIt,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      if (mounted) _resumeScanning();
    });
  }

  Widget _buildHelpItem(String emoji, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  desc,
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// SCANNER OVERLAY (RESPONSIVE Frame Size)
// ──────────────────────────────────────────────────────────────────────────────

class ScannerOverlayPainter extends CustomPainter {
  final double frameSize;

  ScannerOverlayPainter({required this.frameSize});

  @override
  void paint(Canvas canvas, Size size) {
    final double scanAreaSize = frameSize;
    const double cornerLength = 30.0;

    final Rect scanRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2 - 60),
      width: scanAreaSize,
      height: scanAreaSize,
    );

    // Semi-transparent Background
    final Paint backgroundPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    Path path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    Path cutoutPath = Path()
      ..addRRect(RRect.fromRectAndRadius(scanRect, const Radius.circular(16)));

    final Path backgroundPath = Path.combine(
      PathOperation.difference,
      path,
      cutoutPath,
    );

    canvas.drawPath(backgroundPath, backgroundPaint);

    // Corner Paint (Gold Premium)
    final Paint cornerPaint = Paint()
      ..color = const Color(0xFFF59E0B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    final double halfSize = scanAreaSize / 2;
    final Offset center = Offset(size.width / 2, size.height / 2 - 60);

    // Top Left
    canvas.drawPath(
      Path()
        ..moveTo(center.dx - halfSize, center.dy - halfSize + cornerLength)
        ..lineTo(center.dx - halfSize, center.dy - halfSize)
        ..lineTo(center.dx - halfSize + cornerLength, center.dy - halfSize),
      cornerPaint,
    );

    // Top Right
    canvas.drawPath(
      Path()
        ..moveTo(center.dx + halfSize - cornerLength, center.dy - halfSize)
        ..lineTo(center.dx + halfSize, center.dy - halfSize)
        ..lineTo(center.dx + halfSize, center.dy - halfSize + cornerLength),
      cornerPaint,
    );

    // Bottom Left
    canvas.drawPath(
      Path()
        ..moveTo(center.dx - halfSize, center.dy + halfSize - cornerLength)
        ..lineTo(center.dx - halfSize, center.dy + halfSize)
        ..lineTo(center.dx - halfSize + cornerLength, center.dy + halfSize),
      cornerPaint,
    );

    // Bottom Right
    canvas.drawPath(
      Path()
        ..moveTo(center.dx + halfSize - cornerLength, center.dy + halfSize)
        ..lineTo(center.dx + halfSize, center.dy + halfSize)
        ..lineTo(center.dx + halfSize, center.dy + halfSize - cornerLength),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant ScannerOverlayPainter oldDelegate) =>
      oldDelegate.frameSize != frameSize;
}
