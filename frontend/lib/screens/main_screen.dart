import 'package:flutter/material.dart';

import 'home_view.dart';
import 'wallet_screen.dart';
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

  List<Widget> get _screens => [
    const HomeView(),
    const HistoryScreen(),
    ScanPage(onBack: () => _onItemTapped(0)), // Position 2 with Callback
    const WalletScreen(),
    const ProfilePage(),
  ];

  void _onItemTapped(int index) {
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
      body: _screens[_selectedIndex],
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
                        color: Theme.of(
                          context,
                        ).primaryColor.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF1A1F71), // Deep Blue
                        Color(0xFF2C3E50), // Lighter
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
          selectedItemColor: Theme.of(
            context,
          ).colorScheme.primary, // #1A1F71 in Light
          unselectedItemColor: isDark
              ? Colors.grey[400]
              : const Color(0xFF9CA3AF),
          selectedLabelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          unselectedLabelStyle: Theme.of(context).textTheme.labelSmall
              ?.copyWith(fontWeight: FontWeight.w500, fontSize: 12),
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
