import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend/core/l10n/generated/app_localizations.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/app_icon.dart';
import 'package:frontend/features/security/data/datasources/app_encryption_service.dart';
import 'dart:async';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:frontend/core/utils/error_translator.dart';

/// 🚀 Bulletproof Minimalist PIN Entry Widget
/// Decoupled, Secure, Accessible, and Masterclass UX
class PinEntryWidget extends StatefulWidget {
  /// Returns an error message if failed, or null if successful.
  final Future<String?> Function(List<int> pin)? onSubmit;
  final bool isSetupMode;
  final VoidCallback? onForgotPin;
  final VoidCallback? onBiometricPressed;
  final IconData? biometricIcon;
  final String? externalErrorMsg;
  final bool isLocked;
  final String lockedMessage;
  final ValueChanged<bool>? onStateChanged;

  const PinEntryWidget({
    super.key,
    this.onSubmit,
    this.isSetupMode = false,
    this.onForgotPin,
    this.onBiometricPressed,
    this.biometricIcon,
    this.externalErrorMsg,
    this.isLocked = false,
    this.lockedMessage = 'Account Locked',
    this.onStateChanged,
  });

  @override
  State<PinEntryWidget> createState() => _PinEntryWidgetState();
}

class _PinEntryWidgetState extends State<PinEntryWidget> {
  final List<int> _pin = [];
  String? _firstPinHash;
  List<int>? _setupSalt;
  bool _isConfirming = false;
  bool _isProcessing = false;
  String? _localErrorMsg;
  
  // Custom animation controllers
  double _shakeOffset = 0.0;
  
  final _appEncryptionService = AppEncryptionService();

  @override
  void dispose() {
    _clearPinBuffer();
    super.dispose();
  }

  void _clearPinBuffer() {
    if (_pin.isNotEmpty) {
      _pin.fillRange(0, _pin.length, 0);
      _pin.clear();
    }
  }

  void _onKeyPress(String key) {
    if (_isProcessing || _pin.length >= 6) return;

    HapticFeedback.lightImpact();

    setState(() {
      _pin.add(int.parse(key));
      _localErrorMsg = null;
    });

    if (_pin.length == 6) {
      _handleSubmit();
    }
  }

  void _onDelete() {
    if (_isProcessing || _pin.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _pin.removeLast();
      _localErrorMsg = null;
    });
  }

  void _triggerErrorShake(String message) {
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _localErrorMsg = message;
      _shakeOffset = 1.0;
    });
    // Simple custom shake without AnimationController memory leaks
    Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() {
          _shakeOffset = 0.0;
          _clearPinBuffer();
        });
      }
    });
  }

  Future<void> _handleSubmit() async {
    setState(() => _isProcessing = true);

    try {
      if (widget.isSetupMode) {
        if (!_isConfirming) {
          // Move heavy crypto to a small delay (or isolate in production) to keep UI buttery
          await Future.microtask(() {});
          if (!mounted) return;
          
          final salt = _appEncryptionService.randomBytes(16);
          _setupSalt = salt;
          _firstPinHash = _appEncryptionService.hashPinForComparison(_pin.join(), salt); // Use string temporarily for internal setup match
          
          setState(() {
            _isConfirming = true;
            _clearPinBuffer();
          });
          widget.onStateChanged?.call(true);
        } else {
          await Future.microtask(() {});
          if (!mounted) return;
          
          final currentHash = _appEncryptionService.hashPinForComparison(_pin.join(), _setupSalt!);
          // Constant time comparison should be used here in production
          if (currentHash == _firstPinHash) {
            HapticFeedback.mediumImpact();
            if (widget.onSubmit != null) {
              final error = await widget.onSubmit!(List.from(_pin));
              if (error != null) {
                _triggerErrorShake(error);
                _resetSetup();
              } else {
                _clearPinBuffer();
              }
            }
          } else {
            _triggerErrorShake('PINs do not match. Try again.');
            _resetSetup();
          }
        }
      } else {
        if (widget.onSubmit != null) {
          final error = await widget.onSubmit!(List.from(_pin));
          if (error != null) {
            _triggerErrorShake(error);
          } else {
            HapticFeedback.mediumImpact();
            _clearPinBuffer();
          }
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _resetSetup() {
    setState(() {
      _firstPinHash = null;
      _setupSalt = null;
      _isConfirming = false;
    });
    widget.onStateChanged?.call(false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.isLocked) {
      return _buildLockedUI(widget.lockedMessage, isDark);
    }

    final String titleText = widget.isSetupMode
        ? (_isConfirming ? 'Confirm PIN' : 'Create PIN')
        : 'Enter PIN';

    final effectiveError = _localErrorMsg ?? widget.externalErrorMsg;

    return SafeArea(
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                children: [
                  const SizedBox(height: 32),

                  // Lock Icon & Header
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryTeal.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: AppIcon(
                        PhosphorIconsFill.shieldCheck,
                        color: AppTheme.primaryTeal,
                        size: AppIconSize.lg,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      titleText,
                      key: ValueKey<String>(titleText),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color: AppTheme.textPrimaryColor(context),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // PIN Indicator Dots
                  Semantics(
                    label: '${_pin.length} out of 6 digits entered',
                    child: RepaintBoundary(
                      child: _buildPinDots(isDark),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Keypad Section (Constrained width for elegance)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: _buildKeypadGrid(isDark),
                  ),

                  const SizedBox(height: 20),

                  // Action Footer
                  if (widget.onForgotPin != null) ...[
                    _buildForgotAction(isDark),
                  ] else ...[
                    const SizedBox(height: 32),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Error Banner Overlay (Prevents Layout Shifts)
          if (effectiveError != null)
            Positioned(
              top: 16,
              left: 24,
              right: 24,
              child: _buildErrorBanner(
                effectiveError,
                isDark,
                AppLocalizations.of(context),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildKeypadGrid(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
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
    AppLocalizations? l10n,
  ) {
    final errorColor = AppTheme.stateError;
    final subtleBg = isDark ? AppTheme.stateErrorSubtleDark : AppTheme.stateErrorSubtleLight;
    final displayMsg = l10n != null ? ErrorTranslator.translate(l10n, errorMsg) : errorMsg;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: subtleBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: errorColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          AppIcon(
            PhosphorIcons.warningCircle,
            size: AppIconSize.sm,
            color: errorColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              displayMsg,
              style: TextStyle(
                color: isDark ? Colors.red.shade200 : AppTheme.stateError,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    ).animate().slideY(begin: -1, end: 0, duration: 300.ms, curve: Curves.easeOutBack).fadeIn();
  }

  Widget _buildPinDots(bool isDark) {
    final Color filledColor = AppTheme.primaryTeal;
    final Color emptyBorderColor = AppTheme.primaryTeal.withValues(alpha: 0.8); // Solid WCAG compliant

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (index) {
        final isFilled = index < _pin.length;
        final hasError = _shakeOffset > 0;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 12),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hasError
                ? AppTheme.stateError
                : (isFilled ? filledColor : Colors.transparent),
            border: Border.all(
              color: hasError 
                ? AppTheme.stateError 
                : (isFilled ? filledColor : emptyBorderColor),
              width: 1.5,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildKeypadRow(List<String> keys, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((key) {
        if (key == 'BIO') {
          return Expanded(child: _buildBiometricButton(isDark));
        }
        if (key == 'DEL') {
          return Expanded(child: _buildDeleteButton(isDark));
        }
        return Expanded(child: _buildDigitButton(key, isDark));
      }).toList(),
    );
  }

  Widget _buildDigitButton(String digit, bool isDark) {
    return KeypadButton(
      isDark: isDark,
      semanticLabel: 'Digit $digit',
      onTap: () => _onKeyPress(digit),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          digit,
          // Limit scaling factor to prevent overflows on giant text sizes
          textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.5),
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimaryColor(context),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }

  Widget _buildBiometricButton(bool isDark) {
    if (widget.biometricIcon == null || widget.onBiometricPressed == null) {
      return const SizedBox.shrink();
    }
    return KeypadButton(
      isDark: isDark,
      semanticLabel: 'Use Biometrics',
      onTap: widget.onBiometricPressed!,
      child: AppIcon(
        widget.biometricIcon!,
        size: AppIconSize.md,
        color: AppTheme.textPrimaryColor(context),
      ),
    );
  }

  Widget _buildDeleteButton(bool isDark) {
    return KeypadButton(
      isDark: isDark,
      semanticLabel: 'Delete digit',
      onTap: _onDelete,
      child: AppIcon(
        PhosphorIconsLight.backspace,
        size: AppIconSize.lg,
        color: AppTheme.textPrimaryColor(context),
      ),
    );
  }

  Widget _buildForgotAction(bool isDark) {
    return Semantics(
      button: true,
      label: 'Forgot PIN',
      child: GestureDetector(
        onTap: widget.onForgotPin,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          alignment: Alignment.center,
          child: Text(
            AppLocalizations.of(context)?.commonForgotPin ?? 'Forgot PIN?',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondaryColor(context),
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLockedUI(String message, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIcon(
              PhosphorIcons.lockSimple,
              color: AppTheme.stateError,
              size: AppIconSize.xl,
            ),
            const SizedBox(height: 24),
            Text(
              'Security Lockout',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
                color: AppTheme.textPrimaryColor(context),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn();
  }
}

/// 🔘 Zero-latency InkResponse keycap for native hardware ripples
class KeypadButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool isDark;
  final String semanticLabel;

  const KeypadButton({
    super.key,
    required this.child,
    required this.onTap,
    required this.isDark,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final keyBgColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.04);

    return Center(
      child: SizedBox(
        width: 72,
        height: 72,
        child: Material(
          color: keyBgColor,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            splashColor: isDark
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.1),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
