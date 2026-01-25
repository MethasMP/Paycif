import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/connectivity_service.dart';
import '../l10n/generated/app_localizations.dart';

class ConnectivityWrapper extends StatelessWidget {
  final Widget child;

  const ConnectivityWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<ConnectivityService>(context);
    return StreamBuilder<ConnectivityStatus>(
      stream: service.statusStream,
      initialData: service.currentStatus, // Sync with current state immediately
      builder: (context, snapshot) {
        final isOffline = snapshot.data == ConnectivityStatus.offline;

        return Stack(
          children: [
            child,
            AnimatedOpacity(
              opacity: isOffline ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              child: IgnorePointer(
                ignoring: !isOffline,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.8),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.wifi_off_rounded,
                            size: 80,
                            color: Color(0xFFF59E0B), // Gold
                          ),
                          const SizedBox(height: 24),
                          Text(
                            AppLocalizations.of(context)?.noInternetTitle ??
                                'No Connection',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              decoration: TextDecoration.none,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            AppLocalizations.of(context)?.noInternetMessage ??
                                'Please check your internet settings.',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                              decoration: TextDecoration.none,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                          ElevatedButton(
                            onPressed: () {
                              Provider.of<ConnectivityService>(
                                context,
                                listen: false,
                              ).checkStatus();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF59E0B), // Gold
                              foregroundColor: const Color(0xFF1A1F71), // Navy
                              padding: const EdgeInsets.symmetric(
                                horizontal: 40,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: Text(
                              AppLocalizations.of(context)?.noInternetRetry ??
                                  'Retry',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
