import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:frontend/l10n/generated/app_localizations.dart';
import 'package:frontend/utils/emv_parser.dart';
import 'package:frontend/utils/pay_notify.dart';

import 'pay_screen.dart';

// ──────────────────────────────────────────────────────────────────────────────
// SCAN PAGE - Simplified Flow (Scan → Enter Amount → Pay)
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

    final emvData = EMVCoParser.parse(code);

    // "Security Shield" UX - Validate Integrity
    if (emvData.isValid) {
      HapticFeedback.heavyImpact(); // Stronger feedback for valid secure QR
    } else {
      HapticFeedback.mediumImpact(); // Standard feedback
    }

    setState(() => _isProcessing = true);
    _cameraController.stop();

    if (!mounted) return;

    // Proceed to Payment
    _goToPaymentScreen(emvData);
  }

  void _goToPaymentScreen(EMFData data) {
    final l10n = AppLocalizations.of(context)!;
    if (!data.isValid) {
      _showError(AppLocalizations.of(context)!.scanUnknownRecipient);
      _resumeScanning();
      return;
    }

    // If amount is not in QR, we might need an input screen.
    // The design doc focuses on the Confirm/Pay step.
    // Assuming for now QR has amount or we default to 0 for demo if needed.
    // Ideally we prompt for amount. But let's assume valid QR has amount or we hardcode.
    final amount = data.amount ?? 0.0;
    if (amount <= 0) {
      _showError(l10n.topUpEnterAmountError);
      _resumeScanning();
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PayScreen(amount: amount, merchantName: data.merchantName),
      ),
    ).then((result) {
      if (!mounted) return;
      if (result == true) {
        // Explicitly check for success result
        // HapticFeedback.heavyImpact(); // Already done in PayScreen? No, PayScreen popped.
        // Let's do it here on success return
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)!.scanPaymentSuccess} 🎉',
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
      _resumeScanning();
    });
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
  }

  void _showHelpModal() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.7,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.scanGuideTitle,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                ),
                child: Text(
                  l10n.commonGotIt,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHelpItem(String emoji, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  desc,
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white54
                        : Colors.black54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera
          MobileScanner(
            controller: _cameraController,
            onDetect: _onDetect,
            errorBuilder: (context, error) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error, color: Colors.white, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.scanErrorCamera,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),

          // Overlay with RESPONSIVE frame
          CustomPaint(
            painter: ScannerOverlayPainter(frameSize: screenWidth * 0.7),
            child: const SizedBox.expand(),
          ),

          // UI Controls
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                const Spacer(),
                const SizedBox(height: 20),
                _buildActionButtons(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildCircleButton(
            icon: Icons.arrow_back,
            onPressed: () {
              if (widget.onBack != null) {
                widget.onBack!();
              } else {
                Navigator.of(context).maybePop();
              }
            },
          ),
          _buildCircleButton(
            icon: _isFlashOn ? Icons.flash_on : Icons.flash_off,
            onPressed: () async {
              await _cameraController.toggleTorch();
              setState(() => _isFlashOn = !_isFlashOn);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildActionButtons() {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildActionButton(
          Icons.image_rounded,
          l10n.commonUpload,
          _pickFromGallery,
        ),
        const SizedBox(width: 24),
        _buildActionButton(
          Icons.help_outline_rounded,
          l10n.commonHelp,
          _showHelpModal,
        ),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).primaryColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
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
