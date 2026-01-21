import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';
import 'utils/theme_notifier.dart';
import 'utils/language_notifier.dart';
import 'theme/app_theme.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:frontend/l10n/generated/app_localizations.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'controllers/dashboard_controller.dart';
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

  runApp(const ZapPayApp());
}

class ZapPayApp extends StatelessWidget {
  const ZapPayApp({super.key});

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
                BlocProvider<DashboardController>(
                  create: (context) => DashboardController(
                    DashboardRepository(Supabase.instance.client),
                  )..init(),
                ),
              ],
              child: MaterialApp(
                title: 'ZapPay',
                themeMode: currentMode,
                locale: currentLocale,
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
                home: const LoginScreen(),
              ),
            );
          },
        );
      },
    );
  }
}
