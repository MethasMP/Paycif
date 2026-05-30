import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/dashboard_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart' as import_login;
import '../services/api_service.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:ui' as ui;

import 'home_view.dart';
import 'payment_settings_screen.dart';
import 'history_screen.dart';
import 'profile_page.dart';
import 'scan_page.dart';

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
  static const double _barHeight = 70.0;
  static const double _scanButtonSize = 72.0; // 72px circle as per design.md
  static const double _iconSize = 26.0;
  static const double _dotWidth = 14.0;
  static const double _scanButtonOffset = 16.0; // Overlapping overflow bottom offset

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

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
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const import_login.LoginScreen()),
            (route) => false,
          );
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
      await Future.wait([
        _apiService.getUserProfile(),
        _apiService.getSavedCards(),
      ]);
    } catch (_) {}
  }

  List<Widget> get _screens => [
    const HomeView(),
    const HistoryScreen(),
    const PaymentSettingsScreen(),
    const ProfilePage(),
  ];

  void _onItemTapped(int index) {
    HapticFeedback.lightImpact();
    setState(() => _selectedIndex = index);
  }

  void _openScanner() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ScanPage())).then((_) {
      if (mounted) context.read<DashboardController>().refresh();
    });
  }

  // Calculates the horizontal starting point of the sliding active dot
  double _calculateDotLeft(double totalWidth) {
    final double colWidth = totalWidth / 5;
    // Map selected index (0-3) to columns (0, 1, 3, 4), skipping the center column (2)
    final int activeCol = _selectedIndex >= 2 ? _selectedIndex + 1 : _selectedIndex;
    return (activeCol + 0.5) * colWidth - _dotWidth / 2;
  }

  Widget _buildTabItem(int index, IconData unselectedIcon, IconData selectedIcon, double width) {
    final isSelected = _selectedIndex == index;
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      height: _barHeight,
      child: InkWell(
        onTap: () => _onItemTapped(index),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        child: Center(
          child: AnimatedScale(
            scale: isSelected ? 1.08 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
            child: Icon(
              isSelected ? selectedIcon : unselectedIcon,
              color: isSelected ? theme.primaryColor : Colors.grey[400],
              size: _iconSize,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final floatMargin = bottomPadding > 0 ? bottomPadding : 20.0;

    // Total height of bottom bar area, including popping space of FAB button
    const double totalBarHeight = _barHeight + 12.0;

    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _selectedIndex != 0) setState(() => _selectedIndex = 0);
      },
      child: Scaffold(
        extendBody: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        body: IndexedStack(index: _selectedIndex, children: _screens),
        bottomNavigationBar: Container(
          height: totalBarHeight + floatMargin,
          color: Colors.transparent,
          padding: EdgeInsets.only(
            left: 20.0,
            right: 20.0,
            bottom: floatMargin,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double totalWidth = constraints.maxWidth;
              final double colWidth = totalWidth / 5;
              final double dotLeft = _calculateDotLeft(totalWidth);

              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  // 1. Glassmorphic Dock Container
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: _barHeight,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(32.0),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.cardColor.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(32.0),
                            border: Border.all(
                              color: theme.brightness == Brightness.dark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.05),
                              width: 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 15,
                                spreadRadius: 0,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 2. Sliding Dot Indicator
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    left: dotLeft,
                    bottom: 6.0,
                    child: Container(
                      width: _dotWidth,
                      height: 4.0,
                      decoration: BoxDecoration(
                        color: theme.primaryColor,
                        borderRadius: BorderRadius.circular(2.0),
                      ),
                    ),
                  ),

                  // 3. Navigation Tab Items Row
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: _barHeight,
                    child: Row(
                      children: [
                        _buildTabItem(0, PhosphorIconsRegular.house, PhosphorIconsFill.house, colWidth),
                        _buildTabItem(1, PhosphorIconsRegular.receipt, PhosphorIconsFill.receipt, colWidth), // Note: We can toggle duotone dynamically if there is new activity
                        SizedBox(width: colWidth), // Center spacer for FAB
                        _buildTabItem(2, PhosphorIconsRegular.wallet, PhosphorIconsFill.wallet, colWidth),
                        _buildTabItem(3, PhosphorIconsRegular.userCircle, PhosphorIconsFill.userCircle, colWidth),
                      ],
                    ),
                  ),

                  // 4. Center QR Scan Button (Popping up)
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
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFFEF9F27).withValues(alpha: _pulseOpacityAnimation.value),
                                    ),
                                  ),
                                );
                              },
                            ),
                            // Main Gold CTA button
                            Container(
                              width: _scanButtonSize,
                              height: _scanButtonSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFEF9F27),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF0F6E56).withValues(alpha: 0.08),
                                    blurRadius: 8,
                                    spreadRadius: 0,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(
                                  PhosphorIconsBold.qrCode,
                                  color: Color(0xFF412402), // accent-900
                                  size: 28.0, // 28px QR icon
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
