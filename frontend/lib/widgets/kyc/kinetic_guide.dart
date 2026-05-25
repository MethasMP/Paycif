import 'dart:async';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class KineticGuide extends StatefulWidget {
  final Function(bool isLive, double confidence) onLivenessCapture;

  const KineticGuide({super.key, required this.onLivenessCapture});

  @override
  State<KineticGuide> createState() => _KineticGuideState();
}

class _KineticGuideState extends State<KineticGuide> {
  CameraController? _cameraController;
  late FaceDetector _faceDetector;
  bool _isBusy = false;

  // Real-time Rotation Values (from MLKit)
  double _yaw = 0;
  double _pitch = 0;
  double _roll = 0;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableLandmarks: false,
        enableClassification: false,
        enableTracking: true,
        performanceMode: FaceDetectorMode.fast,
      ),
    );
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    final frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await _cameraController!.initialize();
      _cameraController!.startImageStream(_processCameraImage);
    } catch (e) {
      debugPrint("Camera Error: $e");
    }

    if (mounted) setState(() {});
  }

  void _processCameraImage(CameraImage image) async {
    if (_isBusy) return;
    _isBusy = true;

    // MLKit processing logic would go here.
    // For visual Tesla-style effect demo, we use state-based interpolation.

    _isBusy = false;
  }

  // API for parent to update pose
  void updateFacePose(double yaw, double pitch, double roll) {
    if (!mounted) return;
    setState(() {
      _yaw = yaw;
      _pitch = pitch;
      _roll = roll;
    });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.cyanAccent),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Cyber Camera Preview
          Center(
            child: Opacity(
              opacity: 0.5,
              child: AspectRatio(
                aspectRatio: 1 / _cameraController!.value.aspectRatio,
                child: CameraPreview(_cameraController!),
              ),
            ),
          ),

          // 2. Tesla-style 3D Kinetic Mesh Overlay
          Positioned.fill(
            child: CustomPaint(
              painter: CyberHeadPainter(yaw: _yaw, pitch: _pitch, roll: _roll),
            ),
          ),

          // 3. UI Hud Elements
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                children: [
                  _buildHudHeader(),
                  const Spacer(),
                  _buildInstructionCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHudHeader() {
    return Column(
      children: [
        Text(
          "IDENTITY ASSURANCE V1.0",
          style: TextStyle(
            color: Colors.cyanAccent.withValues(alpha: 0.9),
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 6,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 1,
          width: 60,
          color: Colors.cyanAccent.withValues(alpha: 0.5),
        ),
      ],
    );
  }

  Widget _buildInstructionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.face_retouching_natural,
            color: Colors.cyanAccent,
            size: 28,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "KINETIC ALIGNMENT",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "Align your face with the cyber-mesh guide.",
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CyberHeadPainter extends CustomPainter {
  final double yaw;
  final double pitch;
  final double roll;

  CyberHeadPainter({
    required this.yaw,
    required this.pitch,
    required this.roll,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final glowPaint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0;

    // Define a 3D Cyber-Head wireframe points [x, y, z]
    List<List<double>> headPoints = [
      [0, -120, 0], // 0: Top
      [70, -70, 50], // 1: Forehead R
      [-70, -70, 50], // 2: Forehead L
      [90, 20, 30], // 3: Cheek R
      [-90, 20, 30], // 4: Cheek L
      [0, 110, 0], // 5: Chin
      [0, 10, 100], // 6: Nose Tip
      [40, 80, 40], // 7: Jaw R
      [-40, 80, 40], // 8: Jaw L
    ];

    // Projection & Rotation Logic
    List<Offset> projectedPoints = [];
    for (var p in headPoints) {
      var rotated = _rotate(p, yaw, pitch, roll);

      // Simple perspective projection
      double zScale = 400;
      double factor = zScale / (zScale - rotated[2]);

      projectedPoints.add(
        Offset(
          center.dx + rotated[0] * factor,
          center.dy + rotated[1] * factor,
        ),
      );
    }

    // Draw Mesh Connections
    void drawLine(int i, int j) {
      canvas.drawLine(projectedPoints[i], projectedPoints[j], glowPaint);
      canvas.drawLine(projectedPoints[i], projectedPoints[j], paint);
    }

    // Connect the cyber-mask
    drawLine(0, 1);
    drawLine(0, 2);
    drawLine(1, 3);
    drawLine(2, 4);
    drawLine(3, 7);
    drawLine(4, 8);
    drawLine(7, 5);
    drawLine(8, 5);

    // Connect Nose Tip (The 3D Anchor)
    drawLine(6, 1);
    drawLine(6, 2);
    drawLine(6, 3);
    drawLine(6, 4);
    drawLine(6, 5);

    // Draw scanning "Pulse" ring
    final double pulse =
        (math.sin(DateTime.now().millisecondsSinceEpoch / 400) + 1) / 2;
    canvas.drawCircle(
      center,
      140 + (pulse * 20),
      Paint()
        ..color = Colors.cyanAccent.withValues(alpha: 0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  List<double> _rotate(List<double> p, double yaw, double pitch, double roll) {
    double x = p[0];
    double y = p[1];
    double z = p[2];

    // Convert degrees to radians
    double ry = yaw * math.pi / 180;
    double rx = pitch * math.pi / 180;
    double rz = roll * math.pi / 180;

    // Rotate Y (Yaw)
    double tx = x * math.cos(ry) + z * math.sin(ry);
    double tz = -x * math.sin(ry) + z * math.cos(ry);
    x = tx;
    z = tz;

    // Rotate X (Pitch)
    double ty = y * math.cos(rx) - z * math.sin(rx);
    tz = y * math.sin(rx) + z * math.cos(rx);
    y = ty;
    z = tz;

    // Rotate Z (Roll)
    tx = x * math.cos(rz) - y * math.sin(rz);
    ty = x * math.sin(rz) + y * math.cos(rz);
    x = tx;
    y = ty;

    return [x, y, z];
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
