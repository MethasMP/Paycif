import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/security_controller.dart';
import '../widgets/pin_entry_widget.dart';
import '../../../../screens/main_screen.dart';


class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  bool _isProcessing = false;

  void _onPinSuccess(String pin) async {
    setState(() => _isProcessing = true);
    
    final securityController = context.read<SecurityController>();
    
    try {
      await securityController.setupPin(pin);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save PIN: $e')),
        );
        setState(() => _isProcessing = false);
      }
      return;
    }

    final biometricProfile = await securityController.getBiometricProfile();

    if (!mounted) return;

    if (biometricProfile.availableTypes.isNotEmpty) {
      // Ask user if they want to enable biometrics
      final wantsBiometrics = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          final bioName = biometricProfile.bioName;
          
          return AlertDialog(
            title: Text('Enable $bioName?'),
            content: Text('Use $bioName to unlock Paycif faster and more securely.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Not Now'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('Enable $bioName'),
              ),
            ],
          );
        },
      );

      if (wantsBiometrics == true && mounted) {
        try {
          await securityController.bindDevice();
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to enable biometrics. You can enable it later in Settings.')),
            );
          }
        }
      }
    }

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Icon(
                Icons.lock_outline_rounded,
                size: 64,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 24),
              Text(
                'Create a Secure PIN',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'This PIN will be used to protect your account and approve transactions.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              Expanded(
                child: _isProcessing
                    ? const Center(child: CircularProgressIndicator())
                    : PinEntryWidget(
                        isSetupMode: true,
                        showLabel: true,
                        onSuccess: _onPinSuccess,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
