import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:frontend/l10n/generated/app_localizations.dart';
import '../utils/error_translator.dart';
import '../utils/pay_notify.dart';

import 'package:flutter_animate/flutter_animate.dart';
import 'dart:async';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'splash_screen.dart' as import_splash;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  late final StreamSubscription<AuthState> _authSubscription;

  bool _isCanceledAuthError(Object error) {
    final raw = error.toString().toLowerCase();
    return raw.contains('googlesigninexceptioncode.canceled') ||
        raw.contains('activity is cancelled by the user') ||
        raw.contains('canceled');
  }

  @override
  void initState() {
    super.initState();
    _listenToAuthChanges();
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
      final webClientId = dotenv.env['GOOGLE_CLIENT_ID_WEB'];
      if (webClientId == null || webClientId.isEmpty) {
        throw Exception('Missing GOOGLE_CLIENT_ID_WEB in .env');
      }

      // 1. Native Google Sign In
      // IMPORTANT: On Android, clientId MUST be null — the native client ID is
      // read from google-services.json automatically.
      // On iOS, clientId must be the iOS-type Client ID.
      await GoogleSignIn.instance.initialize(
        clientId: Platform.isIOS ? dotenv.env['GOOGLE_CLIENT_ID_IOS'] : null,
        serverClientId: webClientId,
      );

      final GoogleSignInAccount googleUser =
          await GoogleSignIn.instance.authenticate();

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception(
          'No Google ID token. Verify GOOGLE_CLIENT_ID_WEB setup.',
        );
      }

      // 2. Exchange with Supabase
      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );

      // Navigation is handled by the _authStream listener.
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }
      debugPrint('Google Sign-In error: $error');
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
    } catch (error) {
      if (_isCanceledAuthError(error)) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }
      debugPrint('Google Sign-In error: $error');
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
  }

  Future<void> _appleSignInMock() async {
    final l10n = AppLocalizations.of(context)!;
    PayNotify.info(context, l10n.loginAppleComingSoon);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              // Paycif Logo (Shield + Check for Safety)
              Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).primaryColor,
                          Theme.of(context).primaryColorDark,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).primaryColor.withValues(alpha: 0.4),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.shield_outlined, // Emphasize Security ("Paycif")
                      size: 50,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 800.ms)
                  .scale(
                    delay: 200.ms,
                    duration: 600.ms,
                    curve: Curves.elasticOut,
                  ),

              const SizedBox(height: 32),

              // Brand Title
              Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Paycif',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.displayLarge
                            ?.copyWith(
                              color: Theme.of(context).textTheme.displayLarge?.color,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -1.0,
                            ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor, // Gold Dot
                          shape: BoxShape.circle,
                        ),
                      ).animate().scale(delay: 800.ms, duration: 300.ms),
                    ],
                  )
                  .animate()
                  .fadeIn(duration: 600.ms, delay: 400.ms)
                  .slideY(
                    begin: 0.2,
                    end: 0,
                    duration: 600.ms,
                    curve: Curves.easeOut,
                  ),

              const SizedBox(height: 12),

              // Tagline
              Text(
                    'Secure. Simple. Global.', // Keep for style or localize? I'll keep for brand flavor as per user preference.
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.54),
                      letterSpacing: 2.0,
                      fontSize: 16,
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 600.ms, delay: 600.ms)
                  .slideY(
                    begin: 0.2,
                    end: 0,
                    duration: 600.ms,
                    curve: Curves.easeOut,
                  ),

              const Spacer(),

              if (_isLoading)
                Center(
                  child: CircularProgressIndicator(
                    color: Theme.of(context).primaryColor,
                  ),
                )
              else ...[
                // Google Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: Semantics(
                    label: 'Log in with Google',
                    button: true,
                    child: ElevatedButton(
                      onPressed: _googleSignIn,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/google_logo.png',
                            height: 20, // Standard size
                            width: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "${l10n.commonLogIn} with Google",
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(duration: 600.ms, delay: 800.ms)
                    .slideY(
                      begin: 0.2,
                      end: 0,
                      duration: 600.ms,
                      curve: Curves.easeOutQuad,
                    ),

                const SizedBox(height: 16),

                // Apple Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: Semantics(
                    label: 'Log in with Apple',
                    button: true,
                    child: OutlinedButton(
                      onPressed: _appleSignInMock,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.apple,
                            size: 24, // Standard size
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "${l10n.commonLogIn} with Apple",
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(duration: 600.ms, delay: 900.ms)
                    .slideY(
                      begin: 0.2,
                      end: 0,
                      duration: 600.ms,
                      curve: Curves.easeOutQuad,
                    ),
              ],

              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
