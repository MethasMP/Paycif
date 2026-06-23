import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:frontend/core/l10n/generated/app_localizations.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

import 'package:frontend/core/utils/error_translator.dart';
import 'package:frontend/core/utils/language_notifier.dart';
import 'package:frontend/core/utils/pay_notify.dart';
import 'package:frontend/core/utils/theme_notifier.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  bool _isLoading = false;
  bool _isAppleSignInAvailable = false;
  late final StreamSubscription<AuthState> _authSubscription;
  late final AnimationController _orbController;
  late final AnimationController _pulseController;
  late final AnimationController _gridController;

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
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _gridController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    _orbController.dispose();
    _pulseController.dispose();
    _gridController.dispose();
    super.dispose();
  }

  void _listenToAuthChanges() {
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn) {
        _navigateToMain();
      }
    });
  }

  Future<void> _checkAppleSignInAvailability() async {
    try {
      final isAvailable = await SignInWithApple.isAvailable();
      if (mounted) {
        setState(() => _isAppleSignInAvailable = isAvailable);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isAppleSignInAvailable = Platform.isIOS);
      }
    }
  }

  void _navigateToMain() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.go('/');
      }
    });
  }

  Future<void> _googleSignIn() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final idToken = await _getGoogleIdToken();
      if (idToken != null) {
        await _exchangeTokenWithSupabase(OAuthProvider.google, idToken);
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (error) {
      _handleSignInError(error);
    }
  }

  Future<String?> _getGoogleIdToken() async {
    final webClientId = dotenv.env['GOOGLE_CLIENT_ID_WEB'];
    if (webClientId == null || webClientId.isEmpty) {
      throw Exception('Missing GOOGLE_CLIENT_ID_WEB in .env');
    }

    await GoogleSignIn.instance.initialize(
      clientId: Platform.isIOS ? dotenv.env['GOOGLE_CLIENT_ID_IOS'] : null,
      serverClientId: webClientId,
    );

    final GoogleSignInAccount googleUser =
        await GoogleSignIn.instance.authenticate();
    final googleAuth = googleUser.authentication;
    return googleAuth.idToken;
  }

  Future<void> _appleSignIn() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final idToken = await _getAppleIdToken();
      if (idToken != null) {
        await _exchangeTokenWithSupabase(OAuthProvider.apple, idToken);
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (error) {
      _handleSignInError(error);
    }
  }

  Future<String?> _getAppleIdToken() async {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );
    return credential.identityToken;
  }

  Future<void> _exchangeTokenWithSupabase(
      OAuthProvider provider, String idToken) async {
    await Supabase.instance.client.auth.signInWithIdToken(
      provider: provider,
      idToken: idToken,
    );
  }

  void _handleSignInError(Object error) {
    if (_isCanceledAuthError(error)) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    debugPrint('Sign-in error: $error');
    if (mounted) {
      PayNotify.error(
        context,
        ErrorTranslator.translate(
          AppLocalizations.of(context)!,
          error.toString(),
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  void _showLanguageSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0D1117) : Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04),
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ...LanguageNotifier.supportedLocales.map((locale) {
                  final isSelected =
                      languageNotifier.value.languageCode ==
                          locale.languageCode;
                  final languageName =
                      LanguageNotifier.getLanguageName(locale);
                  final flag = _getLanguageFlag(locale.languageCode);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          languageNotifier.value = locale;
                          Navigator.pop(context);
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDark
                                    ? const Color(0xFF00A896)
                                        .withValues(alpha: 0.12)
                                    : const Color(0xFF00A896)
                                        .withValues(alpha: 0.06))
                                : Colors.transparent,
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF00A896)
                                      .withValues(alpha: 0.4)
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.06)
                                      : Colors.black.withValues(alpha: 0.06)),
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Text(flag,
                                  style: const TextStyle(fontSize: 22)),
                              const SizedBox(width: 14),
                              Text(
                                languageName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                              const Spacer(),
                              if (isSelected)
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF00A896),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check,
                                      size: 14, color: Colors.white),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getLanguageFlag(String languageCode) {
    switch (languageCode) {
      case 'en':
        return '🇺🇸';
      case 'zh':
        return '🇨🇳';
      case 'ja':
        return '🇯🇵';
      case 'ko':
        return '🇰🇷';
      default:
        return '🌐';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final flag = _getLanguageFlag(languageNotifier.value.languageCode);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF050808) : const Color(0xFFF7F8FA),
      body: Stack(
        children: [
          // Animated dot grid background
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _gridController,
              builder: (context, _) => CustomPaint(
                painter: _DotGridPainter(
                  progress: _gridController.value,
                  isDark: isDark,
                ),
              ),
            ),
          ),

          // Floating orbs
          AnimatedBuilder(
            animation: _orbController,
            builder: (context, _) {
              final t = _orbController.value * 2 * math.pi;
              return Stack(
                children: [
                  Positioned(
                    top: size.height * 0.12 + math.sin(t) * 20,
                    right: -40 + math.cos(t * 0.7) * 30,
                    child: _GlowOrb(
                      size: 180,
                      color: isDark
                          ? const Color(0xFF00A896)
                          : const Color(0xFF00A896),
                      opacity: isDark ? 0.08 : 0.06,
                    ),
                  ),
                  Positioned(
                    bottom: size.height * 0.18 + math.cos(t * 0.5) * 15,
                    left: -60 + math.sin(t * 0.8) * 25,
                    child: _GlowOrb(
                      size: 220,
                      color: isDark
                          ? const Color(0xFFF4B41A)
                          : const Color(0xFFF4B41A),
                      opacity: isDark ? 0.06 : 0.05,
                    ),
                  ),
                  Positioned(
                    top: size.height * 0.45 + math.sin(t * 1.2) * 12,
                    right: size.width * 0.15 + math.cos(t * 0.9) * 18,
                    child: _GlowOrb(
                      size: 100,
                      color: isDark
                          ? const Color(0xFF6366F1)
                          : const Color(0xFF818CF8),
                      opacity: isDark ? 0.06 : 0.04,
                    ),
                  ),
                ],
              );
            },
          ),

          // Main content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  // Top bar
                  _buildTopBar(isDark, flag),

                  // Scrollable center content
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 32),
                            _buildHeroBrand(isDark),
                            const SizedBox(height: 48),
                            _buildConnectionVisual(isDark),
                            const SizedBox(height: 48),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Bottom pinned: buttons + footer
                  _buildBottomSection(isDark, l10n),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(bool isDark, String flag) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: _showLanguageSelector,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(flag, style: const TextStyle(fontSize: 15)),
                const SizedBox(width: 6),
                Icon(
                  Icons.unfold_more_rounded,
                  size: 16,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ],
            ),
          ),
        ).animate().fadeIn(duration: 500.ms),
        ValueListenableBuilder<ThemeMode>(
          valueListenable: themeNotifier,
          builder: (context, mode, _) {
            final currentIsDark = mode == ThemeMode.dark ||
                (mode == ThemeMode.system &&
                    MediaQuery.of(context).platformBrightness ==
                        Brightness.dark);
            return GestureDetector(
              onTap: () {
                themeNotifier.value =
                    currentIsDark ? ThemeMode.light : ThemeMode.dark;
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.black.withValues(alpha: 0.03),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                child: Icon(
                  currentIsDark
                      ? Icons.light_mode_rounded
                      : Icons.dark_mode_rounded,
                  size: 18,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            );
          },
        ).animate().fadeIn(duration: 500.ms),
      ],
    );
  }

  Widget _buildHeroBrand(bool isDark) {
    return Column(
      children: [
        // Animated logo ring
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final pulse = _pulseController.value;
            return Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF00A896)
                      .withValues(alpha: 0.06 + pulse * 0.08),
                  width: 2 + pulse * 1.5,
                ),
              ),
              child: Center(
                child: Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF00A896),
                        const Color(0xFF005D53),
                        Color.lerp(
                              const Color(0xFF005D53),
                              const Color(0xFF6366F1),
                              0.3,
                            ) ??
                            const Color(0xFF005D53),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00A896)
                            .withValues(alpha: 0.2 + pulse * 0.1),
                        blurRadius: 30 + pulse * 10,
                        spreadRadius: pulse * 4,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'P',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -1,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        )
            .animate()
            .fadeIn(duration: 800.ms)
            .scale(
                begin: const Offset(0.6, 0.6),
                end: const Offset(1, 1),
                curve: Curves.elasticOut,
                duration: 1000.ms),

        const SizedBox(height: 28),

        // Brand name
        Text(
          'Paycif',
          style: TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            letterSpacing: -1.5,
            height: 1,
          ),
        )
            .animate()
            .fadeIn(delay: 300.ms, duration: 600.ms)
            .slideY(begin: 0.3, end: 0, curve: Curves.easeOutCubic),

        const SizedBox(height: 14),

        // Tagline with gradient
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [
              Color(0xFF00A896),
              Color(0xFFF4B41A),
            ],
          ).createShader(bounds),
          child: const Text(
            'Pay anywhere. Settle instantly.',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        )
            .animate()
            .fadeIn(delay: 500.ms, duration: 600.ms)
            .slideY(begin: 0.2, end: 0),
      ],
    );
  }

  Widget _buildConnectionVisual(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isDark
            ? Colors.white.withValues(alpha: 0.02)
            : Colors.white.withValues(alpha: 0.6),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _FeaturePill(
              icon: Icons.credit_card_rounded,
              label: 'Card',
              isDark: isDark,
              color: const Color(0xFF6366F1),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _FeaturePill(
                icon: Icons.currency_bitcoin_rounded,
                label: 'Crypto',
                isDark: isDark,
                color: const Color(0xFFF4B41A),
              ),
            ),
          ),
          Expanded(
            child: _FeaturePill(
              icon: Icons.qr_code_2_rounded,
              label: 'PromptPay',
              isDark: isDark,
              color: const Color(0xFF00A896),
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 700.ms, duration: 600.ms)
        .slideY(begin: 0.15, end: 0);
  }

  Widget _buildBottomSection(bool isDark, AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_isLoading)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: const Color(0xFF00A896),
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.06),
                ),
              ),
            ),
          )
        else ...[
          _buildSignInButton(
            onPressed: _googleSignIn,
            label: '${l10n.commonLogIn} with Google',
            svgAsset: 'assets/images/google_logo.svg',
            isDark: isDark,
            variant: _ButtonVariant.outlined,
          ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.15, end: 0),
          if (Platform.isIOS || _isAppleSignInAvailable) ...[
            const SizedBox(height: 12),
            _buildSignInButton(
              onPressed: _appleSignIn,
              label: '${l10n.commonLogIn} with Apple',
              svgAsset: 'assets/images/apple_logo.svg',
              isDark: isDark,
              variant: _ButtonVariant.filled,
            ).animate().fadeIn(delay: 900.ms).slideY(begin: 0.15, end: 0),
          ],
        ],
        const SizedBox(height: 20),
        _buildFooter(isDark, l10n),
      ],
    );
  }

  Widget _buildSignInButton({
    required VoidCallback onPressed,
    required String label,
    required String svgAsset,
    required bool isDark,
    required _ButtonVariant variant,
  }) {
    final isFilled = variant == _ButtonVariant.filled;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: isFilled
              ? (isDark ? Colors.white : const Color(0xFF0F172A))
              : (isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: isFilled
              ? null
              : Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.08),
                ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              left: 18,
              top: 0,
              bottom: 0,
              child: Center(
                child: SvgPicture.asset(
                  svgAsset,
                  height: 20,
                  width: 20,
                  colorFilter: isFilled
                      ? ColorFilter.mode(
                          isDark
                              ? const Color(0xFF0F172A)
                              : Colors.white,
                          BlendMode.srcIn,
                        )
                      : null,
                ),
              ),
            ),
            Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isFilled
                      ? (isDark
                          ? const Color(0xFF0F172A)
                          : Colors.white)
                      : (isDark ? Colors.white : const Color(0xFF0F172A)),
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(bool isDark, AppLocalizations l10n) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.8),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'End-to-end encrypted',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white30 : Colors.black26,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black26,
              height: 1.5,
            ),
            children: [
              const TextSpan(text: 'By continuing, you agree to our '),
              TextSpan(
                text: l10n.termsOfService,
                style: TextStyle(
                  color: isDark
                      ? const Color(0xFF00A896).withValues(alpha: 0.7)
                      : const Color(0xFF00A896),
                  fontWeight: FontWeight.w500,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () => context.push('/terms'),
              ),
              const TextSpan(text: ' & '),
              TextSpan(
                text: l10n.privacyPolicy,
                style: TextStyle(
                  color: isDark
                      ? const Color(0xFF00A896).withValues(alpha: 0.7)
                      : const Color(0xFF00A896),
                  fontWeight: FontWeight.w500,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () => context.push('/privacy'),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(delay: 1000.ms);
  }
}

enum _ButtonVariant { outlined, filled }

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const _GlowOrb({
    required this.size,
    required this.color,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final Color color;

  const _FeaturePill({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.12 : 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white54 : Colors.black45,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _DotGridPainter extends CustomPainter {
  final double progress;
  final bool isDark;

  _DotGridPainter({required this.progress, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (isDark ? Colors.white : Colors.black)
          .withValues(alpha: isDark ? 0.04 : 0.03);

    const spacing = 32.0;
    final offset = progress * spacing;

    for (double x = -spacing + offset; x < size.width + spacing; x += spacing) {
      for (double y = -spacing; y < size.height + spacing; y += spacing) {
        final distFromCenter = math.sqrt(
          math.pow(x - size.width / 2, 2) + math.pow(y - size.height / 2, 2),
        );
        final wave = math.sin(distFromCenter * 0.008 + progress * 2 * math.pi);
        final radius = 1.0 + wave * 0.5;
        canvas.drawCircle(Offset(x, y), radius.clamp(0.4, 1.8), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
