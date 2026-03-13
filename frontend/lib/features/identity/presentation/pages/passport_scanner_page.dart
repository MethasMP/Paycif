import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_mrz_scanner/flutter_mrz_scanner.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/datasources/nfc_passport_datasource.dart';
import '../../domain/entities/passport_data.dart';
import '../../domain/services/identity_coordinator.dart';

/// 🌍 Passport Scanner Page
///
/// The "Ritual" of identity. Minimalist, focused, and magical.
class PassportScannerPage extends StatefulWidget {
  const PassportScannerPage({super.key});

  @override
  State<PassportScannerPage> createState() => _PassportScannerPageState();
}

class _PassportScannerPageState extends State<PassportScannerPage> {
  MRZController? _controller;
  bool _isNFCOverlayVisible = false;
  bool _isLivenessActive = false;
  int _blinkCount = 0;
  String _livenessInstruction = 'Please blink your eyes';
  PassportData? _scannedData;
  String _status = 'Align Passport MRZ in the frame';

  @override
  void dispose() {
    _controller?.stopPreview();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 📷 The Camera View (The Observer)
          MRZScanner(
            withOverlay: true,
            onControllerCreated: (controller) {
              _controller = controller;
              controller.onParsed = (result) async {
                if (_isNFCOverlayVisible || _isLivenessActive) return;
                setState(() {
                  _status = 'Passport Detected. Hold tight...';
                });
                await _startNFCHandshake(
                  docNum: result.documentNumber,
                  birth: result.birthDate.toString(),
                  expiry: result.expiryDate.toString(),
                );
              };
              controller.startPreview();
            },
          ),

          // 🎨 Steve Jobs Level UI Overlay
          _buildBrandingOverlay(),
          if (_isNFCOverlayVisible) _buildNFCRitualOverlay(),
          if (_isLivenessActive) _buildLivenessOverlay(),
        ],
      ),
    );
  }

  Widget _buildBrandingOverlay() {
    return Positioned(
      top: 60,
      left: 0,
      right: 0,
      child: Column(
        children: [
          Text(
            'Paycif Identity',
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.2,
            ),
          ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.2),
          const SizedBox(height: 8),
          Text(
            _status,
            style: GoogleFonts.outfit(
              fontSize: 16,
              color: Colors.white70,
            ),
          ).animate(key: ValueKey(_status)).fadeIn().scaleX(begin: 0.9),
        ],
      ),
    );
  }

  Widget _buildNFCRitualOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.nfc_rounded,
              size: 100,
              color: Colors.blueAccent,
            )
                .animate(onPlay: (controller) => controller.repeat())
                .scale(
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1.2, 1.2),
                  duration: 1.seconds,
                  curve: Curves.easeInOut,
                )
                .then()
                .fadeOut(duration: 500.ms),
            const SizedBox(height: 40),
            Text(
              'Now, place your phone on the Passport Chip',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 20,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ).animate().fadeIn().moveY(begin: 20, end: 0),
          ],
        ),
      ),
    ).animate().fadeIn();
  }

  Future<void> _startNFCHandshake({
    required String docNum,
    required String birth,
    required String expiry,
  }) async {
    setState(() {
      _isNFCOverlayVisible = true;
      _blinkCount = 0;
      _livenessInstruction = 'Please blink your eyes';
    });

    final nfcSource = NfcPassportDataSource();
    try {
      final data = await nfcSource.readPassport(
        documentNumber: docNum,
        birthDate: birth,
        expiryDate: expiry,
      );

      if (!mounted) return;
      if (data != null) {
        // 🚀 Phase 3: Transition to liveness
        setState(() {
          _scannedData = data;
          _isNFCOverlayVisible = false;
          _isLivenessActive = true;
          _status = 'One last thing... verify your presence';
        });

        _onFaceDetected();
      } else {
        setState(() {
          _isNFCOverlayVisible = false;
          _status = 'Could not read passport. Try again.';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isNFCOverlayVisible = false;
        _status = "Connection lost. Let's try again.";
      });
    }
  }

  Widget _buildLivenessOverlay() {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.blueAccent, width: 4),
              ),
              child: ClipOval(
                child: Container(color: Colors.grey[900]),
              ),
            ).animate().fadeIn().scale(begin: const Offset(0.8, 0.8)),
          ),
          Positioned(
            bottom: 150,
            left: 0,
            right: 0,
            child: Text(
              _livenessInstruction,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 20,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ).animate(key: ValueKey(_livenessInstruction)).fadeIn().slideY(
                  begin: 0.5,
                  end: 0,
                ),
          ),
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                3,
                (index) => Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index < _blinkCount
                        ? Colors.blueAccent
                        : Colors.white24,
                  ),
                ),
              ).animate().fadeIn(),
            ),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  // Simulate blink detection
  void _onFaceDetected() {
    Future.delayed(1.seconds, () {
      if (!mounted || !_isLivenessActive) return;

      setState(() {
        _blinkCount++;
        if (_blinkCount >= 3) {
          _isLivenessActive = false;
          if (_scannedData != null) {
            _showRevealDialog(_scannedData!);
          }
        } else {
          _livenessInstruction = 'Blink again ($_blinkCount/3)';
          _onFaceDetected();
        }
      });
    });
  }

  void _showRevealDialog(PassportData data) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 120,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person, size: 80, color: Colors.white24),
              ).animate().shimmer(duration: 2.seconds).scale(
                    begin: const Offset(0.9, 0.9),
                  ),
              const SizedBox(height: 24),
              Text(
                'Identity Verified',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${data.firstName} ${data.lastName}',
                style: GoogleFonts.outfit(fontSize: 18, color: Colors.white70),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () async {
                  final coordinator = IdentityCoordinator();
                  setState(() => _status = 'Binding to Hardware...');
                  Navigator.pop(context);

                  final result = await coordinator.upgradeToHardwareIdentity(
                    data,
                  );

                  if (result != null) {
                    _showSuccessUI();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                ),
                child: const Text('Confirm Identity'),
              ),
            ],
          ),
        ),
      ).animate().scale(curve: Curves.elasticOut, duration: 800.ms),
    );
  }

  void _showSuccessUI() {
    setState(() {
      _status = 'Identity Secured in Hardware 🛡️';
    });
  }
}
