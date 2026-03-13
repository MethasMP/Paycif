import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import '../../presentation/logic/security_controller.dart';

class BiometricButton extends StatelessWidget {
  final VoidCallback? onSuccess;

  const BiometricButton({super.key, this.onSuccess});

  Future<void> _handleBiometric(BuildContext context) async {
    final controller = context.read<SecurityController>();

    // 1. Check local_auth (Frontend gating)
    final localAuth = LocalAuthentication();
    final canCheck = await localAuth.canCheckBiometrics;

    if (!canCheck) {
      // Show error "Biometrics not available"
      return;
    }

    try {
      final didAuthenticate = await localAuth.authenticate(
        localizedReason: 'Authenticate to confirm identity',
        biometricOnly: true,
      );

      if (didAuthenticate) {
        // 2. Trigger Hardware Key Signature (The real security)
        // The OS might prompt AGAIN for the KeyStore access depending on implementation,
        // but since we just authenticated, usually the session is valid for x seconds
        // OR the key access simply works if "User Presence" was the requirement.
        // If we set "UserAuthenticationRequired" on the key, accessing it will prompt native UI.

        await controller
            .bindDevice(); // Actually we want "Sign" or "Verify Identity" using device.
        // But for this phase, let's assume we are just verifying the binding or "Checking In".

        HapticFeedback.mediumImpact();
        onSuccess?.call();
      }
    } catch (e) {
      HapticFeedback.heavyImpact();
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => _handleBiometric(context),
      icon: const Icon(Icons.fingerprint, size: 48),
      tooltip: 'Biometric Auth',
      style: IconButton.styleFrom(
        foregroundColor: Theme.of(context).primaryColor,
        backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        padding: const EdgeInsets.all(16),
      ),
    );
  }
}
