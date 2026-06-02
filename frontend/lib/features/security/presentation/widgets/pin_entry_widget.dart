import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../pages/pin_setup_screen.dart';
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
  final VoidCallback? onBiometricPressed;
  final IconData? biometricIcon;

  const PinEntryWidget({
    super.key,
    this.onSuccess,
    this.isSetupMode = false,
    this.onPinConfirmed,
    this.onVerify,
    this.showLabel = true,
    this.onForgotPin,
    this.onBiometricPressed,
    this.biometricIcon,
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
    _shakeController.forward(from: 0).then((_) {
      if (mounted) {
        setState(() {
          _hasError = false;
          _pin = '';
        });
      }
    });
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
        if (controller.state.errorMessage?.contains('PIN not setup') == true) {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const PinSetupScreen()),
            );
            return;
          }
        }
        _triggerErrorAnimation();
      }
    }
  }

  void _resetSetup() {
    setState(() {
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
        // 🔘 Deep Gold/Accent Dots with pulse/error feedback (isolated repaint layer)
        RepaintBoundary(
          child: _buildPinDots(isDark),
        ),

        const SizedBox(height: 48),

        // 🔢 Precision Keypad (isolated repaint layer)
        RepaintBoundary(
          child: _buildKeypadGrid(isDark),
        ),

        if (widget.onForgotPin != null) ...[
          const SizedBox(height: 32),
          _buildForgotAction(isDark),
        ],
      ],
    );
  }

  Widget _buildKeypadGrid(bool isDark) {
    return Column(
      children: [
        _buildKeypadRow(['1', '2', '3'], isDark),
        const SizedBox(height: 16),
        _buildKeypadRow(['4', '5', '6'], isDark),
        const SizedBox(height: 16),
        _buildKeypadRow(['7', '8', '9'], isDark),
        const SizedBox(height: 16),
        _buildKeypadRow(['BIO', '0', 'DEL'], isDark),
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
                PhosphorIcons.warningCircle,
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
    // Brand design system mapping
    final Color filledColor = isDark ? const Color(0xFFFAC775) : const Color(0xFFEF9F27); // Gold Accent
    final Color emptyColor = isDark ? Colors.white24 : Colors.grey.shade300;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (index) {
        final isFilled = index < _pin.length;

        return AnimatedContainer(
          duration: 150.ms,
          margin: const EdgeInsets.symmetric(horizontal: 12),
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _hasError
                ? Colors.red.shade600
                : (isFilled ? filledColor : emptyColor),
            boxShadow: [
              if (isFilled && !_hasError)
                BoxShadow(
                  color: filledColor.withValues(alpha: 0.3),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
            ],
          ),
        );
      }),
    ).animate(target: _hasError ? 1 : 0).shake(duration: 400.ms);
  }

  Widget _buildKeypadRow(List<String> keys, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((key) {
        if (key == 'BIO') {
          return _buildBiometricButton(isDark);
        }
        if (key == 'DEL') {
          return _buildDeleteButton(isDark);
        }
        return _buildDigitButton(key, isDark);
      }).toList(),
    );
  }

  Widget _buildDigitButton(String digit, bool isDark) {
    return KeypadButton(
      isDark: isDark,
      onTap: () => _onKeyPress(digit),
      child: Text(
        digit,
        style: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w500,
          color: isDark ? const Color(0xFFF5F5F5) : const Color(0xFF111111),
          fontFamily: 'Outfit',
        ),
      ),
    );
  }

  Widget _buildBiometricButton(bool isDark) {
    if (widget.biometricIcon == null || widget.onBiometricPressed == null) {
      return const SizedBox(width: 80, height: 80);
    }
    return KeypadButton(
      isDark: isDark,
      onTap: widget.onBiometricPressed!,
      child: Icon(
        widget.biometricIcon,
        size: 28,
        color: isDark ? const Color(0xFFFAC775) : const Color(0xFF0F6E56), // Gold for dark, Teal for light
      ),
    );
  }

  Widget _buildDeleteButton(bool isDark) {
    return KeypadButton(
      isDark: isDark,
      onTap: _onDelete,
      child: Icon(
        PhosphorIcons.backspace,
        size: 26,
        color: isDark ? Colors.white70 : Colors.grey.shade700,
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
            color: isDark ? const Color(0xFFFAC775).withValues(alpha: 0.8) : const Color(0xFF0F6E56), // Use brand colors!
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
            child: Icon(
              PhosphorIcons.lockSimple,
              size: 48,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Security Lockout',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
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

/// 🔘 Tactile circular keycap with hover/press scale animation
class KeypadButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool isDark;

  const KeypadButton({
    super.key,
    required this.child,
    required this.onTap,
    required this.isDark,
  });

  @override
  State<KeypadButton> createState() => _KeypadButtonState();
}

class _KeypadButtonState extends State<KeypadButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final Color buttonColor = widget.isDark 
        ? const Color(0xFF141A18) 
        : const Color(0xFFF7F7F5);
    final Color borderColor = widget.isDark 
        ? Colors.white.withValues(alpha: 0.08) 
        : const Color(0xFFE5E5E3);

    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        setState(() => _isPressed = true);
      },
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 80,
        height: 80,
        curve: Curves.easeOut,
        transform: Matrix4.diagonal3Values(_isPressed ? 0.92 : 1.0, _isPressed ? 0.92 : 1.0, 1.0),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isPressed
              ? (widget.isDark ? Colors.white.withValues(alpha: 0.15) : Colors.grey.shade300)
              : buttonColor,
          border: Border.all(
            color: borderColor,
            width: 1.2,
          ),
          boxShadow: [
            if (!_isPressed)
              BoxShadow(
                color: widget.isDark ? Colors.black.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}
