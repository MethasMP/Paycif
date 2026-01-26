import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../presentation/logic/security_controller.dart';

class PinEntryWidget extends StatefulWidget {
  final ValueChanged<String>? onSuccess;
  final bool isSetupMode;
  final Future<void> Function(String)? onPinConfirmed;
  final Future<bool> Function(String)? onVerify;
  final bool showLabel;

  const PinEntryWidget({
    super.key,
    this.onSuccess,
    this.isSetupMode = false,
    this.onPinConfirmed,
    this.onVerify,
    this.showLabel = true,
  });

  @override
  State<PinEntryWidget> createState() => _PinEntryWidgetState();
}

class _PinEntryWidgetState extends State<PinEntryWidget> {
  String _pin = '';
  // Setup mode specific state
  String? _firstPin; // Confirmation step
  bool _isConfirming = false;

  void _onKeyPress(String key) {
    if (_pin.length >= 6) return; // Max 6 digits

    HapticFeedback.lightImpact();

    setState(() {
      _pin += key;
    });

    if (_pin.length == 6) {
      _onSubmit();
    }
  }

  void _onDelete() {
    if (_pin.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
    });
  }

  void _onClear() {
    setState(() {
      _pin = '';
    });
  }

  Future<void> _onSubmit() async {
    final controller = context.read<SecurityController>();

    if (widget.isSetupMode) {
      if (!_isConfirming) {
        // First entry done, ask for confirmation
        _firstPin = _pin;
        _isConfirming = true;
        _onClear();
        // UI feedback "Confirm PIN" (Handled by header text or similar later)
      } else {
        // Second entry
        if (_pin == _firstPin) {
          // Match!
          if (widget.onPinConfirmed != null) {
            await widget.onPinConfirmed!(_pin);
          } else {
            await controller.setupPin(_pin);
          }
          if (controller.state.status == SecurityStatus.success) {
            HapticFeedback.mediumImpact();
            widget.onSuccess?.call(_pin);
          } else {
            // Failed (e.g. net error)
            HapticFeedback.heavyImpact();
            _resetSetup();
          }
        } else {
          // Mismatch
          HapticFeedback.heavyImpact();
          _resetSetup();
          // Ideally show snackbar "PINs do not match"
        }
      }
    } else {
      // Verify Mode
      HapticFeedback.mediumImpact();
      final success = widget.onVerify != null
          ? await widget.onVerify!(_pin)
          : await controller.verifyPin(_pin);

      if (success) {
        HapticFeedback.lightImpact();
        widget.onSuccess?.call(_pin);
      } else {
        HapticFeedback.heavyImpact();
        _onClear(); // Auto clear on error
      }
    }
  }

  void _resetSetup() {
    setState(() {
      _pin = '';
      _firstPin = null;
      _isConfirming = false;
    });
  }

  String _formatErrorMessage(String error) {
    if (error.contains('FunctionException') ||
        error.contains('500') ||
        error.contains('Identity registration failed')) {
      return 'Security service temporarily unavailable. Please try again.';
    }
    if (error.contains('Incorrect PIN') || error.contains('Invalid PIN')) {
      return 'Incorrect passcode. Please verify and try again.';
    }
    return error;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SecurityController>(
      builder: (context, controller, child) {
        final isLocked = controller.state.status == SecurityStatus.locked;
        final errorMsg = controller.state.errorMessage;

        if (isLocked) {
          return _buildLockedUI(errorMsg ?? 'Account Locked');
        }

        return Column(
          children: [
            // Status / Prompt
            if (errorMsg != null && !isLocked)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.shade100),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lock_reset_rounded,
                        size: 20,
                        color: Colors.red.shade700,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _formatErrorMessage(errorMsg),
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().shake(),

            if (widget.isSetupMode && widget.showLabel)
              Text(
                _isConfirming
                    ? 'Verify Your Security PIN'
                    : 'Set Your Security PIN',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).primaryColor,
                  letterSpacing: 0.5,
                ),
              ),

            const SizedBox(height: 32),

            // PIN Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (index) {
                final isFilled = index < _pin.length;
                return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isFilled
                            ? Theme.of(context).primaryColor
                            : Colors.grey.withValues(alpha: 0.2),
                        border: isFilled
                            ? null
                            : Border.all(
                                color: Colors.grey.withValues(alpha: 0.3),
                              ),
                      ),
                    )
                    .animate(target: isFilled ? 1 : 0)
                    .scale(duration: 200.ms, curve: Curves.elasticOut);
              }),
            ),

            const SizedBox(height: 24),

            // Keypad
            _buildKeypad(),
          ],
        );
      },
    );
  }

  Widget _buildLockedUI(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock, size: 64, color: Colors.orange),
          const SizedBox(height: 16),
          Text(
            'Security Lockout',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildKeypad() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildRow(['1', '2', '3']),
          const SizedBox(height: 24),
          _buildRow(['4', '5', '6']),
          const SizedBox(height: 24),
          _buildRow(['7', '8', '9']),
          const SizedBox(height: 24),
          _buildRow([
            'DOT',
            '0',
            'DEL',
          ]), // DOT is empty or biometric placeholder
        ],
      ),
    );
  }

  Widget _buildRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((key) {
        if (key == 'DOT') return const SizedBox(width: 64, height: 64);
        if (key == 'DEL') {
          return IconButton(
            onPressed: _onDelete,
            icon: const Icon(Icons.backspace_outlined),
            iconSize: 28,
            style: IconButton.styleFrom(fixedSize: const Size(64, 64)),
          );
        }
        return _buildDigitButton(key);
      }).toList(),
    );
  }

  Widget _buildDigitButton(String digit) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onKeyPress(digit),
        borderRadius: BorderRadius.circular(40),
        child: Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white10
                : Colors.grey.shade50,
          ),
          child: Text(
            digit,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w500,
              fontFamily: 'Inter',
            ),
          ),
        ),
      ),
    );
  }
}
