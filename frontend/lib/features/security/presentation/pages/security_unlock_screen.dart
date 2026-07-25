import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:frontend/features/security/presentation/logic/security_controller.dart';
import 'package:frontend/features/security/presentation/widgets/pin_entry_widget.dart';

class SecurityUnlockScreen extends StatefulWidget {
  const SecurityUnlockScreen({super.key});

  @override
  State<SecurityUnlockScreen> createState() => _SecurityUnlockScreenState();
}

class _SecurityUnlockScreenState extends State<SecurityUnlockScreen> {
  bool _isAuthenticating = false;
  Future<BiometricProfile>? _profileFuture;
  late Future<Map<String, dynamic>> _biometricStatusFuture;
  late AppLifecycleListener _lifecycleListener;
  bool _isSuccessOverlayActive = false;

  @override
  void initState() {
    super.initState();
    _profileFuture = context.read<SecurityController>().getBiometricProfile();
    _biometricStatusFuture = _getBiometricStatus();
    
    // 🚀 Auto-Trigger Biometric on Boot
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryAutoBiometricUnlock();
    });

    // Listen to app lifecycle to re-trigger biometrics when returning from background
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        // Only trigger if we are actively on the lock screen and not already success/authenticating
        if (mounted && !_isAuthenticating && !_isSuccessOverlayActive) {
          _tryAutoBiometricUnlock();
        }
      },
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
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
      if (!biometricEnabled) return;

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
        _onUnlockSuccess();
      }
    } catch (e) {
      debugPrint('Biometric unlock failed: $e');
    } finally {
      if (mounted) setState(() => _isAuthenticating = false);
    }
  }

  Future<String?> _handlePinSubmit(List<int> rawPin) async {
    final controller = context.read<SecurityController>();
    
    // Security layer: We extract the string here, pass it to the controller.
    // In a full production app, the controller would accept List<int>.
    final pinStr = rawPin.join();
    
    // Securely clear the raw array now that we extracted what we need
    rawPin.fillRange(0, rawPin.length, 0);
    rawPin.clear();

    final success = await controller.verifyPin(pinStr, serverVerify: false);
    
    if (success) {
      _onUnlockSuccess();
      return null;
    } else {
      if (controller.state.errorMessage?.contains('PIN not setup') == true) {
        if (mounted) context.go('/pin_setup');
        return null;
      }
      return controller.state.errorMessage ?? 'Incorrect PIN';
    }
  }

  void _onUnlockSuccess() {
    setState(() => _isSuccessOverlayActive = true);
    context.read<SecurityController>().recordBiometricVerificationSuccess();
    
    // Use GoRouter replacement rather than magic Future.delayed times
    // We wrapped the screen in AbsorbPointer below when _isSuccessOverlayActive is true
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

  void _handleForgotPin() {
    // Decoupled routing logic, perfectly compliant with GoRouter
    context.push('/recovery');
  }

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      absorbing: _isSuccessOverlayActive,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Redundant dark theme check removed
        body: FutureBuilder<Map<String, dynamic>>(
          future: _biometricStatusFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox.shrink(); // Prevent biometric button pop-in jank
            }

            final data = snapshot.data;
            final enabled = data?['enabled'] ?? false;
            final profile = data?['profile'] as BiometricProfile?;
            final controller = context.watch<SecurityController>();
            final isLocked = controller.state.status == SecurityStatus.locked;
            final errorMsg = controller.state.errorMessage;

            return PinEntryWidget(
              onSubmit: _handlePinSubmit,
              onForgotPin: _handleForgotPin,
              biometricIcon: enabled ? profile?.bioIcon : null,
              onBiometricPressed: enabled ? _tryBiometricUnlock : null,
              isLocked: isLocked,
              lockedMessage: errorMsg ?? 'Account Locked',
            );
          },
        ),
      ),
    );
  }
}
