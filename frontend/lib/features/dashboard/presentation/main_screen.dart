import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend/core/l10n/generated/app_localizations.dart';

import 'package:frontend/features/dashboard/presentation/dashboard_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:frontend/core/network/api_service.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import 'package:frontend/features/dashboard/presentation/home_view.dart';
import 'package:frontend/features/transactions/presentation/history_screen.dart';
import 'package:frontend/features/profile/presentation/profile_page.dart';
import 'package:frontend/core/widgets/nav_glyph.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  double _scanButtonScale = 1.0;
  final ApiService _apiService = ApiService();
  late final StreamSubscription<AuthState> _authSubscription;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseScaleAnimation;
  late final Animation<double> _pulseOpacityAnimation;

  // Sizing constants for the premium navigation bar
  static const double _barHeight = 80.0;
  static const double _scanButtonSize = 72.0; // 72px circle as per design.md
  static const double _dotWidth = 14.0;
  static const double _scanButtonOffset = 16.0; // Overlapping overflow bottom offset

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    // Respect reduced-motion: freeze the idle pulse ring entirely.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && MediaQuery.of(context).disableAnimations) {
        _pulseController.stop();
        _pulseController.value = 0.0;
      }
    });

    _pulseScaleAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
    _pulseOpacityAnimation = Tween<double>(begin: 0.5, end: 0.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );

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
    _pulseController.dispose();
    _authSubscription.cancel();
    super.dispose();
  }

  Future<void> _prewarmCache() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;
    try {
      // Removed ensureDeviceBinding() here to prevent unexpected Biometric prompts.
      // Device binding should only happen explicitly via settings or during onboarding.
      await _apiService.getUserProfile();
    } catch (e) {
      debugPrint('⚠️ [MainScreen] Prewarm cache failed: $e');
    }
  }

  List<Widget> get _screens => [
    const HomeView(),
    const HistoryScreen(),
    const ProfilePage(),
  ];

  void _onItemTapped(int index) {
    HapticFeedback.lightImpact();
    setState(() => _selectedIndex = index);
  }

  Future<void> _openScanner() async {
    HapticFeedback.mediumImpact();
    await context.push('/scan');
    if (mounted) context.read<DashboardController>().refresh();
  }

  // 3 real tabs (Home, History, Profile) split unevenly around the center scan
  // FAB — 2 on the left, 1 on the right. The FAB sits at the true screen
  // center (Stack's bottomCenter), so the left and right groups must occupy
  // exactly equal *width* — not equal tab count — or the gap drifts off from
  // where the FAB actually renders and it visually collides with a tab.
  static const double _centerGapFraction = 0.22;

  double get _sideWidthFraction => (1.0 - _centerGapFraction) / 2;

  // Calculates the horizontal starting point of the sliding active dot.
  double _calculateDotLeft(double totalWidth) {
    final double sideWidth = totalWidth * _sideWidthFraction;
    final double leftTabWidth = sideWidth / 2; // Home, History share the left side
    double center;
    switch (_selectedIndex) {
      case 0:
        center = leftTabWidth * 0.5;
        break;
      case 1:
        center = leftTabWidth * 1.5;
        break;
      default: // 2 = Profile, alone on the right side
        center = totalWidth - sideWidth * 0.5;
    }
    return center - _dotWidth / 2;
  }

  Widget _buildTabItem(int index, NavGlyphType glyph, String label, double width) {
    final isSelected = _selectedIndex == index;
    final activeColor = AppTheme.primaryColor(context);
    final inactiveColor = AppTheme.textSecondaryColor(context);
    final color = isSelected ? activeColor : inactiveColor;

    return SizedBox(
      width: width,
      height: _barHeight,
      child: InkWell(
        onTap: () => _onItemTapped(index),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Center(
                  child: AnimatedScale(
                    scale: isSelected ? 1.05 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutQuint,
                    child: NavGlyph(
                      type: glyph,
                      isActive: isSelected,
                      color: color,
                      size: 24.0,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    // Total height of bottom bar area, including popping space of FAB button
    const double totalBarHeight = _barHeight + 12.0;
    final hairline = theme.brightness == Brightness.dark
        ? AppTheme.darkBorderHairline
        : AppTheme.lightBorderHairline;

    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _selectedIndex != 0) setState(() => _selectedIndex = 0);
      },
      child: Scaffold(
        extendBody: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        body: IndexedStack(index: _selectedIndex, children: _screens),
        // Docked edge-to-edge, not a floating pill — Session 002: a bar this
        // load-bearing shouldn't carry its own margin/blur/shadow state. The
        // scan FAB keeps the pop + idle pulse as the one raised element.
        bottomNavigationBar: Container(
          height: totalBarHeight + bottomPadding,
          padding: EdgeInsets.only(bottom: bottomPadding),
          decoration: BoxDecoration(
            color: theme.cardColor,
            border: Border(top: BorderSide(color: hairline, width: 1.0)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double totalWidth = constraints.maxWidth;
              final double sideWidth = totalWidth * _sideWidthFraction;
              final double gapWidth = totalWidth * _centerGapFraction;
              final double leftTabWidth = sideWidth / 2; // Home, History
              final double dotLeft = _calculateDotLeft(totalWidth);

              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  // 1. Sliding Dot Indicator
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutQuint,
                    left: dotLeft,
                    bottom: 6.0,
                    child: Container(
                      width: _dotWidth,
                      height: 4.0,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor(context),
                        borderRadius: BorderRadius.circular(2.0),
                      ),
                    ),
                  ),

                  // 2. Navigation Tab Items Row
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: _barHeight,
                    child: Row(
                      children: [
                        _buildTabItem(0, NavGlyphType.home, l10n.navHome, leftTabWidth),
                        _buildTabItem(1, NavGlyphType.history, l10n.navHistory, leftTabWidth),
                        SizedBox(width: gapWidth), // Center spacer for FAB
                        _buildTabItem(2, NavGlyphType.profile, l10n.navProfile, sideWidth),
                      ],
                    ),
                  ),

                  // 3. Center QR Scan Button (Popping up)
                  Positioned(
                    bottom: _scanButtonOffset,
                    child: GestureDetector(
                      onTapDown: (_) => setState(() => _scanButtonScale = 0.9),
                      onTapUp: (_) => setState(() => _scanButtonScale = 1.0),
                      onTapCancel: () => setState(() => _scanButtonScale = 1.0),
                      onTap: _openScanner,
                      child: AnimatedScale(
                        scale: _scanButtonScale,
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeInOut,
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            // Idle Pulse effect ring
                            AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _pulseScaleAnimation.value,
                                  child: Container(
                                    width: _scanButtonSize,
                                    height: _scanButtonSize,
                                    decoration: ShapeDecoration(
                                      shape: ContinuousRectangleBorder(
                                        borderRadius: BorderRadius.circular(28),
                                      ),
                                      color: AppTheme.primaryColor(context).withValues(alpha: _pulseOpacityAnimation.value),
                                    ),
                                  ),
                                );
                              },
                            ),
                            // Main scan CTA (Squircle) — Action Teal, the app's
                            // single action color; gold stays warning-only.
                            Container(
                              width: 72,
                              height: 72,
                              decoration: ShapeDecoration(
                                color: AppTheme.primaryColor(context),
                                shape: ContinuousRectangleBorder(
                                  borderRadius: BorderRadius.circular(28), // Tuned for better Apple squircle look
                                ),
                                shadows: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: CustomScanIcon(
                                  size: 28.0,
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// CUSTOM SCANNER ICON (Vector Painting for Perfect UI)
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
    
    // Configurable parameters for the vector drawing
    final cornerLength = w * 0.28; // Length of the corner lines (8px)
    final radius = 3.5;           // Smooth corner roundness (Apple-like feel)

    // 1. Top-Left Corner
    final pathTL = Path()
      ..moveTo(0, cornerLength)
      ..lineTo(0, radius)
      ..quadraticBezierTo(0, 0, radius, 0)
      ..lineTo(cornerLength, 0);
    canvas.drawPath(pathTL, paint);

    // 2. Top-Right Corner
    final pathTR = Path()
      ..moveTo(w - cornerLength, 0)
      ..lineTo(w - radius, 0)
      ..quadraticBezierTo(w, 0, w, radius)
      ..lineTo(w, cornerLength);
    canvas.drawPath(pathTR, paint);

    // 3. Bottom-Left Corner
    final pathBL = Path()
      ..moveTo(0, h - cornerLength)
      ..lineTo(0, h - radius)
      ..quadraticBezierTo(0, h, radius, h)
      ..lineTo(cornerLength, h);
    canvas.drawPath(pathBL, paint);

    // 4. Bottom-Right Corner
    final pathBR = Path()
      ..moveTo(w - cornerLength, h)
      ..lineTo(w - radius, h)
      ..quadraticBezierTo(w, h, w, h - radius)
      ..lineTo(w, h - cornerLength);
    canvas.drawPath(pathBR, paint);

    // 5. Middle Laser Line (extends slightly outwards for dynamic scanning visual)
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
