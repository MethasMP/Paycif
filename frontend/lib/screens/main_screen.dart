import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/security/presentation/logic/security_controller.dart';
import '../controllers/dashboard_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart' as import_login;
import '../services/api_service.dart';
import 'package:flutter/services.dart';

import 'home_view.dart';
import 'payment_settings_screen.dart';
import 'history_screen.dart';
import 'profile_page.dart';
import 'scan_page.dart';
import 'package:frontend/l10n/generated/app_localizations.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _prewarmCache();
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedOut) {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const import_login.LoginScreen()),
            (route) => false,
          );
        }
      }
    });
  }

  Future<void> _prewarmCache() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;
    try {
      context.read<SecurityController>().ensureDeviceBinding();
      await Future.wait([
        _apiService.getUserProfile(),
        _apiService.getSavedCards(),
      ]);
    } catch (_) {}
  }

  List<Widget> get _screens => [
    const HomeView(),
    const HistoryScreen(),
    ScanPage(onBack: () => _onItemTapped(0)),
    const PaymentSettingsScreen(),
    const ProfilePage(),
  ];

  void _onItemTapped(int index) {
    HapticFeedback.lightImpact();
    if (index == 2) {
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ScanPage())).then((_) {
        if (mounted) context.read<DashboardController>().refresh();
      });
      return;
    }
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _selectedIndex != 0) setState(() => _selectedIndex = 0);
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: IndexedStack(index: _selectedIndex, children: _screens),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5)),
            ],
          ),
          child: BottomNavigationBar(
            items: <BottomNavigationBarItem>[
              BottomNavigationBarItem(icon: const Icon(Icons.home_filled), label: AppLocalizations.of(context)!.navHome),
              BottomNavigationBarItem(icon: const Icon(Icons.history), label: AppLocalizations.of(context)!.navHistory),
              BottomNavigationBarItem(
                icon: Hero(
                  tag: 'scan-hero',
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: theme.primaryColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: theme.primaryColor.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5)),
                      ],
                    ),
                    child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 28),
                  ),
                ),
                label: '',
              ),
              BottomNavigationBarItem(icon: const Icon(Icons.payment), label: AppLocalizations.of(context)!.navPayment),
              BottomNavigationBarItem(icon: const Icon(Icons.person), label: AppLocalizations.of(context)!.navProfile),
            ],
            currentIndex: _selectedIndex,
            selectedItemColor: theme.primaryColor,
            unselectedItemColor: const Color(0xFF94A3B8),
            type: BottomNavigationBarType.fixed,
            backgroundColor: theme.cardColor,
            elevation: 0,
            onTap: _onItemTapped,
          ),
        ),
      ),
    );
  }
}
