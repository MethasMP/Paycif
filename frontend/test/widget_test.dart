import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:frontend/screens/login_screen.dart';
import 'package:frontend/services/connectivity_service.dart';
import 'package:frontend/features/security/domain/repositories/security_repository.dart';
import 'package:frontend/features/security/data/repositories/security_repository_impl.dart';
import 'package:frontend/features/security/data/datasources/security_remote_data_source.dart';
import 'package:frontend/features/security/data/datasources/crypto_service.dart';
import 'package:frontend/features/security/data/datasources/secure_storage_service.dart';
import 'package:frontend/controllers/payment_controller.dart';
import 'package:frontend/controllers/dashboard_controller.dart';
import 'package:frontend/repositories/dashboard_repository.dart';
import 'package:frontend/features/security/presentation/logic/security_controller.dart';
import 'package:frontend/l10n/generated/app_localizations.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://mock.supabase.co',
      anonKey: 'mockAnonKey',
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
      ),
    );
  });

  testWidgets('Login screen smoke test', (WidgetTester tester) async {
    // Build the providers and the LoginScreen in isolation
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ConnectivityService>(
            create: (_) => ConnectivityService(),
            dispose: (_, service) => service.dispose(),
          ),
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
            create: (_) => PaymentController(),
          ),
          BlocProvider<DashboardController>(
            create: (context) => DashboardController(
              DashboardRepository(Supabase.instance.client),
              context.read<ConnectivityService>(),
            ),
          ),
          ChangeNotifierProvider<SecurityController>(
            create: (context) =>
                SecurityController(context.read<SecurityRepository>()),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const LoginScreen(),
        ),
      ),
    );

    // Let any initial frame settle (e.g. fade-in animation)
    await tester.pumpAndSettle();

    // Verify that the Login Screen is displayed.
    // Check for brand title "Paycif"
    expect(find.text('Paycif'), findsOneWidget);

    // Check for buttons
    expect(find.text('Log In with Google'), findsOneWidget);
    expect(find.text('Log In with Apple'), findsOneWidget);
  });
}
