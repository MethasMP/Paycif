import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../presentation/logic/security_controller.dart';
import '../../../../utils/error_translator.dart';
import 'package:frontend/l10n/generated/app_localizations.dart';

/// 🚀 World-Class Recovery Screen
/// Designed 20 years ahead: Futuristic KYC Identity Challenge
class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({super.key});

  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  final _answerController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // 🎨 Premium Color Palette
  static const _primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF667EEA), // Indigo
      Color(0xFF764BA2), // Purple
    ],
  );

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    final controller = context.read<SecurityController>();
    final success = await controller.initiatePinReset(
      _answerController.text.trim(),
    );

    if (mounted && success) {
      _showSuccessFeedback();
    }
  }

  void _showSuccessFeedback() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              color: Colors.green,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'Identity Verified',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your PIN has been reset. Please set up a new one.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close sheet
                Navigator.of(
                  context,
                ).pop(); // Back to Lock Screen (which will trigger setup)
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF667EEA),
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Continue to Setup',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF0F0F1A), const Color(0xFF1A1A2E)]
                : [const Color(0xFFF8FAFF), Colors.white],
          ),
        ),
        child: Consumer<SecurityController>(
          builder: (context, controller, child) {
            final isLocked = controller.state.status == SecurityStatus.locked;
            final isLoading = controller.state.status == SecurityStatus.loading;
            final errorMsg = controller.state.errorMessage;

            if (isLocked) return _buildLockedState(isDark, errorMsg);

            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 40),
                      // 🎖️ Identity Badge
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF667EEA).withValues(alpha: 0.1),
                        ),
                        child: const Icon(
                          Icons.badge_rounded,
                          color: Color(0xFF667EEA),
                          size: 40,
                        ),
                      ),

                      const SizedBox(height: 24),
                      const Text(
                        'Identity Challenge',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -1,
                        ),
                      ),

                      const SizedBox(height: 12),
                      Text(
                        'To reset your PIN, please provide the identity anchor linked to your account.',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark ? Colors.white54 : Colors.grey.shade600,
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 48),

                      // 🔬 Futuristic Input Card
                      _buildInputCard(isDark, isLoading),

                      if (errorMsg != null && !isLoading)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            ErrorTranslator.translate(
                              AppLocalizations.of(context)!,
                              errorMsg,
                            ),
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 13,
                            ),
                          ),
                        ),

                      const SizedBox(height: 48),

                      // ⚡ Action Button
                      _buildSubmitButton(isLoading),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInputCard(bool isDark, bool isLoading) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.shade200,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Security Anchor'.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: const Color(0xFF667EEA),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _answerController,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
            ),
            decoration: InputDecoration(
              hintText: '••••',
              hintStyle: TextStyle(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
              ),
              helperText: 'Enter the last 4 digits of your Passport / ID',
              helperStyle: const TextStyle(fontSize: 12),
              border: InputBorder.none,
              counterText: '',
            ),
            validator: (value) {
              if (value == null || value.length != 4) {
                return 'Requires 4 digits';
              }
              return null;
            },
            enabled: !isLoading,
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(bool isLoading) {
    return Container(
      width: double.infinity,
      height: 64,
      decoration: BoxDecoration(
        gradient: _primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667EEA).withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              )
            : const Text(
                'Verify Identity',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildLockedState(bool isDark, String? errorMsg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lock_person_rounded,
              size: 80,
              color: Colors.orangeAccent,
            ),
            const SizedBox(height: 24),
            const Text(
              'Security Lockout',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              errorMsg ??
                  'Identity challenge attempts exhausted. Security protocol active.',
              textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? Colors.white54 : Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
