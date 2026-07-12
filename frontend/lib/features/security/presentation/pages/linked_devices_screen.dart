import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/l10n/generated/app_localizations.dart';
import 'package:frontend/features/security/domain/repositories/security_repository.dart';
import 'package:frontend/features/security/presentation/logic/linked_devices_controller.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/utils/pay_notify.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/app_icon.dart';

class LinkedDevicesScreen extends StatelessWidget {
  const LinkedDevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          LinkedDevicesController(context.read<SecurityRepository>()),
      child: const _LinkedDevicesView(),
    );
  }
}

class _LinkedDevicesView extends StatelessWidget {
  const _LinkedDevicesView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LinkedDevicesController>();
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: Text(l10n.linkedDevices)),
      body: controller.isLoading
          ? Center(child: CircularProgressIndicator())
          : controller.devices.isEmpty
          ? _buildEmptyState(context, isDark)
          : ListView.separated(
              padding: const EdgeInsets.all(24),
              itemCount: controller.devices.length,
              separatorBuilder: (context, index) => SizedBox(height: 16),
              itemBuilder: (context, index) {
                final device = controller.devices[index];
                return _buildDeviceTile(
                  context,
                  device,
                  controller,
                  l10n,
                  isDark,
                );
              },
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(
            PhosphorIcons.devices,
            size: AppIconSize.xl,
            color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.5),
          ),
          SizedBox(height: 16),
          Text(
            'No active devices found',
            style: TextStyle(
              color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.8),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceTile(
    BuildContext context,
    Map<String, dynamic> device,
    LinkedDevicesController controller,
    AppLocalizations l10n,
    bool isDark,
  ) {
    final deviceId = device['device_id'] as String;
    final isCurrent = deviceId == controller.currentDeviceId;
    final deviceName = device['device_name']?.toString() ?? 'Unknown Device';
    final osType = device['os_type']?.toString().toLowerCase() ?? 'unknown';
    final lastActive = device['last_used_at']?.toString() ?? '';

    IconData platformIcon;
    if (osType.contains('ios') || osType.contains('iphone')) {
      platformIcon = PhosphorIcons.appleLogo;
    } else if (osType.contains('android')) {
      platformIcon = PhosphorIcons.androidLogo;
    } else {
      platformIcon = PhosphorIcons.deviceMobile;
    }

    return Dismissible(
      key: Key(deviceId),
      direction: DismissDirection.endToStart,
      background: Container(
        padding: const EdgeInsets.only(right: 24),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: AppTheme.errorRed.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: AppIcon(PhosphorIcons.trash, color: Colors.white, size: AppIconSize.lg),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Revoke Device'),
                content: Text(
                  isCurrent
                      ? 'Are you sure you want to revoke this device? You will be logged out immediately.'
                      : 'Are you sure you want to revoke access for this device?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(l10n.commonCancel),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text(
                      'Revoke',
                      style: TextStyle(color: AppTheme.errorRedText),
                    ),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (direction) async {
        try {
          final shouldLogout = await controller.revokeDevice(deviceId, l10n);
          if (context.mounted && shouldLogout) {
            // Force Logout logic
            context.go('/login');
          } else if (context.mounted) {
            PayNotify.success(context, l10n.devicesRevokeSuccess);
          }
        } catch (e) {
          // If error occurs, state might be desync, but controller reloads usually
          if (context.mounted) {
            PayNotify.error(context, l10n.devicesRevokeFailed);
          }
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: isCurrent
              ? Border.all(
                  color: AppTheme.successGreen.withValues(alpha: 0.5),
                  width: 1.5,
                )
              : Border.all(color: AppTheme.borderGrey),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isCurrent
                    ? AppTheme.successGreen.withValues(alpha: 0.1)
                    : Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: AppIcon(
                platformIcon,
                color: isCurrent ? AppTheme.successGreen : AppTheme.textSecondaryColor(context),
              ),
            ),
            title: Text(
              deviceName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 4),
                isCurrent
                    ? Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppTheme.successGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 6),
                          const Text(
                            'Current Device',
                            style: TextStyle(
                              color: AppTheme.successGreen,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        'Active ${controller.formatLastActive(lastActive)}',
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
