import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:frontend/features/security/presentation/logic/security_controller.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/utils/error_translator.dart';
import 'package:frontend/core/l10n/generated/app_localizations.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/paycif_icon_container.dart';

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
  final ValueChanged<bool>? onStateChanged;
  /// When true, PIN verification also hits the server (Argon2id gate).
  /// Use for payment confirmation; leave false for app unlock.
  final bool serverVerify;

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
    this.onStateChanged,
    this.serverVerify = false,
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
        await Future.delayed(const Duration(milliseconds: 50));
        if (!mounted) return;
        _firstPin = _pin;
        setState(() {
          _isConfirming = true;
          _pin = '';
        });
        widget.onStateChanged?.call(true);
      } else {
        await Future.delayed(const Duration(milliseconds: 50));
        if (!mounted) return;
        if (_pin == _firstPin) {
          HapticFeedback.mediumImpact();
          final pinSnapshot = _pin;
          // Await PIN setup so local token is stored before navigation.
          // Without this, a verifyPin call on the next screen races against
          // the background write and sees no local token or cached key.
          if (widget.onPinConfirmed != null) {
            await widget.onPinConfirmed!(pinSnapshot);
          } else {
            await controller.setupPin(pinSnapshot);
          }
          if (!mounted) return;
          widget.onSuccess?.call(pinSnapshot);
        } else {
          _triggerErrorAnimation();
          _resetSetup();
        }
      }
    } else {
      HapticFeedback.mediumImpact();
      final success = widget.onVerify != null
          ? await widget.onVerify!(_pin)
          : await controller.verifyPin(_pin, serverVerify: widget.serverVerify);

      if (success) {
        HapticFeedback.lightImpact();
        widget.onSuccess?.call(_pin);
      } else {
        if (controller.state.errorMessage?.contains('PIN not setup') == true) {
          if (mounted) {
            context.go('/pin_setup');
            return;
          }
        }
        if (controller.state.errorMessage?.contains('Session expired') == true) {
          if (mounted) {
            context.go('/login');
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
    widget.onStateChanged?.call(false);
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

        final String titleText = widget.isSetupMode
            ? (_isConfirming ? 'Confirm your PIN' : 'Create your PIN')
            : 'Unlock Paycif';

        final String descText = widget.isSetupMode
            ? (_isConfirming
                ? 'Please re-enter your PIN to confirm.'
                : 'Protect your account and approve payments.')
            : 'Verify your identity to continue';

        final IconData headerIcon = widget.isSetupMode
            ? PhosphorIcons.lock
            : PhosphorIcons.shieldCheck;

        final Color descColor = isDark
            ? Colors.white.withValues(alpha: 0.60) // 60-65% Opacity
            : Colors.black.withValues(alpha: 0.60); // 60-65% Opacity

        return SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 🚨 Error Banner
                      if (errorMsg != null && !isLocked)
                        _buildErrorBanner(
                          errorMsg,
                          isDark,
                          AppLocalizations.of(context)!,
                        ),

                      // Top safety padding (const 32 px)
                      // 1. Top space (Proportional spacer)
                      const Spacer(flex: 3),

                      // --- PART 1: Tight Context Block (Header) ---
                      PaycifIconContainer(
                        icon: headerIcon,
                      ).animate().scale(
                        duration: 500.ms,
                        curve: Curves.easeOutBack,
                      ),

                      const SizedBox(height: 16), // Icon -> Title: 16

                      // Title: Semibold, 24 pt, letterSpacing -0.5
                      Text(
                        titleText,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600, // Semibold
                          letterSpacing: -0.5,
                          color: AppTheme.textPrimaryColor(context),
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 12), // Title -> Description: 12

                      // Description: Regular, 17 pt, Line Height 22, 60% Opacity
                      Text(
                        descText,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w400, // Regular
                          height: 22 / 17, // Line Height 22
                          color: descColor,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 32), // Description -> Dots: 32 (Tightened)

                      // PIN Dots
                      RepaintBoundary(
                        child: _buildPinDots(isDark),
                      ),

                      // 2. Fixed connection space between dots and keypad
                      const SizedBox(height: 48),

                      // --- PART 2: Keypad block ---
                      RepaintBoundary(
                        child: _buildKeypadGrid(isDark),
                      ),

                      if (widget.onForgotPin != null) ...[
                        const SizedBox(height: 20),
                        _buildForgotAction(isDark),
                      ],

                      // 3. Bottom space (Proportional spacer)
                      const Spacer(flex: 4),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
    // Brand design system mapping - High Contrast Primary Focus
    final Color filledColor = AppTheme.primaryTeal;
    final Color emptyColor = isDark ? Colors.white30 : Colors.grey.shade400;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (index) {
        final isFilled = index < _pin.length;

        return AnimatedContainer(
          duration: 150.ms,
          margin: const EdgeInsets.symmetric(horizontal: 8),
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
          fontSize: 22,
          fontWeight: FontWeight.w500,
          color: AppTheme.textPrimaryColor(context),
          fontFamily: 'Outfit',
        ),
      ),
    );
  }

  Widget _buildBiometricButton(bool isDark) {
    if (widget.biometricIcon == null || widget.onBiometricPressed == null) {
      return const SizedBox(width: 64, height: 64);
    }
    return KeypadButton(
      isDark: isDark,
      flat: false,
      onTap: widget.onBiometricPressed!,
      child: Icon(
        widget.biometricIcon,
        size: 26,
        color: AppTheme.primaryTeal, // Primary Teal for Focus
      ),
    );
  }

  Widget _buildDeleteButton(bool isDark) {
    return KeypadButton(
      isDark: isDark,
      flat: false,
      onTap: _onDelete,
      child: Icon(
        PhosphorIcons.backspace,
        size: 30, // Larger, more prominent
        color: isDark ? Colors.white : Colors.black87, // High contrast neutral
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
            color: (isDark ? AppTheme.accentGoldDisabled : AppTheme.primaryTeal).withValues(alpha: 0.8), // Use brand colors!
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
  final bool flat;

  const KeypadButton({
    super.key,
    required this.child,
    required this.onTap,
    required this.isDark,
    this.flat = false,
  });

  @override
  State<KeypadButton> createState() => _KeypadButtonState();
}

class _KeypadButtonState extends State<KeypadButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final Color buttonColor = widget.flat
        ? Colors.transparent
        : (widget.isDark ? AppTheme.darkTheme.cardColor : AppTheme.backgroundGrey);
    
    final Color borderColor = widget.isDark 
        ? Colors.white.withValues(alpha: 0.08) 
        : AppTheme.borderGrey;

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
        width: 64,
        height: 64,
        curve: Curves.easeOut,
        transform: Matrix4.diagonal3Values(_isPressed ? 0.96 : 1.0, _isPressed ? 0.96 : 1.0, 1.0),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isPressed
              ? (widget.flat 
                  ? (widget.isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04))
                  : (widget.isDark ? Colors.white.withValues(alpha: 0.15) : Colors.grey.shade300))
              : buttonColor,
          border: widget.flat 
              ? null 
              : Border.all(
                  color: borderColor,
                  width: 1.2,
                ),
          boxShadow: [
            if (!_isPressed && !widget.flat)
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
