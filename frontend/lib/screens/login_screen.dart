import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:frontend/l10n/generated/app_localizations.dart';
import '../utils/error_translator.dart';
import '../utils/pay_notify.dart';

import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  late final Stream<AuthState> _authStream;

  @override
  void initState() {
    super.initState();
    _authStream = Supabase.instance.client.auth.onAuthStateChange;
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    _authStream.listen((data) {
      if (data.event == AuthChangeEvent.signedIn) {
        _navigateToMain();
      }
    });
  }

  void _navigateToMain() {
    // Guard against calling setState or Navigator during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Guard against redundant navigation
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const MainScreen(),
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
      // 1. Native Google Sign In
      final GoogleSignIn googleSignIn = GoogleSignIn(
        // iOS Client ID
        clientId: dotenv.env['GOOGLE_CLIENT_ID_IOS'],
        // Web Client ID (Server) - Helps with ID Token audience validation
        serverClientId: dotenv.env['GOOGLE_CLIENT_ID_WEB'],
        scopes: ['email', 'profile'],
      );

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        // User canceled
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw 'No ID Token found.';
      }

      // 2. Exchange with Supabase
      // Note: We intentionally DO NOT pass a nonce here to avoid mismatches
      // with the native Google ID Token.
      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      // Navigation is handled by the _authStream listener.
    } catch (error) {
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
      backgroundColor: const Color(0xFF1A1F71), // Premium Deep Blue
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
                          const Color(0xFFF59E0B), // Gold
                          const Color(0xFFD97706), // Darker Gold
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.shield_outlined, // Emphasize Security ("Paycif")
                      size: 50,
                      color: Colors.white,
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
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.0,
                            ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B), // Gold Dot
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
                      color: Colors.white.withValues(alpha: 0.7),
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
                const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFF59E0B), // Gold
                  ),
                )
              else ...[
                // Google Button
                Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ElevatedButton(
                        onPressed: _googleSignIn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black, // Ripple color
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
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
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.normal,
                                    color: Colors.black, // Forced Black
                                  ),
                            ),
                          ],
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
                Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ElevatedButton(
                        onPressed: _appleSignInMock,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.apple,
                              color: Colors.black,
                              size: 24, // Standard size
                            ),
                            const SizedBox(width: 12),
                            Text(
                              "${l10n.commonLogIn} with Apple",
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.normal,
                                    color: Colors.black,
                                  ),
                            ),
                          ],
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
