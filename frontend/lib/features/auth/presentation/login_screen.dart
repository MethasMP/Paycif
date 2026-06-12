import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:frontend/core/l10n/generated/app_localizations.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:frontend/core/utils/error_translator.dart';
import 'package:frontend/core/utils/language_notifier.dart';
import 'package:frontend/core/utils/pay_notify.dart';
import 'package:frontend/core/utils/theme_notifier.dart';
import 'package:frontend/features/profile/presentation/privacy_policy_screen.dart';
import 'splash_screen.dart' as import_splash;
import 'package:frontend/features/profile/presentation/terms_of_service_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  bool _isAppleSignInAvailable = false;
  late final StreamSubscription<AuthState> _authSubscription;

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
    super.dispose();
  }

  void _listenToAuthChanges() {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
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
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const import_splash.SplashScreen(),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
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
        if (mounted) {
          setState(() => _isLoading = false);
        }
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

    final GoogleSignInAccount googleUser = await GoogleSignIn.instance.authenticate();
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
        if (mounted) {
          setState(() => _isLoading = false);
        }
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

  Future<void> _exchangeTokenWithSupabase(OAuthProvider provider, String idToken) async {
    await Supabase.instance.client.auth.signInWithIdToken(
      provider: provider,
      idToken: idToken,
    );
  }

  void _handleSignInError(Object error) {
    if (_isCanceledAuthError(error)) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
            color: isDark ? const Color(0xFF141A18) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                spreadRadius: 2,
              )
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Select Language / เลือกภาษา',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppTheme.textPrimaryColor(context),
                  ),
                ),
                const SizedBox(height: 20),
                ...LanguageNotifier.supportedLocales.map((locale) {
                  final isSelected = languageNotifier.value.languageCode == locale.languageCode;
                  final languageName = LanguageNotifier.getLanguageName(locale);
                  
                  final flag = _getLanguageFlag(locale.languageCode);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () {
                        languageNotifier.value = locale;
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark ? AppTheme.primaryTeal.withValues(alpha: 0.2) : AppTheme.primaryTealLight)
                              : Colors.transparent,
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.primaryTeal
                                : (isDark ? Colors.white12 : Colors.black12),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Text(
                              flag,
                              style: const TextStyle(fontSize: 22),
                            ),
                            const SizedBox(width: 14),
                            Text(
                              languageName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                color: isSelected
                                    ? (isDark ? const Color(0xFF2BBF9E) : AppTheme.primaryTeal)
                                    : (isDark ? Colors.white70 : AppTheme.textPrimaryColor(context)),
                              ),
                            ),
                            const Spacer(),
                            if (isSelected)
                              Icon(
                                Icons.check_circle,
                                color: isDark ? const Color(0xFF2BBF9E) : AppTheme.primaryTeal,
                              ),
                          ],
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

  Widget _buildVisualMockup(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141A18).withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : AppTheme.primaryTeal).withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2623) : const Color(0xFFF0F7F4),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  PhosphorIcons.creditCard,
                  color: isDark ? const Color(0xFF2BBF9E) : AppTheme.primaryTeal,
                  size: 24,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Card / Pay',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : AppTheme.textPrimaryColor(context),
                ),
              ),
            ],
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      PhosphorIcons.shieldCheck,
                      color: AppTheme.accentGold,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Secure Direct',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppTheme.accentGoldDisabled : AppTheme.accentGold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 2,
                      color: isDark ? Colors.white24 : Colors.black12,
                    ),
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryTeal,
                        shape: BoxShape.circle,
                        border: Border.all(color: isDark ? const Color(0xFF0B0F0E) : Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.arrow_forward,
                        size: 12,
                        color: Colors.white,
                      ),
                    ).animate(onPlay: (controller) => controller.repeat())
                      .shimmer(duration: 1500.ms, delay: 500.ms),
                  ],
                ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2623) : const Color(0xFFF0F7F4),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  PhosphorIcons.qrCode,
                  color: isDark ? const Color(0xFF2BBF9E) : AppTheme.primaryTeal,
                  size: 24,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'PromptPay QR',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : AppTheme.textPrimaryColor(context),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 500.ms, duration: 600.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut);
  }

  List<Widget> _buildBackgroundGlow(bool isDark) {
    return [
      Positioned(
        top: -100,
        left: -100,
        child: Container(
          width: 300,
          height: 300,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark
                ? AppTheme.primaryTeal.withValues(alpha: 0.12)
                : AppTheme.primaryTealLight.withValues(alpha: 0.7),
          ),
        ),
      ).animate().fadeIn(duration: 1000.ms),
      Positioned(
        bottom: -80,
        right: -80,
        child: Container(
          width: 300,
          height: 300,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark
                ? AppTheme.accentGold.withValues(alpha: 0.08)
                : AppTheme.accentGoldDisabled.withValues(alpha: 0.25),
          ),
        ),
      ).animate().fadeIn(duration: 1000.ms),
    ];
  }

  Widget _buildTopUtilityBar(bool isDark, String flag) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildLanguageSelectorPill(isDark, flag),
        _buildThemeSwitcher(),
      ],
    );
  }

  Widget _buildLanguageSelectorPill(bool isDark, String flag) {
    return InkWell(
      onTap: _showLanguageSelector,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(
            color: isDark ? Colors.white24 : Colors.black12,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(20),
          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              LanguageNotifier.getLanguageName(languageNotifier.value).split(' ').first,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : AppTheme.textPrimaryColor(context),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 16,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeSwitcher() {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, _) {
        final currentIsDark = mode == ThemeMode.dark ||
            (mode == ThemeMode.system &&
                MediaQuery.of(context).platformBrightness == Brightness.dark);
        return IconButton(
          icon: Icon(
            currentIsDark ? PhosphorIcons.sun : PhosphorIcons.moon,
            color: currentIsDark ? AppTheme.accentGoldDisabled : AppTheme.primaryTeal,
            size: 24,
          ),
          onPressed: () {
            themeNotifier.value = currentIsDark ? ThemeMode.light : ThemeMode.dark;
          },
        );
      },
    );
  }

  Widget _buildLogoHeader(bool isDark, AppLocalizations l10n) {
    return Column(
      children: [
        _buildLogoEmblem(isDark),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Paycif',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppTheme.textPrimaryColor(context),
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppTheme.accentGold,
                shape: BoxShape.circle,
              ),
            ).animate().scale(delay: 500.ms, duration: 300.ms),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Secure. Simple. Global.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: isDark ? Colors.white54 : const Color(0xFF666664),
            letterSpacing: 2.5,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.15, end: 0);
  }

  Widget _buildLogoEmblem(bool isDark) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.transparent,
            border: Border.all(
              color: isDark
                  ? const Color(0xFF2BBF9E).withValues(alpha: 0.15)
                  : AppTheme.primaryTeal.withValues(alpha: 0.08),
              width: 4,
            ),
          ),
        ).animate().scale(duration: 800.ms, curve: Curves.easeOutBack),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF2BBF9E), AppTheme.primaryTeal]
                  : [AppTheme.primaryTeal, AppTheme.primaryTealDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryTeal.withValues(alpha: isDark ? 0.3 : 0.15),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(
            PhosphorIcons.shield,
            size: 38,
            color: isDark ? const Color(0xFF0B0F0E) : Colors.white,
          ),
        ).animate()
          .fadeIn(duration: 600.ms)
          .scale(delay: 150.ms, duration: 650.ms, curve: Curves.elasticOut),
        Positioned(
          bottom: 2,
          right: 2,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: const Color(0xFF0FBC5C),
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? const Color(0xFF0B0F0E) : Colors.white,
                width: 2.5,
              ),
            ),
          ).animate(onPlay: (c) => c.repeat())
            .shimmer(duration: 2000.ms, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildButtonsAndFooter(bool isDark, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isLoading)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: CircularProgressIndicator(
                color: isDark ? const Color(0xFF2BBF9E) : AppTheme.accentGold,
              ),
            ),
          )
        else ...[
          _buildGoogleButton(isDark, l10n),
          if (Platform.isIOS || _isAppleSignInAvailable) ...[
            const SizedBox(height: 14),
            _buildAppleButton(isDark, l10n),
          ],
        ],
        const SizedBox(height: 24),
        _buildFooter(isDark, l10n),
      ],
    );
  }

  Widget _buildSocialButton({
    required VoidCallback onPressed,
    required Color backgroundColor,
    required Color foregroundColor,
    required String label,
    required String svgAsset,
    Color? iconColor,
    BorderSide? border,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 52,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: border ?? BorderSide.none,
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SvgPicture.asset(
                svgAsset,
                height: 22,
                width: 22,
                colorFilter: iconColor != null
                    ? ColorFilter.mode(iconColor, BlendMode.srcIn)
                    : null,
              ),
            ),
            Center(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleButton(bool isDark, AppLocalizations l10n) {
    return _buildSocialButton(
      onPressed: _googleSignIn,
      backgroundColor: isDark ? const Color(0xFF141A18) : Colors.white,
      foregroundColor: isDark ? Colors.white70 : AppTheme.textPrimaryColor(context),
      label: "${l10n.commonLogIn} with Google",
      svgAsset: 'assets/images/google_logo.svg',
      border: BorderSide(
        color: isDark ? Colors.white12 : AppTheme.borderGrey,
        width: 1.5,
      ),
    ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.2, end: 0, curve: Curves.easeOutQuad);
  }

  Widget _buildAppleButton(bool isDark, AppLocalizations l10n) {
    return _buildSocialButton(
      onPressed: _appleSignIn,
      backgroundColor: isDark ? Colors.white : const Color(0xFF000000),
      foregroundColor: isDark ? const Color(0xFF000000) : Colors.white,
      label: "${l10n.commonLogIn} with Apple",
      svgAsset: 'assets/images/apple_logo.svg',
      iconColor: isDark ? const Color(0xFF000000) : Colors.white,
    ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.2, end: 0, curve: Curves.easeOutQuad);
  }

  Widget _buildFooter(bool isDark, AppLocalizations l10n) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              PhosphorIcons.lockSimple,
              size: 14,
              color: isDark ? Colors.white38 : AppTheme.textPlaceholder,
            ),
            const SizedBox(width: 6),
            Text(
              'Safe & Secure 256-bit SSL Connection',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white38 : AppTheme.textPlaceholder,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white30 : AppTheme.textPlaceholder,
              height: 1.4,
            ),
            children: [
              const TextSpan(text: 'By signing in, you agree to our '),
              TextSpan(
                text: l10n.termsOfService,
                style: TextStyle(
                  color: isDark ? const Color(0xFF2BBF9E) : AppTheme.primaryTeal,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TermsOfServiceScreen(),
                      ),
                    );
                  },
              ),
              const TextSpan(text: ' & '),
              TextSpan(
                text: l10n.privacyPolicy,
                style: TextStyle(
                  color: isDark ? const Color(0xFF2BBF9E) : AppTheme.primaryTeal,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PrivacyPolicyScreen(),
                      ),
                    );
                  },
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(delay: 900.ms);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final flag = _getLanguageFlag(languageNotifier.value.languageCode);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F0E) : const Color(0xFFFBFBFA),
      body: Stack(
        children: [
          ..._buildBackgroundGlow(isDark),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  _buildTopUtilityBar(isDark, flag),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 24),
                          _buildLogoHeader(isDark, l10n),
                          _buildVisualMockup(isDark),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: _buildButtonsAndFooter(isDark, l10n),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
