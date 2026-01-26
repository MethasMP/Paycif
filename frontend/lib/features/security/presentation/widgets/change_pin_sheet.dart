import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:frontend/l10n/generated/app_localizations.dart';
import '../logic/security_controller.dart';
import 'pin_entry_widget.dart';

class ChangePinSheet extends StatefulWidget {
  const ChangePinSheet({super.key});

  @override
  State<ChangePinSheet> createState() => _ChangePinSheetState();
}

class _ChangePinSheetState extends State<ChangePinSheet> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  String? _oldPin;
  String? _newPin;
  bool _isSuccess = false;
  String? _errorMessage;

  void _onOldPinEntered(String pin) {
    // PinEntryWidget already verified the PIN internally before calling this.
    // We just proceed to the next step.
    if (mounted) {
      setState(() {
        _oldPin = pin;
        _errorMessage = null;
      });
      _nextPage();
    }
  }

  void _onNewPinEntered(String pin) {
    if (pin == _oldPin) {
      setState(() => _errorMessage = 'New PIN cannot be same as old PIN');
      return;
    }
    setState(() {
      _newPin = pin;
      _errorMessage = null;
    });
    _nextPage();
  }

  void _onConfirmNewPinEntered(String pin) async {
    if (pin != _newPin) {
      // Mismatch
      // Shake and clear?
      // We need a way to signal error.
      return;
    }

    final controller = context.read<SecurityController>();
    final success = await controller.changePin(oldPin: _oldPin!, newPin: pin);

    if (success && mounted) {
      setState(() => _isSuccess = true);
      HapticFeedback.lightImpact();
      Future.delayed(1500.ms, () {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: 300.ms,
      curve: Curves.easeInOutCubicEmphasized,
    );
    setState(() => _currentStep++);
  }

  String _getHeaderText(AppLocalizations? l10n) {
    switch (_currentStep) {
      case 0:
        return 'Enter Current PIN';
      case 1:
        return 'Create New PIN';
      case 2:
        return 'Confirm New PIN';
      default:
        return '';
    }
  }

  Color _getHeaderColor(BuildContext context) {
    switch (_currentStep) {
      case 0:
        return Colors.orange;
      case 1:
        return Colors.blue;
      case 2:
        return Colors.green;
      default:
        return Theme.of(context).primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Drag Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Dynamic Header
          AnimatedSwitcher(
            duration: 300.ms,
            child: Text(
              _getHeaderText(l10n),
              key: ValueKey(_currentStep),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: _getHeaderColor(context),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Step Indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (index) {
              final active = index <= _currentStep;
              return AnimatedContainer(
                duration: 300.ms,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: active ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: active
                      ? _getHeaderColor(context)
                      : Colors.grey.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),

          const SizedBox(height: 32),

          // Content
          Expanded(
            child: Stack(
              children: [
                PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    // Step 1: Verify Old PIN
                    PinEntryWidget(onSuccess: _onOldPinEntered),

                    // Step 2: Create New PIN
                    PinEntryWidget(
                      key: const ValueKey('step2'),
                      showLabel: false,
                      onVerify: (pin) async => true,
                      onSuccess: _onNewPinEntered,
                    ),

                    // Step 3: Confirm New PIN
                    PinEntryWidget(
                      key: const ValueKey('step3'),
                      showLabel: false,
                      onVerify: (pin) async => pin == _newPin,
                      onSuccess: _onConfirmNewPinEntered,
                    ),
                  ],
                ),

                // Mismatch / Error Overlay
                if (_errorMessage != null)
                  Positioned(
                    top: 0,
                    left: 24,
                    right: 24,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade100),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().shake().fadeIn(),
                  ),

                // Success Overlay
                if (_isSuccess)
                  Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF10B981),
                            size: 80,
                          ).animate().scale(
                            duration: 400.ms,
                            curve: Curves.elasticOut,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'PIN Updated Successfully',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF10B981),
                                ),
                          ).animate().fadeIn(delay: 200.ms),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
