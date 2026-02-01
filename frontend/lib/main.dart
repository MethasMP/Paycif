import 'package:flutter/material.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/splash_screen.dart';
import 'services/connectivity_service.dart';
import 'services/api_service.dart';
import 'widgets/connectivity_wrapper.dart';
import 'utils/theme_notifier.dart';
import 'utils/language_notifier.dart';
import 'theme/app_theme.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:frontend/l10n/generated/app_localizations.dart';
// import 'package:jwt_decoder/jwt_decoder.dart'; // No longer needed

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'controllers/dashboard_controller.dart';
import 'controllers/payment_controller.dart';
import 'repositories/dashboard_repository.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'features/security/data/datasources/security_remote_data_source.dart';
import 'features/security/data/datasources/crypto_service.dart';
import 'features/security/data/datasources/secure_storage_service.dart';
import 'features/security/domain/repositories/security_repository.dart';
import 'features/security/data/repositories/security_repository_impl.dart';
import 'features/security/presentation/logic/security_controller.dart';
import 'features/security/presentation/pages/security_unlock_screen.dart';
// import 'screens/main_screen.dart'; // No longer used in main.dart nav directly

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseKey = dotenv.env['SUPABASE_ANON_KEY'];

  if (supabaseUrl == null || !Uri.tryParse(supabaseUrl)!.isAbsolute) {
    throw Exception(
      '🚨 FATAL ERROR: Malformed or missing SUPABASE_URL in .env. Checking this prevents the "WebSocket 500" crash.',
    );
  }

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey ?? '');

  // 🛡️ World-Class Diagnostic: Project Environment Audit
  // Log truncated URL and Key prefix to detect environment mismatches without leaking secrets.
  final projectRef = Uri.parse(supabaseUrl).host.split('.').first;
  final keyPrefix = (supabaseKey ?? '').length > 10
      ? (supabaseKey ?? '').substring(0, 10)
      : 'INVALID';
  debugPrint('🚀 [Environment] Project: $projectRef');
  debugPrint('🚀 [Environment] Key Prefix: $keyPrefix...');
  debugPrint('🚀 [Environment] Backend: ${dotenv.env['BACKEND_URL']}');

  // 10x Performance: Establish early connection to backend
  ApiService.prewarmConnection().ignore();

  runApp(const PaycifApp());
}

class PaycifApp extends StatefulWidget {
  const PaycifApp({super.key});

  @override
  State<PaycifApp> createState() => _PaycifAppState();
}

class _PaycifAppState extends State<PaycifApp> with WidgetsBindingObserver {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  Timer? _heartbeatTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 💓 The Supreme Session Engine: Heartbeat Timer
    // Check and refresh session proactively every 15 minutes
    // even if the user is just sitting on a screen.
    // This makes the "Expiry" non-existent to the user.
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 15), (timer) {
      _checkSessionHealth();
    });
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  DateTime? _lastBackgroundTime;
  static const _lockdownThreshold = Duration(seconds: 30);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkSessionHealth();
      _checkBackgroundLockdown();
    } else if (state == AppLifecycleState.paused) {
      _lastBackgroundTime = DateTime.now();
      debugPrint("📱 [Security] App backgrounded at: $_lastBackgroundTime");
    }
  }

  void _checkBackgroundLockdown() {
    if (_lastBackgroundTime == null) return;

    final inactiveDuration = DateTime.now().difference(_lastBackgroundTime!);
    debugPrint(
      "📱 [Security] App resumed after: ${inactiveDuration.inSeconds}s",
    );

    if (inactiveDuration > _lockdownThreshold) {
      debugPrint(
        "🚨 [Security] Lockdown triggered! Redirecting to SecurityUnlockScreen...",
      );
      // 🛡️ World-Class Security: Force re-authentication
      // Use navigatorKey to find the correct context for navigation
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SecurityUnlockScreen()),
        (route) => false,
      );
    }
    _lastBackgroundTime = null; // Reset
  }

  Future<void> _checkSessionHealth() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      // 🛡️ World-Class First Principle: "Daily Use = Never Expire"
      // We use the Centralized Mutex from ApiService to prevent Race Conditions.
      // This ensures that MainScreen, SecurityDataSource, and ApiService all respect the same lock.
      debugPrint(
        "📱 [Resilience] App Resumed: Proactivately extending session (Centralized)...",
      );

      try {
        await ApiService.ensureSessionValid(forceRefresh: false);
        debugPrint(
          "✅ [Resilience] Session health checked via Centralized Manager.",
        );

        // 🕯️ Background Security Warmup
        if (navigatorKey.currentContext != null) {
          navigatorKey.currentContext!
              .read<SecurityController>()
              .warmUp()
              .ignore();
        }
      } catch (e) {
        debugPrint("⚠️ [Resilience] Extension warning: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        return ValueListenableBuilder<Locale>(
          valueListenable: languageNotifier,
          builder: (context, currentLocale, _) {
            return MultiProvider(
              providers: [
                Provider<ConnectivityService>(
                  create: (_) => ConnectivityService(),
                  dispose: (_, service) => service.dispose(),
                ),
                // 🛡️ Provide Security Infrastructure Globally
                Provider<SecurityRepository>(
                  create: (_) => SecurityRepositoryImpl(
                    remoteDataSource: SecurityRemoteDataSource(
                      Supabase.instance.client,
                    ),
                    cryptoService: CryptoService(),
                    secureStorage: SecureStorageService(),
                  ),
                ),
                ChangeNotifierProvider<PaymentController>(
                  create: (_) => PaymentController()..fetchData(),
                ),
                BlocProvider<DashboardController>(
                  create: (context) => DashboardController(
                    DashboardRepository(Supabase.instance.client),
                  )..init(),
                ),
                ChangeNotifierProvider<SecurityController>(
                  create: (context) =>
                      SecurityController(context.read<SecurityRepository>()),
                ),
              ],
              child: MaterialApp(
                navigatorKey: navigatorKey,
                title: 'Paycif',
                themeMode: currentMode,
                locale: currentLocale,
                builder: (context, child) {
                  return ConnectivityWrapper(child: child!);
                },
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: AppLocalizations.supportedLocales,
                // ─── Centralized Theme ─────────────────────────────────────
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                // ───────────────────────────────────────────────────────────
                home: const SplashScreen(),
              ),
            );
          },
        );
      },
    );
  }
}
