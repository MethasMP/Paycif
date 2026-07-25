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

import 'package:frontend/core/network/api_service.dart';
import 'package:frontend/core/utils/error_translator.dart';
import 'package:frontend/core/utils/app_notification_toast.dart';
import 'package:frontend/core/widgets/app_icon.dart';
import 'package:frontend/core/widgets/paycif_button.dart';

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
      if (mounted && GoRouterState.of(context).matchedLocation == '/login') {
        context.go('/');
      }
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
    final webClientId = ApiService.requireEnv(
      const String.fromEnvironment('GOOGLE_CLIENT_ID_WEB'),
      'GOOGLE_CLIENT_ID_WEB',
      debugFallback: '985333032452-5d4lf6j704jag2vpjaq8rth6i44vn1cq.apps.googleusercontent.com',
    );

    final iosClientId = ApiService.requireEnv(
      const String.fromEnvironment('GOOGLE_CLIENT_ID_IOS'),
      'GOOGLE_CLIENT_ID_IOS',
      debugFallback: '985333032452-vr8cmr5e4emq820n6an2qu4fv4vj1e70.apps.googleusercontent.com',
    );

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
        AppNotificationToast.success(
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
      AppNotificationToast.error(
        context,
        ErrorTranslator.translate(
            AppLocalizations.of(context)!, error.toString()),
      );
      _resetLoading();
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final reduce = MediaQuery.of(context).disableAnimations;

    final textPrimary = AppTheme.textPrimaryColor(context);
    final textSecondary = AppTheme.textSecondaryColor(context);
    final borderDefault =
        isDark ? AppTheme.darkBorderHairline : AppTheme.lightBorderHairline;
    final surfaceCard =
        isDark ? AppTheme.darkSurfaceCard : AppTheme.lightSurfaceCard;

    // Apple-HIG: the ink-filled button inverts between themes.
    final inkFill = textPrimary;
    final onInkFill = isDark ? AppTheme.darkTextOnDark : AppTheme.lightTextOnDark;

    final showApple = Platform.isIOS || _isAppleSignInAvailable;

    return Scaffold(
      // Ink-on-paper canvas — the brand carries warmth through type and the
      // mark, not a drenched hero.
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Brand block — upper third, generous air ──
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 40),
                              SizedBox(
                                width: 44,
                                height: 44,
                                child: CustomPaint(
                                  painter: _IntersectingRingsPainter(
                                    primaryColor: textPrimary,
                                    secondaryColor: AppTheme.primaryColor(context),
                                  ),
                                ),
                              )
                                  .animate(target: reduce ? 0 : 1)
                                  .fadeIn(duration: 500.ms)
                                  .scale(
                                    begin: const Offset(0.9, 0.9),
                                    curve: Curves.easeOutQuint,
                                  ),
                              const SizedBox(height: 20),
                              Text(
                                'paycif',
                                style: GoogleFonts.inter(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.8,
                                  color: textPrimary,
                                ),
                              )
                                  .animate(target: reduce ? 0 : 1)
                                  .fadeIn(delay: 100.ms, duration: 500.ms),
                              const SizedBox(height: 8),
                              Text(
                                l10n.loginHeroTagline,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: textSecondary,
                                  fontWeight: FontWeight.w400,
                                ),
                              )
                                  .animate(target: reduce ? 0 : 1)
                                  .fadeIn(delay: 200.ms, duration: 500.ms),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),

                        // ── Auth block — thumb zone ──
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Apple first on devices that support it (HIG prominence),
                            // ink-filled so the primary path wears the strongest weight.
                            if (showApple) ...[
                              _AuthButton(
                                label: l10n.loginContinueWithApple,
                                svgAsset: 'assets/images/apple_logo.svg',
                                tintIcon: true,
                                loading: _isLoading && _pending == _AuthMethod.apple,
                                disabled: _isLoading,
                                bgColor: inkFill,
                                fgColor: onInkFill,
                                border: null,
                                onTap: _appleSignIn,
                              ),
                              const SizedBox(height: 12),
                            ],
                            _AuthButton(
                              label: l10n.loginContinueWithGoogle,
                              svgAsset: 'assets/images/google_logo.svg',
                              tintIcon: false,
                              loading: _isLoading && _pending == _AuthMethod.google,
                              disabled: _isLoading,
                              bgColor: surfaceCard,
                              fgColor: textPrimary,
                              border: Border.all(color: borderDefault),
                              onTap: _googleSignIn,
                            ),
                            const SizedBox(height: 20),

                            // ── Progressive-disclosure email ──
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              transitionBuilder: (child, animation) {
                                return SizeTransition(
                                  sizeFactor: animation,
                                  alignment: Alignment.topCenter,
                                  child: FadeTransition(opacity: animation, child: child),
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
                                            autofocus: true,
                                            style: GoogleFonts.inter(
                                              fontSize: 16,
                                              color: textPrimary,
                                            ),
                                            decoration: InputDecoration(
                                              hintText: l10n.loginEmailHint,
                                              hintStyle: GoogleFonts.inter(
                                                color: textSecondary,
                                                fontSize: 16,
                                              ),
                                              contentPadding: const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 18,
                                              ),
                                              filled: true,
                                              fillColor: isDark
                                                  ? AppTheme.darkSurfaceSunken
                                                  : AppTheme.lightSurfaceSunken,
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
                                                borderSide: BorderSide(
                                                  color: AppTheme.primaryColor(context),
                                                  width: 1.5,
                                                ),
                                              ),
                                              errorStyle: GoogleFonts.inter(fontSize: 13),
                                            ),
                                            validator: (value) {
                                              if (value == null || value.trim().isEmpty) {
                                                return l10n.loginEmailRequired;
                                              }
                                              if (value.trim().contains('@') == false) {
                                                return l10n.loginEmailInvalid;
                                              }
                                              return null;
                                            },
                                          ),
                                          const SizedBox(height: 12),
                                          PaycifButton(
                                            text: l10n.loginContinueButton,
                                            isLoading: _isEmailSending,
                                            onPressed: _isLoading ? null : _sendOtp,
                                            variant: PaycifButtonVariant.primary,
                                            size: PaycifButtonSize.lg,
                                          ),
                                        ],
                                      ),
                                    )
                                  : Align(
                                      alignment: Alignment.center,
                                      child: TextButton(
                                        onPressed: () {
                                          setState(() => _showEmailForm = true);
                                        },
                                        style: TextButton.styleFrom(
                                          foregroundColor: textSecondary,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                        ),
                                        child: Text(
                                          l10n.loginUseEmailInstead,
                                          style: GoogleFonts.inter(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 24),

                            // ── Footer ──
                            _buildFooter(l10n, textSecondary),
                          ],
                        )
                            .animate(target: reduce ? 0 : 1)
                            .slideY(
                              begin: 0.06,
                              end: 0,
                              duration: 500.ms,
                              curve: Curves.easeOutQuint,
                            )
                            .fadeIn(duration: 400.ms),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFooter(AppLocalizations l10n, Color textSecondary) {
    final linkColor = AppTheme.primaryColor(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Quiet ink trust mark — Signal Green stays success-only.
            AppIcon(PhosphorIcons.lockSimple, size: AppIconSize.xs, color: textSecondary),
            const SizedBox(width: 8),
            Text(
              l10n.loginBankGradeSecurity,
              style: GoogleFonts.inter(
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
            style: GoogleFonts.inter(
              fontSize: 11.5,
              color: textSecondary,
              height: 1.5,
            ),
            children: [
              TextSpan(
                text: l10n.termsOfService,
                style: TextStyle(
                  color: linkColor,
                  fontWeight: FontWeight.w600,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () => context.push('/terms'),
              ),
              const TextSpan(text: ' · '),
              TextSpan(
                text: l10n.privacyPolicy,
                style: TextStyle(
                  color: linkColor,
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
// Standard modern auth buttons — pill silhouette, matching PaycifButton
// ---------------------------------------------------------------------------

class _AuthButton extends StatefulWidget {
  final String label;
  final String svgAsset;
  final bool tintIcon;
  final bool loading;
  final bool disabled;
  final Color bgColor;
  final Color fgColor;
  final Border? border;
  final VoidCallback onTap;

  const _AuthButton({
    required this.label,
    required this.svgAsset,
    required this.tintIcon,
    required this.loading,
    required this.disabled,
    required this.bgColor,
    required this.fgColor,
    required this.border,
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
                borderRadius: BorderRadius.circular(9999),
                border: widget.border,
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
                            style: GoogleFonts.inter(
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
