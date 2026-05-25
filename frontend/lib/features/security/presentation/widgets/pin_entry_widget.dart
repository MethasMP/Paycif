import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../presentation/logic/security_controller.dart';
import '../../../../utils/error_translator.dart';
import 'package:frontend/l10n/generated/app_localizations.dart';

/// 🚀 World-Class PIN Entry Widget
/// Designed 20 years ahead with premium UX/UI patterns
class PinEntryWidget extends StatefulWidget {
  final ValueChanged<String>? onSuccess;
  final bool isSetupMode;
  final Future<void> Function(String)? onPinConfirmed;
  final Future<bool> Function(String)? onVerify;
  final bool showLabel;
  final VoidCallback? onForgotPin;

  const PinEntryWidget({
    super.key,
    this.onSuccess,
    this.isSetupMode = false,
    this.onPinConfirmed,
    this.onVerify,
    this.showLabel = true,
    this.onForgotPin,
  });

  @override
  State<PinEntryWidget> createState() => _PinEntryWidgetState();
}

class _PinEntryWidgetState extends State<PinEntryWidget>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  String? _firstPin;
  bool _isConfirming = false;
  bool _hasError = false;
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onKeyPress(String key) {
    if (_pin.length >= 6) return;

    HapticFeedback.lightImpact();

    setState(() {
      _pin += key;
      _hasError = false;
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

  void _triggerErrorAnimation() {
    setState(() => _hasError = true);
    _shakeController.forward(from: 0);
    HapticFeedback.heavyImpact();
  }

  Future<void> _onSubmit() async {
    final controller = context.read<SecurityController>();

    if (widget.isSetupMode) {
      if (!_isConfirming) {
        _firstPin = _pin;
        _isConfirming = true;
        _onClear();
      } else {
        if (_pin == _firstPin) {
          if (widget.onPinConfirmed != null) {
            await widget.onPinConfirmed!(_pin);
          } else {
            await controller.setupPin(_pin);
          }
          if (controller.state.status == SecurityStatus.success) {
            HapticFeedback.mediumImpact();
            widget.onSuccess?.call(_pin);
          } else {
            _triggerErrorAnimation();
            _resetSetup();
          }
        } else {
          _triggerErrorAnimation();
          _resetSetup();
        }
      }
    } else {
      HapticFeedback.mediumImpact();
      final success = widget.onVerify != null
          ? await widget.onVerify!(_pin)
          : await controller.verifyPin(_pin);

      if (success) {
        HapticFeedback.lightImpact();
        widget.onSuccess?.call(_pin);
      } else {
        _triggerErrorAnimation();
        _onClear();
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

  String _formatErrorMessage(String error, AppLocalizations l10n) {
    return ErrorTranslator.translate(l10n, error);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<SecurityController>(
      builder: (context, controller, child) {
        final isLocked = controller.state.status == SecurityStatus.locked;
        final errorMsg = controller.state.errorMessage;

        if (isLocked) {
          return _buildLockedUI(errorMsg ?? 'Account Locked');
        }

        return Column(
          children: [
            // 🚨 Error Banner
            if (errorMsg != null && !isLocked)
              _buildErrorBanner(
                errorMsg,
                isDark,
                AppLocalizations.of(context)!,
              ),

            // 📝 Setup Context
            if (widget.isSetupMode && widget.showLabel)
              _buildSetupPrompt(isDark),

            // 🏛️ The Silent Sentinel (Clean, Fast)
            _buildUnifiedConsole(isDark),
          ],
        );
      },
    );
  }

  Widget _buildSetupPrompt(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        _isConfirming ? 'Confirm Your PIN' : 'Create Your Security PIN',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white70 : Colors.black54,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildUnifiedConsole(bool isDark) {
    return Column(
      children: [
        if (widget.onForgotPin != null) ...[
          _buildForgotAction(isDark),
          const SizedBox(height: 32),
        ],

        // 🔘 Deep Navy Dots (Static, Instant)
        _buildPinDots(isDark),

        const SizedBox(height: 48),

        // 🔢 Precision Keypad
        _buildKeypadGrid(isDark),
      ],
    ); // No animation - instant render
  }

  Widget _buildKeypadGrid(bool isDark) {
    return Column(
      children: [
        _buildKeypadRow(['1', '2', '3'], isDark),
        const SizedBox(height: 12),
        _buildKeypadRow(['4', '5', '6'], isDark),
        const SizedBox(height: 12),
        _buildKeypadRow(['7', '8', '9'], isDark),
        const SizedBox(height: 12),
        _buildKeypadRow(['EMPTY', '0', 'DEL'], isDark),
      ],
    );
  }

  Widget _buildErrorBanner(
    String errorMsg,
    bool isDark,
    AppLocalizations l10n,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.red.shade900.withValues(alpha: 0.15),
              Colors.red.shade800.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.shade400.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade400.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 20,
                color: Colors.red.shade300,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _formatErrorMessage(errorMsg, l10n),
                style: TextStyle(
                  color: isDark ? Colors.red.shade200 : Colors.red.shade700,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().shake(duration: 400.ms).fadeIn();
  }

  Widget _buildPinDots(bool isDark) {
    const navyColor = Color(0xFF0F172A); // Premium Navy
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (index) {
        final isFilled = index < _pin.length;

        return AnimatedContainer(
          duration: 100.ms,
          margin: const EdgeInsets.symmetric(horizontal: 12),
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _hasError
                ? Colors.red.shade600
                : (isFilled
                      ? (isDark ? Colors.white : navyColor)
                      : (isDark ? Colors.white24 : Colors.grey.shade300)),
          ),
        );
      }),
    );
  }

  Widget _buildKeypadRow(List<String> keys, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((key) {
        if (key == 'EMPTY') {
          return const SizedBox(width: 80, height: 80);
        }
        if (key == 'DEL') {
          return _buildDeleteButton(isDark);
        }
        return _buildDigitButton(key, isDark);
      }).toList(),
    );
  }

  Widget _buildDigitButton(String digit, bool isDark) {
    return GestureDetector(
      onTapDown: (_) => HapticFeedback.lightImpact(),
      onTap: () => _onKeyPress(digit),
      child: Container(
        width: 80,
        height: 80,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.transparent,
        ),
        child: Text(
          digit,
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w400,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontFamily: 'Outfit',
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteButton(bool isDark) {
    return GestureDetector(
      onTap: _onDelete,
      child: Container(
        width: 72,
        height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.grey.shade100,
        ),
        child: Icon(
          Icons.backspace_outlined,
          size: 26,
          color: isDark ? Colors.white54 : Colors.grey.shade600,
        ),
      ),
    );
  }

  Widget _buildForgotAction(bool isDark) {
    return GestureDetector(
      onTap: widget.onForgotPin,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          AppLocalizations.of(context)?.commonForgotPin ?? 'Forgot PIN?',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white60 : Colors.grey.shade500,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  Widget _buildLockedUI(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Colors.orange.shade400, Colors.red.shade400],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withValues(alpha: 0.4),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(
              Icons.lock_clock_rounded,
              size: 48,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Security Lockout',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().scale();
  }
}
