import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:frontend/core/l10n/generated/app_localizations.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

import 'package:frontend/core/utils/error_translator.dart';
import 'package:frontend/core/utils/pay_notify.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  bool _isAppleSignInAvailable = false;
  _AuthMethod? _pending;
  late final StreamSubscription<AuthState> _authSubscription;

  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isEmailSending = false;
  bool _showEmailForm = false; // For progressive disclosure

  bool _isCanceledAuthError(Object error) {
    final raw = error.toString().toLowerCase();
    return raw.contains('googlesigninexceptioncode.canceled') ||
        raw.contains('activity is cancelled by the user') ||
        raw.contains('canceled') ||
        raw.contains('user_cancelled') ||
        raw.contains('error code 1001');
  }

  @override
  void initState() {
    super.initState();
    _listenToAuthChanges();
    _checkAppleSignInAvailability();
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    _emailController.dispose();
    super.dispose();
  }

  void _listenToAuthChanges() {
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn) _navigateToMain();
    });
  }

  Future<void> _checkAppleSignInAvailability() async {
    try {
      final isAvailable = await SignInWithApple.isAvailable();
      if (mounted) setState(() => _isAppleSignInAvailable = isAvailable);
    } catch (_) {
      if (mounted) setState(() => _isAppleSignInAvailable = Platform.isIOS);
    }
  }

  void _navigateToMain() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go('/');
    });
  }

  Future<void> _googleSignIn() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _pending = _AuthMethod.google;
    });
    try {
      final idToken = await _getGoogleIdToken();
      if (idToken != null) {
        await _exchangeToken(OAuthProvider.google, idToken);
      } else {
        _resetLoading();
      }
    } catch (e) {
      _handleError(e);
    }
  }

  Future<String?> _getGoogleIdToken() async {
    const webClientIdEnv = String.fromEnvironment('GOOGLE_CLIENT_ID_WEB');
    final webClientId = webClientIdEnv.isNotEmpty 
        ? webClientIdEnv 
        : '985333032452-5d4lf6j704jag2vpjaq8rth6i44vn1cq.apps.googleusercontent.com';

    const iosClientIdEnv = String.fromEnvironment('GOOGLE_CLIENT_ID_IOS');
    final iosClientId = iosClientIdEnv.isNotEmpty 
        ? iosClientIdEnv 
        : '985333032452-vr8cmr5e4emq820n6an2qu4fv4vj1e70.apps.googleusercontent.com';

    await GoogleSignIn.instance.initialize(
      clientId: Platform.isIOS ? iosClientId : null,
      serverClientId: webClientId,
    );
    final account = await GoogleSignIn.instance.authenticate();
    return account.authentication.idToken;
  }

  Future<void> _appleSignIn() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _pending = _AuthMethod.apple;
    });
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final idToken = credential.identityToken;
      if (idToken != null) {
        await _exchangeToken(OAuthProvider.apple, idToken);
      } else {
        _resetLoading();
      }
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> _exchangeToken(OAuthProvider provider, String idToken) async {
    await Supabase.instance.client.auth.signInWithIdToken(
      provider: provider,
      idToken: idToken,
    );
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _isEmailSending = true;
    });
    try {
      await Supabase.instance.client.auth.signInWithOtp(
        email: _emailController.text.trim(),
        emailRedirectTo: 'paycif://login-callback',
      );
      if (mounted) {
        PayNotify.success(
          context,
          AppLocalizations.of(context)!.loginMagicLinkSent,
        );
      }
    } catch (e) {
      _handleError(e);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isEmailSending = false;
        });
      }
    }
  }

  void _resetLoading() {
    if (mounted) {
      setState(() {
        _isLoading = false;
        _pending = null;
      });
    }
  }

  void _handleError(Object error) {
    if (_isCanceledAuthError(error)) {
      _resetLoading();
      return;
    }
    debugPrint('Sign-in error: $error');
    if (mounted) {
      PayNotify.error(
        context,
        ErrorTranslator.translate(
            AppLocalizations.of(context)!, error.toString()),
      );
      _resetLoading();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reduce = MediaQuery.of(context).disableAnimations;

    final heroGradientStart = AppTheme.primaryTeal;
    final heroGradientEnd = AppTheme.primaryTealDark;
    final sheetBg = isDark ? AppTheme.darkSurfaceCard : AppTheme.backgroundWhite;
    final canvasBg = isDark ? AppTheme.darkSurfaceBase : AppTheme.backgroundGrey;
    final textOnHero = Colors.white;
    final textPrimary = AppTheme.textPrimaryColor(context);
    final textSecondary = AppTheme.textSecondaryColor(context);
    final borderDefault = isDark ? AppTheme.darkBorderHairline : AppTheme.borderGrey;
    final primaryTeal = AppTheme.primaryTeal;

    final showApple = Platform.isIOS || _isAppleSignInAvailable;

    return Scaffold(
      backgroundColor: canvasBg,
      body: Stack(
        children: [
          // ── Teal Hero Zone (Top 45%) ───────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.45 + 32, // Add 32 for sheet overlap
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [heroGradientStart, heroGradientEnd],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo Rings
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: CustomPaint(
                          painter: _IntersectingRingsPainter(
                            primaryColor: primaryTeal,
                            secondaryColor: AppTheme.primaryTealDeep,
                          ),
                        ),
                      ),
                    )
                        .animate(target: reduce ? 0 : 1)
                        .fadeIn(duration: 500.ms)
                        .scale(curve: Curves.easeOutQuint),
                    const SizedBox(height: 16),

                    // Brand Name
                    Text(
                      'paycif',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.8,
                        color: textOnHero,
                      ),
                    )
                        .animate(target: reduce ? 0 : 1)
                        .fadeIn(delay: 100.ms, duration: 500.ms),
                    const SizedBox(height: 4),

                    // Tagline
                    Text(
                      l10n.loginHeroTagline,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 16,
                        color: textOnHero.withValues(alpha: 0.9),
                        letterSpacing: -0.1,
                      ),
                    )
                        .animate(target: reduce ? 0 : 1)
                        .fadeIn(delay: 200.ms, duration: 500.ms),
                    
                    // Offset to visually center within the visible teal area
                    SizedBox(height: MediaQuery.of(context).size.height * 0.05),
                  ],
                ),
              ),
            ),
          ),

          // ── Rising White Sheet (Bottom) ────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).size.height * 0.45,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border(top: BorderSide(color: borderDefault)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // ── Social Login ──
                              _AuthButton(
                                label: l10n.loginContinueWithGoogle,
                                svgAsset: 'assets/images/google_logo.svg',
                                isDark: isDark,
                                tintIcon: false,
                                loading: _isLoading && _pending == _AuthMethod.google,
                                disabled: _isLoading,
                                bgColor: isDark ? AppTheme.darkSurfaceCard : AppTheme.backgroundWhite,
                                fgColor: textPrimary,
                                borderColor: Border.all(color: borderDefault),
                                onTap: _googleSignIn,
                              ),
                              if (showApple) ...[
                                const SizedBox(height: 12),
                                _AuthButton(
                                  label: l10n.loginContinueWithApple,
                                  svgAsset: 'assets/images/apple_logo.svg',
                                  isDark: isDark,
                                  tintIcon: true,
                                  loading: _isLoading && _pending == _AuthMethod.apple,
                                  disabled: _isLoading,
                                  bgColor: isDark ? AppTheme.darkSurfaceCard : AppTheme.backgroundWhite,
                                  fgColor: textPrimary,
                                  borderColor: Border.all(color: borderDefault),
                                  onTap: _appleSignIn,
                                ),
                              ],

                              const SizedBox(height: 24),

                              // ── Progressive Disclosure Email ──
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                transitionBuilder: (child, animation) {
                                  return SizeTransition(
                                    sizeFactor: animation,
                                    alignment: Alignment.topCenter,
                                    child: FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    ),
                                  );
                                },
                                child: _showEmailForm
                                    ? Form(
                                        key: _formKey,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            TextFormField(
                                              controller: _emailController,
                                              keyboardType: TextInputType.emailAddress,
                                              style: GoogleFonts.ibmPlexSans(
                                                fontSize: 16,
                                                color: textPrimary,
                                              ),
                                              decoration: InputDecoration(
                                                hintText: l10n.loginEmailHint,
                                                hintStyle: GoogleFonts.ibmPlexSans(
                                                  color: textSecondary,
                                                  fontSize: 16,
                                                ),
                                                contentPadding: const EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 18,
                                                ),
                                                filled: true,
                                                fillColor: isDark ? AppTheme.darkSurfaceSunken : AppTheme.lightSurfaceSunken,
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                  borderSide: BorderSide.none,
                                                ),
                                                enabledBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                  borderSide: BorderSide.none,
                                                ),
                                                focusedBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                  borderSide: BorderSide(color: AppTheme.primaryTealDark, width: 1.5),
                                                ),
                                                errorStyle: GoogleFonts.ibmPlexSans(
                                                  fontSize: 13,
                                                ),
                                              ),
                                              validator: (value) {
                                                if (value == null || value.trim().isEmpty) {
                                                  return l10n.loginEmailRequired;
                                                }
                                                final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                                                if (!emailRegex.hasMatch(value.trim())) {
                                                  return l10n.loginEmailInvalid;
                                                }
                                                return null;
                                              },
                                            ),
                                            const SizedBox(height: 12),
                                            ElevatedButton(
                                              onPressed: _isLoading ? null : _sendOtp,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppTheme.primaryTealDark,
                                                foregroundColor: Colors.white,
                                                minimumSize: const Size(double.infinity, 56),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                elevation: 0,
                                              ),
                                              child: _isEmailSending
                                                  ? const SizedBox(
                                                      width: 22,
                                                      height: 22,
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 2.5,
                                                        valueColor: AlwaysStoppedAnimation(Colors.white),
                                                      ),
                                                    )
                                                  : Text(
                                                      l10n.loginContinueButton,
                                                      style: GoogleFonts.ibmPlexSans(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : Align(
                                        alignment: Alignment.center,
                                        child: TextButton(
                                          onPressed: () {
                                            setState(() {
                                              _showEmailForm = true;
                                            });
                                          },
                                          style: TextButton.styleFrom(
                                            foregroundColor: textSecondary,
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          ),
                                          child: Text(
                                            l10n.loginUseEmailInstead,
                                            style: GoogleFonts.ibmPlexSans(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // ── Footer ──
                      _buildFooter(l10n, textSecondary),
                    ],
                  ),
                ),
              ),
            ),
          )
            .animate(target: reduce ? 0 : 1)
            .slideY(begin: 0.2, end: 0, duration: 600.ms, curve: Curves.easeOutCirc)
            .fadeIn(duration: 400.ms),
        ],
      ),
    );
  }

  Widget _buildFooter(AppLocalizations l10n, Color textSecondary) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(PhosphorIcons.lockSimple, size: 10, color: AppTheme.successGreen),
            ),
            const SizedBox(width: 8),
            Text(
              l10n.loginBankGradeSecurity,
              style: GoogleFonts.ibmPlexSans(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: GoogleFonts.ibmPlexSans(
              fontSize: 11.5,
              color: textSecondary,
              height: 1.5,
            ),
            children: [
              TextSpan(
                text: l10n.termsOfService,
                style: const TextStyle(
                  color: AppTheme.primaryTealDark,
                  fontWeight: FontWeight.w600,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () => context.push('/terms'),
              ),
              const TextSpan(text: ' · '),
              TextSpan(
                text: l10n.privacyPolicy,
                style: const TextStyle(
                  color: AppTheme.primaryTealDark,
                  fontWeight: FontWeight.w600,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () => context.push('/privacy'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _AuthMethod { google, apple }

// ---------------------------------------------------------------------------
// Standard modern auth buttons
// ---------------------------------------------------------------------------

class _AuthButton extends StatefulWidget {
  final String label;
  final String svgAsset;
  final bool isDark;
  final bool tintIcon;
  final bool loading;
  final bool disabled;
  final Color bgColor;
  final Color fgColor;
  final Border? borderColor;
  final VoidCallback onTap;

  const _AuthButton({
    required this.label,
    required this.svgAsset,
    required this.isDark,
    required this.tintIcon,
    required this.loading,
    required this.disabled,
    required this.bgColor,
    required this.fgColor,
    required this.borderColor,
    required this.onTap,
  });

  @override
  State<_AuthButton> createState() => _AuthButtonState();
}

class _AuthButtonState extends State<_AuthButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: !widget.disabled,
      label: widget.label,
      child: AnimatedOpacity(
        duration: 150.ms,
        opacity: widget.disabled && !widget.loading ? 0.5 : 1.0,
        child: GestureDetector(
          onTapDown: widget.disabled
              ? null
              : (_) => setState(() => _pressed = true),
          onTapUp: widget.disabled
              ? null
              : (_) => setState(() => _pressed = false),
          onTapCancel: widget.disabled
              ? null
              : () => setState(() => _pressed = false),
          onTap: widget.disabled ? null : widget.onTap,
          child: AnimatedScale(
            scale: _pressed ? 0.98 : 1.0,
            duration: 120.ms,
            curve: Curves.easeOut,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: widget.bgColor,
                borderRadius: BorderRadius.circular(12),
                border: widget.borderColor,
              ),
              child: Center(
                child: widget.loading
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation(widget.fgColor),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SvgPicture.asset(
                            widget.svgAsset,
                            width: 20,
                            height: 20,
                            colorFilter: widget.tintIcon
                               ? ColorFilter.mode(
                                    widget.fgColor, BlendMode.srcIn)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            widget.label,
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: widget.fgColor,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IntersectingRingsPainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;

  _IntersectingRingsPainter({required this.primaryColor, required this.secondaryColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final paint2 = Paint()
      ..color = secondaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(Offset(size.width * 0.40, size.height * 0.5), size.width * 0.28, paint1);
    canvas.drawCircle(Offset(size.width * 0.60, size.height * 0.5), size.width * 0.28, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
