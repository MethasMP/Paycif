import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/splash_screen.dart';
import 'services/connectivity_service.dart';
import 'widgets/connectivity_wrapper.dart';
import 'utils/theme_notifier.dart';
import 'utils/language_notifier.dart';
import 'theme/app_theme.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:frontend/l10n/generated/app_localizations.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'controllers/dashboard_controller.dart';
import 'controllers/payment_controller.dart';
import 'repositories/dashboard_repository.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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

  runApp(const PaycifApp());
}

class PaycifApp extends StatefulWidget {
  const PaycifApp({super.key});

  @override
  State<PaycifApp> createState() => _PaycifAppState();
}

class _PaycifAppState extends State<PaycifApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkSessionHealth();
    }
  }

  Future<void> _checkSessionHealth() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      // 🛡️ World-Class: Auto-Refresh on Resume
      // If token is expired or close to expiring (within 10 mins), refresh it.
      final isNearlyExpired =
          JwtDecoder.getExpirationDate(
            session.accessToken,
          ).difference(DateTime.now()).inMinutes <
          10;

      if (isNearlyExpired) {
        final timeleft = JwtDecoder.getExpirationDate(
          session.accessToken,
        ).difference(DateTime.now()).inMinutes;
        debugPrint(
          "📱 [Resilience] App Resumed: Token stale (${timeleft}m). Refreshing...",
        );
        try {
          // Use ApiService logic if available, or direct call with logging
          await Supabase.instance.client.auth.refreshSession();
          debugPrint(
            "✅ [Resilience] App Resumed: Session refreshed successfully.",
          );
        } catch (e) {
          debugPrint("⚠️ [Resilience] App Resumed: Refresh failed: $e");
          // If refresh fails on resume, we don't force logout yet,
          // but next API call will catch it via ApiService Interceptor.
        }
      } else {
        debugPrint("📱 [Resilience] App Resumed: Session is healthy.");
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
                ChangeNotifierProvider<PaymentController>(
                  create: (_) => PaymentController()..fetchData(),
                ),
                BlocProvider<DashboardController>(
                  create: (context) => DashboardController(
                    DashboardRepository(Supabase.instance.client),
                  )..init(),
                ),
              ],
              child: MaterialApp(
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
