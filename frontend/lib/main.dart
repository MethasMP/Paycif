import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:frontend/core/network/connectivity_service.dart';
import 'package:frontend/core/network/api_service.dart';
import 'package:frontend/core/widgets/connectivity_wrapper.dart';
import 'package:frontend/core/utils/theme_notifier.dart';
import 'package:frontend/core/utils/language_notifier.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:frontend/core/l10n/generated/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/router/app_router.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:frontend/features/dashboard/presentation/dashboard_controller.dart';
import 'package:frontend/features/payment/presentation/payment_controller.dart';
import 'package:frontend/features/dashboard/data/dashboard_repository.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:frontend/core/network/push_notification_service.dart';
import 'firebase_options.dart';

import 'package:frontend/features/security/data/datasources/security_remote_data_source.dart';
import 'package:frontend/features/security/data/datasources/crypto_service.dart';
import 'package:frontend/features/security/data/datasources/secure_storage_service.dart';
import 'package:frontend/features/security/domain/repositories/security_repository.dart';
import 'package:frontend/features/security/data/repositories/security_repository_impl.dart';
import 'package:frontend/features/security/presentation/logic/security_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.initHostOverride();

  // 🛡️ Required via --dart-define; falls back to local-dev defaults only in
  // kDebugMode. Release/profile builds fail fast instead of silently
  // shipping with dev credentials. See ApiService.requireEnv.
  final String supabaseUrlRaw = ApiService.requireEnv(
    const String.fromEnvironment('SUPABASE_URL'),
    'SUPABASE_URL',
    debugFallback: 'http://127.0.0.1:54321',
  );
  final String supabaseKey = ApiService.supabaseAnonKey;

  final supabaseUrl = ApiService.resolveLocalHost(supabaseUrlRaw);

  final parsedUrl = supabaseUrl.isNotEmpty ? Uri.tryParse(supabaseUrl) : null;
  if (supabaseUrl.isEmpty || parsedUrl == null || !parsedUrl.isAbsolute) {
    throw Exception(
      '🚨 FATAL ERROR: Malformed or missing SUPABASE_URL in .env. Checking this prevents the "WebSocket 500" crash.',
    );
  }

  // 🛡️ Realtime Stability Fix: Explicit RealtimeClientOptions prevent premature
  // WebSocket disconnects (channel error 1002) on mobile networks with brief
  // interruptions. eventsPerSecond: 10 documents the intended rate-limit and
  // shields against future SDK default changes that could break reconnect logic.
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseKey,
    realtimeClientOptions: const RealtimeClientOptions(
      eventsPerSecond: 10,
      // logLevel: RealtimeLogLevel.info, // enable only for debug
    ),
  );

  // 🛡️ Firebase Initialization (Required for Push Notifications)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // 📲 Obtain APNS token for iOS devices (required for Supabase realtime / FCM on iOS)
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
      if (apnsToken != null && Supabase.instance.client.auth.currentSession != null) {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(data: {'apns_token': apnsToken}),
        );
        debugPrint('✅ APNS token set in Supabase');
      } else {
        // Simulators or apps without push entitlements won't have APNS tokens, which is fine in debug/dev
        debugPrint('📡 APNS token not available yet or no active session (normal on iOS Simulator/Debug/Startup)');
      }
    }
    await PushNotificationService.initialize();
  } catch (e) {
    debugPrint('⚠️ Firebase initialization failed: $e');
  }

  // 🛡️ World-Class Diagnostic: Project Environment Audit
  // Log truncated URL and Key prefix to detect environment mismatches without leaking secrets.
  final projectRef = Uri.parse(supabaseUrl).host.split('.').first;
  final keyPrefix = supabaseKey.length > 10
      ? supabaseKey.substring(0, 10)
      : 'INVALID';
  debugPrint('🚀 [Environment] Project: $projectRef');
  debugPrint('🚀 [Environment] Key Prefix: $keyPrefix...');
  debugPrint('🚀 [Environment] Backend: ${const String.fromEnvironment('BACKEND_URL')}');

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
  Timer? _heartbeatTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startHeartbeat();
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    // 💓 The Supreme Session Engine: Heartbeat Timer
    // Check and refresh session proactively every 15 minutes
    // even if the user is just sitting on a screen.
    // This makes the "Expiry" non-existent to the user.
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 15), (timer) {
      _checkSessionHealth();
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  @override
  void dispose() {
    _stopHeartbeat();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  DateTime? _lastBackgroundTime;
  static const _lockdownThreshold = Duration(seconds: 30);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startHeartbeat(); // Resume heartbeat when user returns
      _checkSessionHealth();
      _checkBackgroundLockdown();
    } else if (state == AppLifecycleState.paused) {
      _stopHeartbeat(); // Stop heartbeat when backgrounded to save energy
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
      // 🛡️ World-Class Security: Force re-authentication if not already on the unlock screen
      final currentConfig = appRouter.routerDelegate.currentConfiguration;
      final isAlreadyOnUnlockScreen = currentConfig.uri.path == '/unlock';

      if (!isAlreadyOnUnlockScreen) {
        if (rootNavigatorKey.currentContext != null) {
          rootNavigatorKey.currentContext!.go('/unlock');
        }
      }
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
        if (rootNavigatorKey.currentContext != null) {
          rootNavigatorKey.currentContext!
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
                    context.read<ConnectivityService>(),
                  )..init(),
                ),
                ChangeNotifierProvider<SecurityController>(
                  create: (context) =>
                      SecurityController(context.read<SecurityRepository>()),
                ),
              ],
              child: MaterialApp.router(
                routerConfig: appRouter,
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
              ),
            );
          },
        );
      },
    );
  }
}
