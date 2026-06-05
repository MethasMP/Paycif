import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

import '../../presentation/logic/security_controller.dart';
import '../../../../utils/error_translator.dart';
import 'package:flutter/foundation.dart';
import 'package:frontend/l10n/generated/app_localizations.dart';
import 'package:frontend/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RECOVERY SCREEN
// Design Philosophy:
//   • "Moment of Anxiety" — User lost their PIN. They're stressed. Every pixel
//     must communicate: calm, safety, and one simple path forward.
//   • Radical Focus — One field, one action. No noise.
//   • Kinetic Trust — The 4 ID digits animate in with a micro-glow on each tap,
//     providing instant sensory feedback that turns anxiety into confidence.
//   • Contextual Warmth — Teal brand color used as a reassurance signal,
//     not as a warning. Gold only for the CTA to signal "this matters."
// ─────────────────────────────────────────────────────────────────────────────

class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({super.key});

  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen>
    with SingleTickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
  String _digits = '';
  bool _hasError = false;
  bool _isLoading = false;
  late AnimationController _shakeController;

  // ── Brand tokens ───────────────────────────────────────────────────────────
  Color get _teal => Theme.of(context).brightness == Brightness.dark ? AppTheme.darkTheme.primaryColor : AppTheme.primaryTeal;
  Color get _tealDark => AppTheme.primaryTealDark;
  Color get _darkBg => AppTheme.darkTheme.scaffoldBackgroundColor;
  Color get _darkSurface => AppTheme.darkTheme.cardColor;
  Color get _lightBg => AppTheme.lightTheme.scaffoldBackgroundColor;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  // ── Input Handlers ─────────────────────────────────────────────────────────
  void _appendDigit(String d) {
    if (_digits.length >= 4 || _isLoading) return;
    HapticFeedback.lightImpact();
    setState(() {
      _digits += d;
      _hasError = false;
    });
    if (_digits.length == 4) _submit();
  }

  void _deleteDigit() {
    if (_digits.isEmpty || _isLoading) return;
    HapticFeedback.selectionClick();
    setState(() => _digits = _digits.substring(0, _digits.length - 1));
  }

  Future<void> _submit() async {
    if (_digits.length != 4) return;
    setState(() => _isLoading = true);

    final controller = context.read<SecurityController>();
    final success = await controller.initiatePinReset(_digits);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      _showVerifiedSheet();
    } else {
      _triggerError();
    }

  }

  void _triggerError() {
    HapticFeedback.heavyImpact();
    _shakeController.forward(from: 0).then((_) {
      if (mounted) {
        setState(() {
          _hasError = false;
          _digits = '';
        });
      }
    });
    setState(() => _hasError = true);
  }

  // ── Success Bottom Sheet ───────────────────────────────────────────────────
  void _showVerifiedSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _VerifiedSheet(isDark: isDark),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? _darkBg : _lightBg,
      body: Consumer<SecurityController>(
        builder: (context, ctrl, _) {
          final isLocked = ctrl.state.status == SecurityStatus.locked;
          if (isLocked) return _LockedState(isDark: isDark, message: ctrl.state.errorMessage);

          return Stack(
            children: [
              // ── Ambient Glow (Dark mode only) ─────────────────────────────
              if (isDark) _buildAmbientGlow(),

              // ── Content ───────────────────────────────────────────────────
              SafeArea(
                child: Column(
                  children: [
                    _buildTopBar(isDark),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 16),
                              _buildHeader(isDark),
                              const SizedBox(height: 48),
                              _buildIdCard(isDark, ctrl),
                              const SizedBox(height: 40),
                              _buildKeypad(isDark),
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Ambient Background Glow ────────────────────────────────────────────────
  Widget _buildAmbientGlow() {
    return Positioned(
      top: -120,
      left: -80,
      child: Container(
        width: 340,
        height: 340,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              _teal.withValues(alpha: 0.12),
              _teal.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top Navigation Bar ─────────────────────────────────────────────────────
  Widget _buildTopBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          // Back button — subtle, not distracting
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: AnimatedContainer(
              duration: 150.ms,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                PhosphorIcons.caretLeft,
                size: 20,
                color: isDark ? const Color(0xFFF5F5F5) : const Color(0xFF111111),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header: Reassurance Copy ───────────────────────────────────────────────
  Widget _buildHeader(bool isDark) {
    final primary = isDark ? _teal : _tealDark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon badge — soft, not alarming
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(PhosphorIcons.shieldCheck, color: primary, size: 26),
        )
        .animate()
        .scale(begin: const Offset(0.7, 0.7), duration: 500.ms, curve: Curves.elasticOut),

        const SizedBox(height: 20),

        // Headline — calm and direct
        Text(
          'Verify\nYour Identity',
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.8,
            height: 1.1,
            color: isDark ? const Color(0xFFF5F5F5) : const Color(0xFF111111),
          ),
        )
        .animate()
        .fadeIn(delay: 80.ms, duration: 400.ms)
        .slideY(begin: 0.15, end: 0, duration: 400.ms, curve: Curves.easeOut),

        const SizedBox(height: 12),

        // Subtitle — contextual guidance, not legalese
        Text(
          'Enter the last 4 digits of your\nPassport or National ID.',
          style: TextStyle(
            fontSize: 15,
            height: 1.55,
            color: isDark ? Colors.white.withValues(alpha: 0.45) : const Color(0xFF666664),
          ),
        )
        .animate()
        .fadeIn(delay: 160.ms, duration: 400.ms),
      ],
    );
  }

  // ── ID Input Card ──────────────────────────────────────────────────────────
  Widget _buildIdCard(bool isDark, SecurityController ctrl) {
    final primary = isDark ? _teal : _tealDark;
    final errorMsg = ctrl.state.errorMessage;
    final showError = (ctrl.state.status == SecurityStatus.error) && errorMsg != null && !_isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Text(
          'LAST 4 DIGITS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.4,
            color: primary.withValues(alpha: 0.7),
          ),
        ),

        const SizedBox(height: 10),

        // The input card — glassmorphic feel in dark, clean card in light
        AnimatedBuilder(
          animation: _shakeController,
          builder: (context, child) {
            final shake = _hasError
                ? (4 * (_shakeController.value < 0.5
                    ? 2 * _shakeController.value - 1
                    : 2 * (1 - _shakeController.value) - 1))
                : 0.0;
            return Transform.translate(
              offset: Offset(shake * 8, 0),
              child: child,
            );
          },
          child: AnimatedContainer(
            duration: 200.ms,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
            decoration: BoxDecoration(
              color: isDark
                  ? _darkSurface
                  : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _hasError
                    ? Colors.red.withValues(alpha: 0.5)
                    : (_digits.isNotEmpty
                        ? primary.withValues(alpha: 0.35)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.07)
                            : const Color(0xFFE5E5E3))),
                width: 1.5,
              ),
              boxShadow: [
                if (!isDark)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                if (_digits.isNotEmpty && !_hasError)
                  BoxShadow(
                    color: primary.withValues(alpha: isDark ? 0.12 : 0.08),
                    blurRadius: 20,
                    spreadRadius: 0,
                  ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(4, (i) => _buildDigitSlot(i, isDark, primary)),
            ),
          ),
        ),

        // Error message — compact, non-alarming
        AnimatedSize(
          duration: 250.ms,
          curve: Curves.easeOut,
          child: showError
              ? Padding(
                  padding: const EdgeInsets.only(top: 10, left: 4),
                  child: Row(
                    children: [
                      Icon(PhosphorIcons.warningCircle,
                          size: 14,
                          color: isDark ? Colors.red.shade300 : Colors.red.shade600),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          ErrorTranslator.translate(
                            AppLocalizations.of(context)!,
                            errorMsg,
                          ),
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? Colors.red.shade300 : Colors.red.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    )
    .animate()
    .fadeIn(delay: 240.ms, duration: 400.ms)
    .slideY(begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOut);
  }

  // ── Single digit slot ──────────────────────────────────────────────────────
  Widget _buildDigitSlot(int index, bool isDark, Color primary) {
    final isFilled = index < _digits.length;
    final isActive = index == _digits.length; // next slot to be filled

    return AnimatedContainer(
      duration: 120.ms,
      width: 56,
      height: 64,
      decoration: BoxDecoration(
        color: isFilled
            ? primary.withValues(alpha: isDark ? 0.18 : 0.1)
            : (isDark
                ? Colors.white.withValues(alpha: 0.04)
                : const Color(0xFFF7F7F5)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _hasError
              ? Colors.red.withValues(alpha: 0.4)
              : (isFilled
                  ? primary.withValues(alpha: 0.5)
                  : (isActive
                      ? primary.withValues(alpha: 0.25)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : const Color(0xFFE5E5E3)))),
          width: isFilled ? 1.5 : 1.0,
        ),
      ),
      child: Center(
        child: isFilled
            ? Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _hasError
                      ? Colors.red.shade400
                      : primary,
                  boxShadow: [
                    if (!_hasError)
                      BoxShadow(
                        color: primary.withValues(alpha: 0.5),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                  ],
                ),
              )
            : (isActive
                ? (() {
                    final container = Container(
                      width: 2,
                      height: 22,
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
                      return container;
                    }
                    return container
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .fadeIn(duration: 500.ms)
                        .then()
                        .fadeOut(duration: 500.ms);
                  })()
                : null),
      ),
    );
  }

  // ── Numeric Keypad ─────────────────────────────────────────────────────────
  Widget _buildKeypad(bool isDark) {
    return Column(
      children: [
        _buildKeypadRow(['1', '2', '3'], isDark),
        const SizedBox(height: 12),
        _buildKeypadRow(['4', '5', '6'], isDark),
        const SizedBox(height: 12),
        _buildKeypadRow(['7', '8', '9'], isDark),
        const SizedBox(height: 12),
        _buildKeypadRow(['', '0', 'DEL'], isDark),
      ],
    )
    .animate()
    .fadeIn(delay: 320.ms, duration: 400.ms)
    .slideY(begin: 0.08, end: 0, duration: 400.ms, curve: Curves.easeOut);
  }

  Widget _buildKeypadRow(List<String> keys, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((k) {
        if (k == '') return const SizedBox(width: 80, height: 80);
        if (k == 'DEL') {
          return _RecoveryKeypadButton(
            isDark: isDark,
            onTap: _deleteDigit,
            child: Icon(
              PhosphorIcons.backspace,
              size: 24,
              color: isDark ? Colors.white54 : const Color(0xFF666664),
            ),
          );
        }
        return _RecoveryKeypadButton(
          isDark: isDark,
          onTap: () => _appendDigit(k),
          child: Text(
            k,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.5,
              color: isDark ? const Color(0xFFF5F5F5) : const Color(0xFF111111),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// KEYPAD BUTTON — Tactile, Scale-down on press
// ─────────────────────────────────────────────────────────────────────────────
class _RecoveryKeypadButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool isDark;

  const _RecoveryKeypadButton({
    required this.child,
    required this.onTap,
    required this.isDark,
  });

  @override
  State<_RecoveryKeypadButton> createState() => _RecoveryKeypadButtonState();
}

class _RecoveryKeypadButtonState extends State<_RecoveryKeypadButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        width: 80,
        height: 80,
        curve: Curves.easeOut,
        transform: _pressed
            ? (Matrix4.diagonal3Values(0.90, 0.90, 1.0))
            : Matrix4.identity(),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _pressed
              ? (widget.isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.07))
              : Colors.transparent,
        ),
        child: Center(child: widget.child),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOCKED STATE — Empathetic, not punitive
// ─────────────────────────────────────────────────────────────────────────────
class _LockedState extends StatelessWidget {
  final bool isDark;
  final String? message;

  const _LockedState({required this.isDark, this.message});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // Back button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.07)
                        : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    PhosphorIcons.caretLeft,
                    size: 20,
                    color: isDark ? const Color(0xFFF5F5F5) : const Color(0xFF111111),
                  ),
                ),
              ),
            ),
          ),

          // Spacer
          const Spacer(),

          // Padlock illustration
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFF79009).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              PhosphorIcons.lockSimple,
              size: 36,
              color: Color(0xFFF79009),
            ),
          )
          .animate()
          .scale(begin: const Offset(0.6, 0.6), duration: 600.ms, curve: Curves.elasticOut),

          const SizedBox(height: 24),

          // Headline
          Text(
            'Account Locked',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
              color: isDark ? const Color(0xFFF5F5F5) : const Color(0xFF111111),
            ),
          )
          .animate()
          .fadeIn(delay: 100.ms, duration: 400.ms),

          const SizedBox(height: 12),

          // Calm message
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 44),
            child: Text(
              message?.isNotEmpty == true
                  ? message!
                  : 'Too many attempts. Please contact support or try again later.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.6,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.45)
                    : const Color(0xFF666664),
              ),
            ),
          )
          .animate()
          .fadeIn(delay: 200.ms, duration: 400.ms),

          const SizedBox(height: 40),

          // Contact support CTA — secondary, not aggressive
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: isDark ? const Color(0xFF2BBF9E) : const Color(0xFF0F6E56),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
              ),
              child: const Text(
                'Back to Login',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
          )
          .animate()
          .fadeIn(delay: 320.ms, duration: 400.ms),

          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VERIFIED BOTTOM SHEET — Moment of delight, not ceremony
// ─────────────────────────────────────────────────────────────────────────────
class _VerifiedSheet extends StatelessWidget {
  final bool isDark;

  const _VerifiedSheet({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF141A18).withValues(alpha: 0.98)
              : Colors.white.withValues(alpha: 0.98),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
            ),
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          28,
          28,
          28,
          28 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            const SizedBox(height: 28),

            // Success icon
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF2BBF9E).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                PhosphorIcons.checkCircle,
                size: 36,
                color: Color(0xFF2BBF9E),
              ),
            )
            .animate()
            .scale(begin: const Offset(0.5, 0.5), duration: 500.ms, curve: Curves.elasticOut),

            const SizedBox(height: 20),

            Text(
              'Identity Verified',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.4,
                color: isDark ? const Color(0xFFF5F5F5) : const Color(0xFF111111),
              ),
            )
            .animate()
            .fadeIn(delay: 120.ms, duration: 350.ms),

            const SizedBox(height: 10),

            Text(
              "You're all set. Let's create\na new PIN for your account.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.55,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.45)
                    : const Color(0xFF666664),
              ),
            )
            .animate()
            .fadeIn(delay: 200.ms, duration: 350.ms),

            const SizedBox(height: 32),

            // CTA — gold, prominent
            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close sheet
                  Navigator.of(context).pop(); // Back (triggers PIN setup flow)
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark
                      ? AppTheme.accentGoldDisabled
                      : AppTheme.accentGold,
                  foregroundColor: AppTheme.accentGoldDark,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Set New PIN',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            )
            .animate()
            .fadeIn(delay: 280.ms, duration: 350.ms)
            .slideY(begin: 0.1, end: 0, duration: 350.ms, curve: Curves.easeOut),
          ],
        ),
      ),
    );
  }
}
