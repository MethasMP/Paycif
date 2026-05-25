import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../services/connectivity_service.dart';
import '../services/api_service.dart';
import '../l10n/generated/app_localizations.dart';

class ConnectivityWrapper extends StatelessWidget {
  final Widget child;

  const ConnectivityWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<ConnectivityService>(context);
    return StreamBuilder<ConnectivityStatus>(
      stream: service.statusStream,
      initialData: service.currentStatus,
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
                ignoring:
                    !isOffline, // 🛡️ CRITICAL: Don't block UI when online!
                child: Material(
                  type: MaterialType.transparency,
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: Colors.black.withValues(alpha: 0.9),
                    child: Center(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                    Icons.wifi_off_rounded,
                                    size: 100,
                                    color: Color(0xFFF59E0B),
                                  )
                                  .animate(
                                    onPlay: (c) => c.repeat(reverse: true),
                                  )
                                  .scale(
                                    duration: 1.seconds,
                                    curve: Curves.easeInOut,
                                  ),
                              const SizedBox(height: 32),
                              Text(
                                AppLocalizations.of(context)?.noInternetTitle ??
                                    'No Connection',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                  decoration: TextDecoration.none,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                AppLocalizations.of(
                                      context,
                                    )?.noInternetMessage ??
                                    'Please check your internet settings.',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.white70,
                                  height: 1.5,
                                  decoration: TextDecoration.none,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 40),
                              SizedBox(
                                width: 200,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: () {
                                    HapticFeedback.mediumImpact();
                                    ApiService.resetCircuitBreaker();
                                    Provider.of<ConnectivityService>(
                                      context,
                                      listen: false,
                                    ).checkStatus();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFF59E0B),
                                    foregroundColor: const Color(0xFF1A1F71),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(28),
                                    ),
                                    elevation: 8,
                                    shadowColor: const Color(
                                      0xFFF59E0B,
                                    ).withValues(alpha: 0.4),
                                  ),
                                  child: Text(
                                    AppLocalizations.of(
                                          context,
                                        )?.noInternetRetry ??
                                        'Retry',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
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
              ),
            ),
          ],
        );
      },
    );
  }
}
