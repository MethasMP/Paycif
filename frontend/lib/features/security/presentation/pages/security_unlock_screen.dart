import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../logic/security_controller.dart';
import '../widgets/pin_entry_widget.dart';
import '../../../../screens/main_screen.dart';

import 'recovery_screen.dart';

class SecurityUnlockScreen extends StatefulWidget {
  const SecurityUnlockScreen({super.key});

  @override
  State<SecurityUnlockScreen> createState() => _SecurityUnlockScreenState();
}

class _SecurityUnlockScreenState extends State<SecurityUnlockScreen> {
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    // 🚀 Auto-Trigger Biometric for a "Magical" Experience
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryBiometricUnlock();
    });
  }

  Future<void> _tryBiometricUnlock() async {
    if (_isAuthenticating) return;

    final controller = context.read<SecurityController>();
    final profile = await controller.getBiometricProfile();

    if (profile.availableTypes.isEmpty) return;

    setState(() => _isAuthenticating = true);

    try {
      final auth = LocalAuthentication();
      final authenticated = await auth.authenticate(
        localizedReason: 'Please verify your identity to unlock Paycif',
        persistAcrossBackgrounding: true,
        biometricOnly: true,
      );

      if (authenticated && mounted) {
        HapticFeedback.mediumImpact();
        // Give time for iOS native Face ID dialog to dismiss fully before replacing route
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) _onUnlockSuccess();
      }
    } catch (e) {
      debugPrint('Biometric unlock failed: $e');
    } finally {
      if (mounted) setState(() => _isAuthenticating = false);
    }
  }

  void _onUnlockSuccess() {
    // 🛡️ World-Class Navigation: Smooth Fade to Home
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const MainScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // isDark is used implicitly in theme checks if needed, but not explicitly used here.
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 60),

              // 🛡️ Premium Identity Header
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock_person_rounded,
                        size: 32,
                        color: Theme.of(context).primaryColor,
                      ),
                    ).animate().scale(
                      duration: 600.ms,
                      curve: Curves.elasticOut,
                    ),

                    const SizedBox(height: 16),

                    Text(
                          'Unlock Paycif',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                        )
                        .animate()
                        .fadeIn(delay: 200.ms)
                        .slideY(begin: 0.2, end: 0),

                    const SizedBox(height: 8),

                    Text(
                      'Verify your identity to continue',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 14,
                      ),
                    ).animate().fadeIn(delay: 400.ms),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // 🔢 PIN Keypad with Forgot Action
              PinEntryWidget(
                showLabel: false,
                onSuccess: (_) => _onUnlockSuccess(),
                onForgotPin: () => _handleForgotPin(context),
              ).animate().fadeIn(delay: 600.ms),

              const SizedBox(height: 24),

              // 🤳 Biometric Action (Primary Alternative)
              TextButton.icon(
                onPressed: _tryBiometricUnlock,
                icon: const Icon(Icons.face_unlock_rounded),
                label: const Text('Use Biometrics'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).primaryColor,
                ),
              ).animate().fadeIn(delay: 800.ms),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  void _handleForgotPin(BuildContext context) {
    // 🛡️ World-Class UX: Seamless Transition to Recovery Protocol
    // Instead of a jarring dialog, we flow into the Identity Challenge.
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const RecoveryScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubicEmphasized;
          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }
}
