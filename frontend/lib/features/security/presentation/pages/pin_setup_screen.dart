import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/features/security/presentation/logic/security_controller.dart';
import 'package:frontend/features/security/presentation/widgets/pin_entry_widget.dart';
import 'package:go_router/go_router.dart';



import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  late Future<BiometricProfile> _biometricProfileFuture;

  @override
  void initState() {
    super.initState();
    _biometricProfileFuture =
        context.read<SecurityController>().getBiometricProfile();
  }

  void _onPinSuccess(String pin) async {
    final securityController = context.read<SecurityController>();

    // Biometric profile is already pre-fetched — this resolves instantly.
    final biometricProfile = await _biometricProfileFuture;
    if (!mounted) return;

    if (biometricProfile.availableTypes.isNotEmpty) {
      final bioName = biometricProfile.bioName;
      final wantsBiometrics = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text('Enable $bioName?'),
          content: Text('Use $bioName to unlock Paycif faster and more securely.'),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Not Now'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Enable $bioName'),
            ),
          ],
        ),
      );

      if (wantsBiometrics == true) {
        await _enableBiometrics(securityController);
      }
    }

    if (mounted) {
      context.go('/main');
    }
  }

  Future<void> _enableBiometrics(SecurityController securityController) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('biometric_enabled', true);

      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user != null) {
        await supabase
            .from('profiles')
            .update({
              'biometric_enabled': true,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', user.id);
      }

      await securityController.bindDevice();
    } catch (e) {
      debugPrint('⚠️ Biometric setup failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: PinEntryWidget(
          isSetupMode: true,
          onSubmit: (pinList) async {
            final pin = pinList.join();
            final securityController = context.read<SecurityController>();
            final success = await securityController.setupPin(pin);
            if (success) {
              if (mounted) _onPinSuccess(pin);
              return null;
            } else {
              return securityController.state.errorMessage ?? 'Failed to setup PIN';
            }
          },
        ),
      ),
    );
  }
}
