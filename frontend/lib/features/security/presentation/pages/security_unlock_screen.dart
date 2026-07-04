import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:frontend/features/security/presentation/logic/security_controller.dart';
import 'package:frontend/features/security/presentation/widgets/pin_entry_widget.dart';
import 'package:frontend/core/theme/app_theme.dart';

import 'package:frontend/features/security/presentation/pages/recovery_screen.dart';

class SecurityUnlockScreen extends StatefulWidget {
  const SecurityUnlockScreen({super.key});

  @override
  State<SecurityUnlockScreen> createState() => _SecurityUnlockScreenState();
}

class _SecurityUnlockScreenState extends State<SecurityUnlockScreen> {
  bool _isAuthenticating = false;
  Future<BiometricProfile>? _profileFuture;
  late Future<Map<String, dynamic>> _biometricStatusFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = context.read<SecurityController>().getBiometricProfile();
    _biometricStatusFuture = _getBiometricStatus();
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
    final controller = context.read<SecurityController>();
    setState(() => _isAuthenticating = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final biometricEnabled = prefs.getBool('biometric_enabled') ?? false;
      if (!biometricEnabled) {
        return; // Abort if disabled by preference
      }

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
    context.go('/main');
  }

  Future<Map<String, dynamic>> _getBiometricStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final biometricEnabled = prefs.getBool('biometric_enabled') ?? false;
    BiometricProfile? profile;
    if (_profileFuture != null) {
      profile = await _profileFuture;
    }
    return {
      'enabled': biometricEnabled,
      'profile': profile,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkTheme.scaffoldBackgroundColor : Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _biometricStatusFuture,
          builder: (context, snapshot) {
            final data = snapshot.data;
            final enabled = data?['enabled'] ?? false;
            final profile = data?['profile'] as BiometricProfile?;

            return PinEntryWidget(
              onSuccess: (_) => _onUnlockSuccess(),
              onForgotPin: () => _handleForgotPin(context),
              biometricIcon: enabled ? profile?.bioIcon : null,
              onBiometricPressed: enabled ? _tryBiometricUnlock : null,
            );
          },
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
