import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../logic/security_controller.dart';
import '../widgets/pin_entry_widget.dart';
import '../../../../screens/main_screen.dart';
import '../../../../widgets/paycif_icon_container.dart';

import 'recovery_screen.dart';

class SecurityUnlockScreen extends StatefulWidget {
  const SecurityUnlockScreen({super.key});

  @override
  State<SecurityUnlockScreen> createState() => _SecurityUnlockScreenState();
}

class _SecurityUnlockScreenState extends State<SecurityUnlockScreen> {
  bool _isAuthenticating = false;
  Future<BiometricProfile>? _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = context.read<SecurityController>().getBiometricProfile();
    // 🚀 Auto-Trigger Biometric for a "Magical" Experience
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryAutoBiometricUnlock();
    });
  }

  Future<void> _tryAutoBiometricUnlock() async {
    final prefs = await SharedPreferences.getInstance();
    final biometricEnabled = prefs.getBool('biometric_enabled') ?? false;
    if (biometricEnabled) {
      _tryBiometricUnlock();
    }
  }

  Future<void> _tryBiometricUnlock() async {
    if (_isAuthenticating) return;
    setState(() => _isAuthenticating = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final biometricEnabled = prefs.getBool('biometric_enabled') ?? false;
      if (!biometricEnabled) {
        return; // Abort if disabled by preference
      }

      final controller = context.read<SecurityController>();
      BiometricProfile? profile;
      if (_profileFuture != null) {
        profile = await _profileFuture;
      } else {
        profile = await controller.getBiometricProfile();
      }

      if (profile == null || profile.availableTypes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Biometrics not available or not enrolled on this device.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

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
    context.read<SecurityController>().recordBiometricVerificationSuccess();
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
              SizedBox(height: 60),

              // 🛡️ Premium Identity Header
              Center(
                child: Column(
                  children: [
                    PaycifIconContainer(
                      icon: PhosphorIcons.lockKey,
                    ).animate().scale(
                      duration: 600.ms,
                      curve: Curves.elasticOut,
                    ),

                    SizedBox(height: 16),

                    Text(
                          'Unlock Paycif',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.5,
                              ),
                        )
                        .animate()
                        .fadeIn(delay: 200.ms)
                        .slideY(begin: 0.2, end: 0),

                    SizedBox(height: 8),

                    Text(
                      'Verify your identity to continue',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                        fontSize: 14,
                      ),
                    ).animate().fadeIn(delay: 400.ms),
                  ],
                ),
              ),

              SizedBox(height: 40),

              // 🔢 PIN Keypad with Forgot Action
              PinEntryWidget(
                showLabel: false,
                onSuccess: (_) => _onUnlockSuccess(),
                onForgotPin: () => _handleForgotPin(context),
              ).animate().fadeIn(delay: 600.ms),

              SizedBox(height: 24),

              // 🤳 Biometric Action (Primary Alternative)
              if (_profileFuture != null)
                FutureBuilder<BiometricProfile>(
                  future: _profileFuture,
                  builder: (context, snapshot) {
                    final profile = snapshot.data;
                    if (profile == null) return const SizedBox.shrink();

                    return FutureBuilder<bool>(
                      future: SharedPreferences.getInstance().then((prefs) => prefs.getBool('biometric_enabled') ?? false),
                      builder: (context, enabledSnapshot) {
                        final enabled = enabledSnapshot.data ?? false;
                        if (!enabled) return const SizedBox.shrink();

                        return OutlinedButton.icon(
                          onPressed: _tryBiometricUnlock,
                          icon: Icon(profile.bioIcon),
                          label: Text('Use ${profile.bioName}'),
                        ).animate().fadeIn(delay: 800.ms);
                      },
                    );
                  },
                ),

              SizedBox(height: 40),
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
