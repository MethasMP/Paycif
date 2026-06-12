import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/network/connectivity_service.dart';
import 'package:frontend/core/network/api_service.dart';
import 'package:frontend/core/l10n/generated/app_localizations.dart';
import 'package:frontend/core/theme/app_theme.dart';

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
                              Icon(
                                    PhosphorIcons.wifiSlash,
                                    size: 100,
                                    color: AppTheme.warningAmber,
                                  )
                                  .animate(
                                    onPlay: (c) => c.repeat(reverse: true),
                                  )
                                  .scale(
                                    duration: 1.seconds,
                                    curve: Curves.easeInOut,
                                  ),
                              SizedBox(height: 32),
                              Text(
                                AppLocalizations.of(context)?.noInternetTitle ??
                                    'No Connection',
                                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                  color: Colors.white,
                                  decoration: TextDecoration.none,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 16),
                              Text(
                                AppLocalizations.of(
                                      context,
                                    )?.noInternetMessage ??
                                    'Please check your internet settings.',
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Colors.white70,
                                  decoration: TextDecoration.none,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 40),
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
                                    backgroundColor: AppTheme.warningAmber,
                                    foregroundColor: AppTheme.accentGoldDark,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(28),
                                    ),
                                    elevation: 8,
                                      shadowColor: AppTheme.warningAmber.withValues(alpha: 0.4),
                                  ),
                                  child: Text(
                                    AppLocalizations.of(
                                          context,
                                        )?.noInternetRetry ??
                                        'Retry',
                                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.accentGoldDark,
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
