import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/security/presentation/logic/security_controller.dart';
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
    // 🚀 PRE-WARM CACHE: Start fetching data in the background immediately
    _prewarmCache();

    // 🛡️ World-Class Security: Global Auth Listener
    // If the session expires or is killed by Sudo Mode (401),
    // this listener ensures we INSTANTLY redirect to Login,
    // closing all modals/sheets.
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedOut) {
        if (mounted) {
          // Prevent double navigation if already on LoginScreen?
          // Technically pushAndRemoveUntil clears everything.
          // However, let's make sure we are not already going there.
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const import_login.LoginScreen(),
            ),
            (route) => false,
          );
        }
      } else if (data.event == AuthChangeEvent.initialSession) {
        // Handle recovery?
      }
    });
  }

  Future<void> _prewarmCache() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;

    try {
      debugPrint('🔥 Pre-warming caches (Background)...');
      // 🛡️ World-Class Security: Ensure device binding is active for this session
      // This heals "Ghost Sessions" where a device was logged in but not bound.
      context.read<SecurityController>().ensureDeviceBinding();

      await Future.wait([
        _apiService.getUserProfile(),
        _apiService.getSavedCards(),
      ]);
      debugPrint('🔥 Caches pre-warmed successfully.');
    } catch (e) {
      debugPrint('⚠️ Pre-warm failed (non-critical): $e');
    }
  }

  List<Widget> get _screens => [
    const HomeView(),
    const HistoryScreen(),
    ScanPage(onBack: () => _onItemTapped(0)), // Position 2 with Callback
    const PaymentSettingsScreen(),
    const ProfilePage(),
  ];

  void _onItemTapped(int index) {
    // 🧠 Tactile Identity: Every interaction should feel "real"
    HapticFeedback.lightImpact();

    if (index == 2) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (context) => const ScanPage()));
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          items: <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: const Icon(Icons.home_filled),
              label: AppLocalizations.of(context)!.navHome,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.history),
              label: AppLocalizations.of(context)!.navHistory,
            ),
            BottomNavigationBarItem(
              icon: Hero(
                tag: 'scan-hero',
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor, // Deep Blue
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
                            : Theme.of(
                                context,
                              ).primaryColor.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                    gradient: LinearGradient(
                      colors: isDark
                          ? [
                              const Color(0xFFF59E0B), // Amber 500
                              const Color(0xFFB45309), // Amber 700
                            ]
                          : [
                              const Color(0xFF1A1F71), // Deep Blue
                              const Color(0xFF2C3E50), // Lighter
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner,
                    color: Colors.white, // Always White for contrast
                    size: 28,
                  ),
                ),
              ),
              label: '', // No label for focus
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.payment),
              label: AppLocalizations.of(context)!.navPayment,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.person),
              label: AppLocalizations.of(context)!.navProfile,
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: Theme.of(context).primaryColor,
          unselectedItemColor: const Color(0xFF94A3B8), // Slate 400
          selectedLabelStyle: TextStyle(
            color: Theme.of(context).primaryColor,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Theme.of(context).cardColor,
          elevation: 0,
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}
