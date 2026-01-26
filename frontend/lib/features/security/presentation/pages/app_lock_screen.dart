import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../screens/main_screen.dart';
import '../logic/security_controller.dart';
import '../widgets/pin_entry_widget.dart';
import '../../../../l10n/generated/app_localizations.dart';
import 'recovery_screen.dart';

class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final LocalAuthentication _auth = LocalAuthentication();
  bool _isLoading = true;
  bool _isSetupMode = false;
  BiometricType _biometricType = BiometricType.fingerprint;

  @override
  void initState() {
    super.initState();
    _checkSecurityStatus();
  }

  Future<void> _checkSecurityStatus() async {
    final controller = context.read<SecurityController>();
    final hasPin = await controller.hasPin();

    if (mounted) {
      setState(() {
        _isSetupMode = !hasPin;
        _isLoading = false;
      });
    }

    if (hasPin) {
      await _determineBiometricType();

      // 🛡️ World-Class UX: Biometric-First Auto-Trigger
      // Add a small delay to ensure UI is mounted and Navigation animations finished.
      // This prevents the OS prompt from failing due to race conditions.
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _tryBiometricUnlock(isAutoTrigger: true);
      });
    }
  }

  Future<void> _determineBiometricType() async {
    final available = await _auth.getAvailableBiometrics();
    if (mounted) {
      setState(() {
        if (available.contains(BiometricType.face)) {
          _biometricType = BiometricType.face;
        } else if (available.contains(BiometricType.iris)) {
          _biometricType = BiometricType.iris;
        } else {
          _biometricType = BiometricType.fingerprint;
        }
      });
    }
  }

  Future<void> _tryBiometricUnlock({bool isAutoTrigger = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // Force reload from disk
    final bool isBiometricEnabled = prefs.getBool('biometric_enabled') ?? false;

    if (!isBiometricEnabled) {
      return;
    }

    try {
      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) return;

      // 🧠 Tactile Feedback: Acknowledge the start of scanning
      if (!isAutoTrigger) HapticFeedback.mediumImpact();

      final authenticated = await _auth.authenticate(
        localizedReason: 'Secure access to your Paycif Wallet',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (authenticated) {
        HapticFeedback.lightImpact();
        _unlockApp();
      } else {
        // User Canceled or didn't match.
        // Fallback: Just stay on PIN pad.
        debugPrint('🛡️ Biometric authentication unsuccessful or canceled.');
      }
    } on PlatformException catch (e) {
      debugPrint('⚠️ Biometric error: $e');
      // Fallback: PIN pad is already visible.
    }
  }

  void _unlockApp() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainScreen()),
    );
  }

  void _onPinSuccess(String pin) {
    _unlockApp();
  }

  void _onForgotPin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RecoveryScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
            ),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  const SizedBox(height: 48),
                  // ... UI children ...
                  // Logo / Branding
                  Icon(
                    _isSetupMode
                        ? Icons.security_rounded
                        : (_biometricType == BiometricType.face
                              ? Icons.face_unlock_rounded
                              : Icons.lock_outline_rounded),
                    size: 56,
                    color: _isSetupMode
                        ? Theme.of(context).primaryColor
                        : Theme.of(context).primaryColor.withValues(alpha: 0.8),
                  ).animate().scale(
                    duration: 400.ms,
                    curve: Curves.easeOutBack,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isSetupMode ? 'Protect Your Account' : 'Paycif Locked',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_isSetupMode)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 48),
                      child: Text(
                        'Create a secure 6-digit passcode to shield your wallet and authorize sensitive transactions.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ),
                  const SizedBox(height: 40),

                  // PIN Entry
                  PinEntryWidget(
                    onSuccess: _onPinSuccess,
                    isSetupMode: _isSetupMode,
                  ),

                  const SizedBox(height: 24),

                  // Manual Biometric Trigger
                  if (!_isSetupMode)
                    FutureBuilder<bool>(
                      future: _auth.canCheckBiometrics,
                      builder: (context, snapshot) {
                        if (snapshot.data == true) {
                          return IconButton(
                            onPressed: _tryBiometricUnlock,
                            icon: Icon(
                              _biometricType == BiometricType.face
                                  ? Icons.face_retouching_natural_rounded
                                  : Icons.fingerprint_rounded,
                              size: 52,
                            ),
                            style: IconButton.styleFrom(
                              foregroundColor: Theme.of(context).primaryColor,
                              padding: const EdgeInsets.all(12),
                            ),
                          ).animate().fadeIn(delay: 400.ms).scale();
                        }
                        return const SizedBox.shrink();
                      },
                    ),

                  const Spacer(),

                  // Forgot PIN (Only show if not in setup mode)
                  if (!_isSetupMode)
                    TextButton(
                      onPressed: _onForgotPin,
                      child: Text(l10n?.commonForgotPin ?? 'Forgot PIN?'),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
