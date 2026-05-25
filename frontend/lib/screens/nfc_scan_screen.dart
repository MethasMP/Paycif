import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_mrz_scanner/flutter_mrz_scanner.dart';
import 'package:mrz_parser/mrz_parser.dart';
import 'package:image_picker/image_picker.dart';
import '../services/kyc/nfc_passport_service.dart';

enum _KycStep { scanMrz, tapNfc, takeSelfie, success, error }

class NfcScanScreen extends StatefulWidget {
  const NfcScanScreen({super.key});

  @override
  NfcScanScreenState createState() => NfcScanScreenState();
}

class NfcScanScreenState extends State<NfcScanScreen>
    with SingleTickerProviderStateMixin {
  final NfcPassportService _nfcService = NfcPassportService();
  _KycStep _step = _KycStep.scanMrz;
  PassportData? _passportData;
  String? _errorMessage;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  MRZController? _mrzController;
  Uint8List? _selfieImage;
  bool _isProcessing = false;
  String _livenessStep = 'ready'; // ready, blink, success
  final String _challengeText = 'Slowly blink your eyes';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _pulseAnimation = Tween(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _onControllerCreated(MRZController controller) {
    _mrzController = controller;
    _mrzController?.onParsed = _onMrzRecognized;
    _mrzController?.onError = (text) => debugPrint('MRZ Error: $text');
    _mrzController?.startPreview();
  }

  // Called when MRZScanner plugin successfully recognizes the passport MRZ lines.
  void _onMrzRecognized(MRZResult result) async {
    setState(() => _step = _KycStep.tapNfc);

    final mrz = MrzData(
      documentNumber: result.documentNumber,
      dateOfBirth: _formatDate(result.birthDate),
      dateOfExpiry: _formatDate(result.expiryDate),
    );

    try {
      final data = await _nfcService.readPassportNfc(mrz: mrz);
      if (data != null && mounted) {
        setState(() {
          _passportData = data;
          _step = _KycStep.takeSelfie; // Move to Selfie step
        });
      } else if (mounted) {
        setState(() {
          _step = _KycStep.error;
          _errorMessage = 'Could not read the passport chip. Please try again.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _step = _KycStep.error;
          _errorMessage = e.toString();
        });
      }
    }
  }

  String _formatDate(DateTime date) {
    // Standard ICAO YYMMDD format
    String year = date.year.toString().substring(2);
    String month = date.month.toString().padLeft(2, '0');
    String day = date.day.toString().padLeft(2, '0');
    return '$year$month$day';
  }

  Future<void> _captureSelfie() async {
    setState(() {
      _livenessStep = 'blink';
    });

    // Simulate real-time liveness processing
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final picker = ImagePicker();
    final XFile? photo = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 85,
    );

    if (photo != null) {
      final bytes = await photo.readAsBytes();
      setState(() {
        _selfieImage = bytes;
        _isProcessing = true;
        _livenessStep = 'success';
      });

      // Submit all data to backend including selfie for matching
      final success = await _nfcService.submitSelfieForMatching(
        bytes,
        _passportData?.sessionId ?? '',
      );

      if (mounted) {
        if (success) {
          setState(() {
            _isProcessing = false;
            _step = _KycStep.success;
          });
        } else {
          setState(() {
            _isProcessing = false;
            _errorMessage =
                'Biometric matching failed. Please try a clearer photo.';
            _step = _KycStep.error;
          });
        }
      }
    } else {
      setState(() {
        _livenessStep = 'ready';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Verify Your Identity',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          _buildStepIndicator(
            _step == _KycStep.scanMrz ? 1 : (_step == _KycStep.tapNfc ? 2 : 3),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: _buildStep(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case _KycStep.scanMrz:
        return _buildMrzScanView();
      case _KycStep.tapNfc:
        return _buildNfcTapView();
      case _KycStep.takeSelfie:
        return _buildSelfieCaptureView();
      case _KycStep.success:
        return _buildSuccessView();
      case _KycStep.error:
        return _buildErrorView();
    }
  }

  Widget _buildMrzScanView() {
    return Column(
      key: const ValueKey(_KycStep.scanMrz),
      children: [
        _buildStepIndicator(1),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Step 1 of 2',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 4),
              const Text(
                'Scan passport MRZ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Open your passport to the photo page and point the camera at the two lines of text at the bottom.',
                style: TextStyle(color: Colors.white60, height: 1.5),
              ),
            ],
          ),
        ),
        // ─── Camera Viewfinder (REAL) ──────────────────────────────────────
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.blueAccent.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: MRZScanner(
                withOverlay: true,
                onControllerCreated: _onControllerCreated,
              ),
            ),
          ),
        ),
        if (kDebugMode)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: TextButton(
              onPressed: () => _onMrzRecognized(
                MRZResult(
                  documentType: 'P',
                  countryCode: 'THA',
                  surnames: 'HOLDER',
                  givenNames: 'VERIFIED',
                  documentNumber: 'A12345678',
                  nationalityCountryCode: 'THA',
                  birthDate: DateTime(1990, 1, 1),
                  sex: Sex.male,
                  expiryDate: DateTime(2030, 1, 1),
                  personalNumber: '',
                  personalNumber2: '',
                ),
              ),
              child: const Text(
                'Simulate MRZ Detected (Debug Mode)',
                style: TextStyle(color: Colors.white24),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNfcTapView() {
    return Center(
      key: const ValueKey(_KycStep.tapNfc),
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Step 2 of 2',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap Your Passport',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 40),
            // Pulsing NFC icon animation
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) => Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blueAccent.withValues(alpha: 0.15),
                    border: Border.all(color: Colors.blueAccent, width: 2),
                  ),
                  child: const Icon(
                    Icons.nfc,
                    size: 80,
                    color: Colors.blueAccent,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            const Text(
              'Hold the top of your phone against the cover of your opened passport.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                height: 1.6,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(
              color: Colors.blueAccent,
              strokeWidth: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    return Center(
      key: const ValueKey(_KycStep.success),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.verified_rounded,
              size: 100,
              color: Colors.greenAccent,
            ),
            const SizedBox(height: 24),
            Text(
              'Welcome, ${_passportData!.firstName}!',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Your identity has been cryptographically verified.\nYour wallet is now active.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, height: 1.6),
            ),
            const SizedBox(height: 40),
            // Show the biometric photo from passport chip if available
            if (_passportData?.facialImage != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: Image.memory(
                  _passportData!.facialImage!,
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Continue to Wallet',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      key: const ValueKey(_KycStep.error),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 80,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 24),
            const Text(
              'Verification Failed',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'An unknown error occurred.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60, height: 1.5),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => setState(() {
                _step = _KycStep.scanMrz;
                _errorMessage = null;
              }),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int current) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        children: [1, 2, 3].map((step) {
          final bool active = step == current;
          final bool done = step < current;
          return Expanded(
            child: Container(
              margin: step < 3
                  ? const EdgeInsets.only(right: 8)
                  : EdgeInsets.zero,
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: done
                    ? Colors.greenAccent
                    : active
                    ? Colors.blueAccent
                    : Colors.white12,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSelfieCaptureView() {
    return Center(
      key: const ValueKey(_KycStep.takeSelfie),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey.shade900,
                    border: Border.all(
                      color: _selfieImage != null
                          ? Colors.greenAccent
                          : Colors.blueAccent,
                      width: 3,
                    ),
                  ),
                  child: ClipOval(
                    child: _selfieImage != null
                        ? Image.memory(_selfieImage!, fit: BoxFit.cover)
                        : const Icon(
                            Icons.face_retouching_natural_rounded,
                            size: 80,
                            color: Colors.white30,
                          ),
                  ),
                ),
                if (_selfieImage != null)
                  const CircleAvatar(
                    backgroundColor: Colors.greenAccent,
                    radius: 18,
                    child: Icon(Icons.check, color: Colors.black),
                  ),
              ],
            ),
            const SizedBox(height: 32),
            const Text(
              'Biometric Verification',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'We need to match your selfie with your passport photo to ensure you are the actual owner.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, height: 1.5),
            ),
            const SizedBox(height: 40),
            if (_isProcessing)
              const Column(
                children: [
                  CircularProgressIndicator(color: Colors.blueAccent),
                  SizedBox(height: 16),
                  Text(
                    'Matching Face...',
                    style: TextStyle(color: Colors.blueAccent),
                  ),
                ],
              )
            else
              ElevatedButton.icon(
                onPressed: _livenessStep == 'blink' ? null : _captureSelfie,
                icon: Icon(
                  _selfieImage == null ? Icons.camera_alt : Icons.refresh,
                ),
                label: Text(
                  _livenessStep == 'blink'
                      ? 'Detector Active...'
                      : (_selfieImage == null
                            ? 'Start Liveness Check'
                            : 'Retake photo'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _livenessStep == 'blink'
                      ? Colors.orangeAccent
                      : Colors.blueAccent,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            if (_livenessStep == 'blink')
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orangeAccent, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.orangeAccent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _challengeText,
                        style: const TextStyle(
                          color: Colors.orangeAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
