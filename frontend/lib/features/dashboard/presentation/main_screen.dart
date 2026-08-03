import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

import 'package:frontend/features/dashboard/presentation/dashboard_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:frontend/core/network/api_service.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import 'package:frontend/core/network/connectivity_service.dart';
import 'package:frontend/core/widgets/vpn_required_sheet.dart';
import 'package:frontend/features/dashboard/presentation/home_view.dart';
import 'package:frontend/features/profile/presentation/profile_page.dart';
import 'package:frontend/core/widgets/nav_glyph.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final ApiService _apiService = ApiService();
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();

    _prewarmCache();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedOut) {
        if (mounted) {
          context.go('/login');
        }
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  Future<void> _prewarmCache() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;
    try {
      await _apiService.getUserProfile();
    } catch (e) {
      debugPrint('⚠️ [MainScreen] Prewarm cache failed: $e');
    }
  }

  List<Widget> get _screens => [
    const HomeView(),
    const ProfilePage(),
  ];

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;
    HapticFeedback.lightImpact();
    setState(() => _selectedIndex = index);
  }

  Widget _buildTabItem(int index, NavGlyphType glyph, String label) {
    final isSelected = _selectedIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final activeColor = isDark ? Colors.white : AppTheme.primaryColor(context);
    final inactiveColor = AppTheme.textSecondaryColor(context).withValues(alpha: 0.6);
    final color = isSelected ? activeColor : inactiveColor;

    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        label: label,
        child: GestureDetector(
          onTap: () => _onItemTapped(index),
          behavior: HitTestBehavior.opaque,
          child: Container(
            color: Colors.transparent, // Ensures the entire area is clickable
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutQuint,
                  padding: EdgeInsets.symmetric(
                    horizontal: isSelected ? 20 : 12,
                    vertical: isSelected ? 8 : 4,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected 
                      ? (isDark ? Colors.white.withValues(alpha: 0.1) : AppTheme.primaryTeal.withValues(alpha: 0.08))
                      : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      NavGlyph(
                        type: glyph,
                        isActive: isSelected,
                        color: color,
                        size: 24.0,
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: color,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _selectedIndex != 0) setState(() => _selectedIndex = 0);
      },
      child: Scaffold(
        extendBody: true, // Content scrolls UNDER the pill
        backgroundColor: theme.scaffoldBackgroundColor,
        body: IndexedStack(index: _selectedIndex, children: _screens),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Container(
              height: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(36),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(36),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: isDark 
                        ? const Color(0xFF121212)
                        : Colors.white.withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(36),
                      border: Border.all(
                        color: isDark 
                          ? Colors.white.withValues(alpha: 0.2)
                          : Colors.black.withValues(alpha: 0.08),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildTabItem(0, NavGlyphType.home, "Home"),
                        const _EmbeddedScanButton(),
                        _buildTabItem(1, NavGlyphType.profile, "Profile"),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// EMBEDDED SCAN BUTTON (Pill-in-Pill Design)
// ────────────────────────────────────────────────────────────
class _EmbeddedScanButton extends StatefulWidget {
  const _EmbeddedScanButton();

  @override
  State<_EmbeddedScanButton> createState() => _EmbeddedScanButtonState();
}

class _EmbeddedScanButtonState extends State<_EmbeddedScanButton> {
  bool _isPressed = false;

  Future<void> _openScanner() async {
    final connectivity = context.read<ConnectivityService>();
    if (connectivity.isVpnActive) {
      HapticFeedback.heavyImpact();
      await VpnRequiredSheet.show(context);
      return;
    }
    HapticFeedback.mediumImpact();
    await context.push('/scan');
    if (mounted) context.read<DashboardController>().refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: "Scan QR Code",
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          _openScanner();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.92 : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutQuad,
          child: Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: AppTheme.primaryTeal,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: CustomScanIcon(
                size: 24.0,
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// CUSTOM SCANNER ICON (Vector Painting)
// ────────────────────────────────────────────────────────────
class CustomScanIcon extends StatelessWidget {
  final double size;
  final Color color;
  final double strokeWidth;

  const CustomScanIcon({
    super.key,
    this.size = 28.0,
    this.color = Colors.white,
    this.strokeWidth = 2.5,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _ScanIconPainter(color: color, strokeWidth: strokeWidth),
    );
  }
}

class _ScanIconPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _ScanIconPainter({required this.color, this.strokeWidth = 2.5});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    
    final cornerLength = w * 0.28; 
    final radius = 3.5;           

    // Top-Left
    final pathTL = Path()
      ..moveTo(0, cornerLength)
      ..lineTo(0, radius)
      ..quadraticBezierTo(0, 0, radius, 0)
      ..lineTo(cornerLength, 0);
    canvas.drawPath(pathTL, paint);

    // Top-Right
    final pathTR = Path()
      ..moveTo(w - cornerLength, 0)
      ..lineTo(w - radius, 0)
      ..quadraticBezierTo(w, 0, w, radius)
      ..lineTo(w, cornerLength);
    canvas.drawPath(pathTR, paint);

    // Bottom-Left
    final pathBL = Path()
      ..moveTo(0, h - cornerLength)
      ..lineTo(0, h - radius)
      ..quadraticBezierTo(0, h, radius, h)
      ..lineTo(cornerLength, h);
    canvas.drawPath(pathBL, paint);

    // Bottom-Right
    final pathBR = Path()
      ..moveTo(w - cornerLength, h)
      ..lineTo(w - radius, h)
      ..quadraticBezierTo(w, h, w, h - radius)
      ..lineTo(w, h - cornerLength);
    canvas.drawPath(pathBR, paint);

    // Middle Laser Line
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(-1.5, h / 2),
      Offset(w + 1.5, h / 2),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScanIconPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}
