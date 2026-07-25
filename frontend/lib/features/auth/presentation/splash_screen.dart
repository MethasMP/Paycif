import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_animate/flutter_animate.dart';
import 'package:frontend/features/dashboard/presentation/dashboard_controller.dart';
import 'package:go_router/go_router.dart' as import_go_router;
import 'package:frontend/core/l10n/generated/app_localizations.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

import 'package:provider/provider.dart';
import 'package:frontend/features/security/presentation/logic/security_controller.dart';
import 'package:frontend/core/widgets/paycif_text.dart';
import 'package:frontend/core/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  int _currentDelaySeconds = 1;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final startTime = DateTime.now();

    try {
      // 1. Check Auth Session (Enhanced with Auto-Recovery)
      final session = Supabase.instance.client.auth.currentSession;

      if (session == null) {
        await _delayedNavigateToLogin();
        return;
      }

      // 🛡️ Proactive Check: Is the cached session actually valid?
      final isExpired = JwtDecoder.isExpired(session.accessToken);
      if (isExpired) {
        debugPrint("Session expired on startup. Attempting silent recovery...");
        try {
          final refreshResponse = await Supabase.instance.client.auth.refreshSession();
          if (refreshResponse.session != null) {
            debugPrint("✅ Session recovered successfully via Refresh Token.");
          } else {
            debugPrint("⚠️ Refresh returned null, but keeping session for PIN unlock self-healing.");
          }
        } catch (e) {
          debugPrint("⚠️ Network/Refresh error during splash ($e). Proceeding with local PIN authentication.");
        }
      }

      // 2. User is Logged In -> Wait for "Dark Warming" (Data Readiness)
      // We listen to the Bloc and proceed once warmed.
      if (!mounted) return;
      final dashboardController = context.read<DashboardController>();

      // Start a timer for safety (Max 5s wait)
      var isWarmed = dashboardController.state.isDataWarmed;
      final timeout = DateTime.now().add(const Duration(seconds: 5));

      while (!isWarmed && DateTime.now().isBefore(timeout)) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (!mounted) return;
        isWarmed = dashboardController.state.isDataWarmed;
      }

      // 3. Ensure minimum branding time (at least 1.5s total)
      final elapsed = DateTime.now().difference(startTime);
      if (elapsed < const Duration(milliseconds: 1500)) {
        await Future.delayed(const Duration(milliseconds: 1500) - elapsed);
      }

      // 🛡️ World-Class Security: Mandatory Pin/Biometric Check
      if (!mounted) return;
      final securityController = context.read<SecurityController>();
      final hasPin = await securityController.hasPin();

      // Reset delay on success
      _currentDelaySeconds = 1;

      if (hasPin) {
        debugPrint("🚨 [Security] PIN detected. Challenging user identity...");
        _navigateTo('/unlock');
      } else {
        debugPrint("🔓 [Security] No PIN set. Enforcing PIN setup...");
        _navigateTo('/pin_setup');
      }
    } catch (e) {
      debugPrint("❌ Connection error during startup: $e");
      
      // If it is a true AuthException, it signifies a credentials/session failure
      if (e is AuthException) {
        debugPrint("Session is invalid/expired. Forcing login...");
        await Supabase.instance.client.auth.signOut();
        await _delayedNavigateToLogin();
        return;
      }
      
      // Silent Exponential Backoff Retry (1s -> 2s -> 4s -> 5s max)
      debugPrint("🔁 Retrying connection in $_currentDelaySeconds seconds...");
      await Future.delayed(Duration(seconds: _currentDelaySeconds));
      
      _currentDelaySeconds = (_currentDelaySeconds * 2).clamp(1, 5);
      
      if (mounted) {
        _initializeApp();
      }
    }
  }

  Future<void> _delayedNavigateToLogin() async {
    // Small animation buffer for branding
    await Future.delayed(const Duration(milliseconds: 1500));
    _navigateTo('/login');
  }

  void _navigateTo(String path) {
    if (!mounted) return;
    HapticFeedback.mediumImpact(); // 🧠 Haptic Ritual: The vibration of 'Ready'
    import_go_router.GoRouter.of(context).go(path);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduce = MediaQuery.of(context).disableAnimations;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Brand mark — the same intersecting rings as the login screen,
            // drawn straight on canvas: splash and login read as one identity.
            SizedBox(
              width: 56,
              height: 56,
              child: CustomPaint(
                painter: _SplashRingsPainter(
                  primaryColor: AppTheme.textPrimaryColor(context),
                  secondaryColor: AppTheme.primaryColor(context),
                ),
              ),
            )
                .animate(target: reduce ? 0 : 1)
                .fadeIn(duration: 500.ms)
                .scale(
                  begin: const Offset(0.9, 0.9),
                  end: const Offset(1, 1),
                  duration: 400.ms,
                  curve: Curves.easeOutCubic,
                ),

            const SizedBox(height: 24),

            // Wordmark — identical treatment to the login screen
            Text(
                  'paycif',
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontSize: 34,
                    color: AppTheme.textPrimaryColor(context),
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.8,
                  ),
                )
                .animate(target: reduce ? 0 : 1)
                .fadeIn(delay: 400.ms, duration: 600.ms)
                .slideY(begin: 0.2, end: 0),

            const SizedBox(height: 10),

            // Tagline
            Text(
              AppLocalizations.of(context)?.splashTagline ?? 'Secure. Simple. Global.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppTheme.textSecondaryColor(context),
                fontWeight: FontWeight.w400,
              ),
            ).animate(target: reduce ? 0 : 1).fadeIn(delay: 600.ms, duration: 600.ms),

            const SizedBox(height: 64),
            // Loading Text
            PaycifText(
                  AppLocalizations.of(context)?.splashLoading ??
                      'Connecting...',
                  style: PaycifTextStyle.caption,
                  color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.7),
                )
                .animate(
                  target: reduce ? 0 : 1,
                  onPlay: (controller) {
                    if (!reduce) controller.repeat();
                  },
                )
                .fadeIn(duration: 1000.ms)
                .then()
                .fadeOut(duration: 1000.ms),
          ],
        ),
      ),
    );
  }
}

class _SplashRingsPainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;

  _SplashRingsPainter({required this.primaryColor, required this.secondaryColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    final paint2 = Paint()
      ..color = secondaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(Offset(size.width * 0.40, size.height * 0.5), size.width * 0.28, paint1);
    canvas.drawCircle(Offset(size.width * 0.60, size.height * 0.5), size.width * 0.28, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
