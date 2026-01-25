import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../controllers/dashboard_controller.dart';
import 'login_screen.dart';
import 'main_screen.dart';
import '../l10n/generated/app_localizations.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

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

    _navigateTo(const MainScreen());
  }

  Future<void> _delayedNavigateToLogin() async {
    // Small animation buffer for branding
    await Future.delayed(const Duration(milliseconds: 1500));
    _navigateTo(const LoginScreen());
  }

  void _navigateTo(Widget page) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1F71), // Navy
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
                      colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                        blurRadius: 30,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
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
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                )
                .animate()
                .fadeIn(delay: 400.ms, duration: 600.ms)
                .slideY(begin: 0.2, end: 0),

            const SizedBox(height: 12),

            // Tagline
            Text(
              'Secure. Simple. Global.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.white70,
                letterSpacing: 2.0,
              ),
            ).animate().fadeIn(delay: 600.ms, duration: 600.ms),

            const SizedBox(height: 64),

            // Loading Text
            Text(
                  AppLocalizations.of(context)?.splashLoading ??
                      'Connecting...',
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
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
