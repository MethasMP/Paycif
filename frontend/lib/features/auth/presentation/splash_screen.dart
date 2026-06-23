import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
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
        debugPrint("⚠️ Session expired on startup. Attempting recovery...");
        try {
          final refreshResponse = await Supabase.instance.client.auth
              .refreshSession();
          if (refreshResponse.session == null) {
            throw Exception("Refresh failed");
          }
          debugPrint("✅ Session recovered successfully.");
        } catch (e) {
          debugPrint("❌ Recovery failed. Redirecting to login.");
          await _delayedNavigateToLogin();
          return;
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

      if (hasPin) {
        debugPrint("🚨 [Security] PIN detected. Challenging user identity...");
        _navigateTo('/unlock');
      } else {
        debugPrint("🔓 [Security] No PIN set. Enforcing PIN setup...");
        _navigateTo('/pin_setup');
      }
    } catch (e) {
      debugPrint("❌ Fatal error during startup: $e");
      // Fallback: Clear session and force user to login to recover state
      await Supabase.instance.client.auth.signOut();
      await _delayedNavigateToLogin();
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
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Paycif Logo (Shield)
            Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.accentGold, AppTheme.accentGoldDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentGold.withValues(alpha: 0.3),
                        blurRadius: 30,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(
                    PhosphorIcons.shield,
                    size: 60,
                    color: Colors.white,
                  ),
                )
                .animate()
                .fadeIn(duration: 800.ms)
                .scale(duration: 600.ms, curve: Curves.elasticOut),

            const SizedBox(height: 32),

            // Title
            Text(
                  'Paycif',
                  style: theme.textTheme.displayMedium?.copyWith(
                    color: AppTheme.textPrimaryColor(context),
                    fontWeight: FontWeight.w600,
                  ),
                )
                .animate()
                .fadeIn(delay: 400.ms, duration: 600.ms)
                .slideY(begin: 0.2, end: 0),

            const SizedBox(height: 12),

            // Tagline
            Text(
              'Secure. Simple. Global.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppTheme.textSecondaryColor(context),
                letterSpacing: 2.0,
              ),
            ).animate().fadeIn(delay: 600.ms, duration: 600.ms),

            const SizedBox(height: 64),

            // Loading Text
            PaycifText(
                  AppLocalizations.of(context)?.splashLoading ??
                      'Connecting...',
                  style: PaycifTextStyle.caption,
                  color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.7),
                )
                .animate(onPlay: (controller) => controller.repeat())
                .fadeIn(duration: 1000.ms)
                .then()
                .fadeOut(duration: 1000.ms),
          ],
        ),
      ),
    );
  }
}
