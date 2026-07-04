import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/router/analytics_observer.dart';
import 'package:frontend/features/auth/presentation/splash_screen.dart';
import 'package:frontend/features/auth/presentation/login_screen.dart';
import 'package:frontend/features/dashboard/presentation/main_screen.dart';
import 'package:frontend/features/security/presentation/pages/security_unlock_screen.dart';
import 'package:frontend/features/security/presentation/pages/pin_setup_screen.dart';
import 'package:frontend/features/profile/presentation/terms_of_service_screen.dart';
import 'package:frontend/features/profile/presentation/privacy_policy_screen.dart';
import 'package:frontend/features/payment/presentation/scan_page.dart';
import 'package:frontend/features/profile/presentation/profile_page.dart';
import 'package:frontend/features/transactions/presentation/history_screen.dart';
import 'package:frontend/features/payment/presentation/payment_settings_screen.dart';
import 'package:frontend/features/profile/presentation/add_card_screen.dart';

import 'package:frontend/features/kyc/presentation/kyc_screen.dart';
import 'package:frontend/features/kyc/presentation/sumsub_kyc_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/features/security/presentation/pages/linked_devices_screen.dart';
import 'package:frontend/features/profile/presentation/notification_settings_screen.dart';
import 'package:frontend/features/profile/presentation/help_center_screen.dart';
import 'package:frontend/features/profile/presentation/contact_support_screen.dart';
import 'package:frontend/features/transactions/presentation/transaction_detail_screen.dart';
import 'package:frontend/features/transactions/domain/transaction.dart';
import 'package:frontend/features/payment/presentation/pages/pay_screen.dart';
import 'package:frontend/features/payment/presentation/pages/payment_success_screen.dart';

// Import other screens here as we migrate them...

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Centralized Router using go_router.
/// Supports state restoration (restorationScopeId) and deep linking.
final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  observers: [
    AnalyticsObserver(),
  ],
  // Enable State Restoration
  restorationScopeId: 'paycif_router',
  routes: [
    GoRoute(
      path: '/',
      name: 'splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/main',
      name: 'main',
      builder: (context, state) => const MainScreen(),
    ),
    GoRoute(
      path: '/unlock',
      name: 'unlock',
      builder: (context, state) => const SecurityUnlockScreen(),
    ),
    GoRoute(
      path: '/pin_setup',
      name: 'pin_setup',
      builder: (context, state) => const PinSetupScreen(),
    ),
    GoRoute(
      path: '/terms',
      name: 'terms',
      builder: (context, state) => const TermsOfServiceScreen(),
    ),
    GoRoute(
      path: '/privacy',
      name: 'privacy',
      builder: (context, state) => const PrivacyPolicyScreen(),
    ),
    GoRoute(
      path: '/scan',
      name: 'scan',
      builder: (context, state) => const ScanPage(),
    ),
    GoRoute(
      path: '/profile',
      name: 'profile',
      builder: (context, state) => const ProfilePage(),
    ),
    GoRoute(
      path: '/history',
      name: 'history',
      builder: (context, state) => const HistoryScreen(),
    ),
    GoRoute(
      path: '/payment_settings',
      name: 'payment_settings',
      builder: (context, state) => const PaymentSettingsScreen(),
    ),
    GoRoute(
      path: '/add_card',
      name: 'add_card',
      builder: (context, state) => const AddCardScreen(),
    ),

    GoRoute(
      path: '/kyc',
      name: 'kyc',
      builder: (context, state) => BlocProvider(
        create: (_) => SumsubKycCubit(),
        child: const KycScreen(),
      ),
    ),
    GoRoute(
      path: '/linked_devices',
      name: 'linked_devices',
      builder: (context, state) => const LinkedDevicesScreen(),
    ),
    GoRoute(
      path: '/notification_settings',
      name: 'notification_settings',
      builder: (context, state) => const NotificationSettingsScreen(),
    ),
    GoRoute(
      path: '/help',
      name: 'help',
      builder: (context, state) => const HelpCenterScreen(),
    ),
    GoRoute(
      path: '/contact_support',
      name: 'contact_support',
      builder: (context, state) => const ContactSupportScreen(),
    ),
    GoRoute(
      path: '/transaction_detail',
      name: 'transaction_detail',
      builder: (context, state) {
        final tx = state.extra as Transaction;
        return TransactionDetailScreen(transaction: tx);
      },
    ),
    GoRoute(
      path: '/pay',
      name: 'pay',
      builder: (context, state) {
        final params = state.extra as Map<String, dynamic>? ?? {};
        return PayScreen(
          amount: params['amount'] ?? 0.0,
          merchantName: params['merchantName'] ?? '',
          promptPayId: params['promptPayId'],
          billerId: params['billerId'],
          reference1: params['reference1'],
          reference2: params['reference2'],
        );
      },
    ),
    GoRoute(
      path: '/payment_success',
      name: 'payment_success',
      builder: (context, state) {
        final params = state.extra as Map<String, dynamic>? ?? {};
        return PaymentSuccessScreen(
          transactionId: params['transactionId'] ?? '',
          amount: params['amount'] ?? 0.0,
          recipientName: params['recipientName'] ?? '',
          promptPayId: params['promptPayId'],
        );
      },
    ),
  ],
  // Centralized Route Guards (Redirects)
  redirect: (BuildContext context, GoRouterState state) {
    // We can add auth checks here in the future
    // final isAuthenticated = context.read<AuthBloc>().state.isAuthenticated;
    // if (!isAuthenticated && state.uri.path != '/login') return '/login';
    return null; // Return null to proceed without redirecting
  },
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Text('Route not found: ${state.uri.path}'),
    ),
  ),
);
