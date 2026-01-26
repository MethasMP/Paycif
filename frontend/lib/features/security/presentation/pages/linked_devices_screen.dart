import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:frontend/l10n/generated/app_localizations.dart';
import '../../domain/repositories/security_repository.dart';
import '../logic/linked_devices_controller.dart';
import 'package:frontend/utils/pay_notify.dart';
import '../../../../screens/login_screen.dart'; // For logout redirection

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
      appBar: AppBar(title: Text(l10n.linkedDevices), centerTitle: true),
      body: controller.isLoading
          ? const Center(child: CircularProgressIndicator())
          : controller.devices.isEmpty
          ? _buildEmptyState(context, isDark)
          : ListView.separated(
              padding: const EdgeInsets.all(24),
              itemCount: controller.devices.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final device = controller.devices[index];
                return _buildDeviceTile(
                  context,
                  device,
                  controller,
                  l10n,
                  isDark,
                ).animate(delay: (index * 100).ms).fadeIn().slideX();
              },
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.devices_other_rounded,
            size: 64,
            color: Colors.grey.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No active devices found',
            style: TextStyle(
              color: Colors.grey.withValues(alpha: 0.8),
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
      platformIcon = Icons.apple;
    } else if (osType.contains('android')) {
      platformIcon = Icons.android;
    } else {
      platformIcon = Icons.phone_android;
    }

    return Dismissible(
      key: Key(deviceId),
      direction: DismissDirection.endToStart,
      background: Container(
        padding: const EdgeInsets.only(right: 24),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
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
                      style: TextStyle(color: Colors.red),
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
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          } else if (context.mounted) {
            PayNotify.success(context, 'Device revoked successfully');
          }
        } catch (e) {
          // If error occurs, state might be desync, but controller reloads usually
          if (context.mounted) {
            PayNotify.error(context, 'Failed to revoke device');
          }
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: isCurrent
              ? Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.5),
                  width: 1.5,
                )
              : Border.all(color: Colors.grey.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isCurrent
                  ? const Color(0xFF10B981).withValues(alpha: 0.1)
                  : Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              platformIcon,
              color: isCurrent ? const Color(0xFF10B981) : Colors.grey,
            ),
          ),
          title: Text(
            deviceName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              isCurrent
                  ? Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Current Device',
                          style: TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      'Active ${controller.formatLastActive(lastActive)}',
                      style: TextStyle(
                        color: Colors.grey.withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
