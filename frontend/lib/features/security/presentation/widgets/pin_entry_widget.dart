import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../presentation/logic/security_controller.dart';

class PinEntryWidget extends StatefulWidget {
  final VoidCallback? onSuccess;
  final bool isSetupMode;

  const PinEntryWidget({super.key, this.onSuccess, this.isSetupMode = false});

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
          await controller.setupPin(_pin);
          if (controller.state.status == SecurityStatus.success) {
            HapticFeedback.mediumImpact();
            widget.onSuccess?.call();
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
      final success = await controller.verifyPin(_pin);
      if (success) {
        HapticFeedback.lightImpact();
        widget.onSuccess?.call();
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
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  errorMsg,
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ).animate().shake(),
              ),

            if (widget.isSetupMode)
              Text(
                _isConfirming ? 'Confirm your PIN' : 'Enter new PIN',
                style: Theme.of(context).textTheme.titleMedium,
              ),

            const SizedBox(height: 24),

            // PIN Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (index) {
                final isFilled = index < _pin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFilled
                        ? Theme.of(context).primaryColor
                        : Colors.grey.shade300,
                    border: isFilled ? null : Border.all(color: Colors.grey),
                  ),
                ).animate(target: isFilled ? 1 : 0).scale(duration: 100.ms);
              }),
            ),

            const Spacer(),

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
    return InkWell(
      onTap: () => _onKeyPress(digit),
      borderRadius: BorderRadius.circular(32),
      child: Container(
        width: 64,
        height: 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey.shade100, // Light background
        ),
        child: Text(
          digit,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
