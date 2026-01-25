import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../presentation/logic/security_controller.dart';

class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({super.key});

  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  final _answerController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    final controller = context.read<SecurityController>();
    final success = await controller.initiatePinReset(
      _answerController.text.trim(),
    );

    if (mounted && success) {
      // Show Success Dialog or Snackbar before popping
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PIN Reset Successful. Please setup a new PIN.'),
        ),
      );
      Navigator.of(context).pop(); // Go back to Setup or Login
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Secure Recovery')),
      body: Consumer<SecurityController>(
        builder: (context, controller, child) {
          final isLocked = controller.state.status == SecurityStatus.locked;
          final isLoading = controller.state.status == SecurityStatus.loading;
          final errorMsg = controller.state.errorMessage;

          if (isLocked) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_clock, size: 64, color: Colors.orange),
                  const SizedBox(height: 16),
                  Text(
                    'Recovery Locked',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    errorMsg ?? 'Too many attempts.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ).animate().fadeIn();
          }

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Security Challenge',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter the last 4 digits of your ID Card or Passport to reset your PIN.',
                  ),

                  const SizedBox(height: 24),

                  if (errorMsg != null && !isLoading)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        errorMsg,
                        style: TextStyle(color: Colors.red.shade800),
                      ),
                    ).animate().shake(),

                  TextFormField(
                    controller: _answerController,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    decoration: const InputDecoration(
                      labelText: 'Last 4 Digits',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                    validator: (value) {
                      if (value == null || value.length != 4) {
                        return 'Please enter exactly 4 digits';
                      }
                      return null;
                    },
                    enabled: !isLoading,
                  ),

                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Verify Identity'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
