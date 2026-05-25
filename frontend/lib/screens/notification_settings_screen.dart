import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:frontend/l10n/generated/app_localizations.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _transactionAlerts = true;
  bool _marketingUpdates = true;
  bool _isLoading = true;

  static const String _keyTransaction = 'notification_transaction';
  static const String _keyMarketing = 'notification_marketing';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _transactionAlerts = prefs.getBool(_keyTransaction) ?? true;
        _marketingUpdates = prefs.getBool(_keyMarketing) ?? true;
        _isLoading = false;
      });
    }
  }

  Future<void> _savePreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);

    // 🛡️ World-Class Security: Sync Policy to Server
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        // Map local keys to database columns
        final dbColumn = key == _keyTransaction
            ? 'notification_transaction'
            : 'notification_marketing';

        await Supabase.instance.client
            .from('profiles')
            .update({
              dbColumn: value,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', user.id);

        debugPrint('✅ Pref synced: $dbColumn = $value');
      }
    } catch (e) {
      debugPrint('⚠️ Preferences sync failed: $e');
      // We don't block the UI, local persistence is already done.
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🛡️ Security-First: We use the context's theme to inherit the premium feel
    // and consistent typography.
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.notificationSettingsTitle,
        ),
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        iconTheme: IconThemeData(color: theme.textTheme.bodyLarge?.color),
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🛡️ 1. Security Alerts (Non-negotiable)
                  _buildSectionHeader(
                    AppLocalizations.of(context)!.notificationSecurityAlwaysOn,
                  ),
                  const SizedBox(height: 16),
                  _buildCard(context, [
                    _buildSwitchTile(
                      context,
                      title: AppLocalizations.of(
                        context,
                      )!.notificationAccountSecurity,
                      subtitle: AppLocalizations.of(
                        context,
                      )!.notificationAccountSecurityDesc,
                      value: true,
                      onChanged: null, // Disabled: Security is mandatory
                      icon: Icons.shield_rounded,
                      activeColor: const Color(
                        0xFF10B981,
                      ), // Green for Security
                    ),
                  ]),

                  const SizedBox(height: 32),

                  // 💳 2. Transaction Activity
                  _buildSectionHeader(
                    AppLocalizations.of(context)!.notificationWalletActivity,
                  ),
                  const SizedBox(height: 16),
                  _buildCard(context, [
                    _buildSwitchTile(
                      context,
                      title: AppLocalizations.of(
                        context,
                      )!.notificationTransactionAlerts,
                      subtitle: AppLocalizations.of(
                        context,
                      )!.notificationTransactionAlertsDesc,
                      value: _transactionAlerts,
                      onChanged: (val) {
                        setState(() => _transactionAlerts = val);
                        _savePreference(_keyTransaction, val);
                      },
                      icon: Icons.account_balance_wallet_rounded,
                      activeColor: const Color(0xFFF59E0B), // Brand Color
                    ),
                  ]),

                  const SizedBox(height: 32),

                  // 📣 3. Marketing & Updates
                  _buildSectionHeader(
                    AppLocalizations.of(context)!.notificationUpdates,
                  ),
                  const SizedBox(height: 16),
                  _buildCard(context, [
                    _buildSwitchTile(
                      context,
                      title: AppLocalizations.of(
                        context,
                      )!.notificationNewsPromotions,
                      subtitle: AppLocalizations.of(
                        context,
                      )!.notificationNewsPromotionsDesc,
                      value: _marketingUpdates,
                      onChanged: (val) {
                        setState(() => _marketingUpdates = val);
                        _savePreference(_keyMarketing, val);
                      },
                      icon: Icons.campaign_rounded,
                      activeColor: Colors.blueAccent,
                    ),
                  ]),

                  const SizedBox(height: 48),

                  // Footer Note
                  Center(
                    child: Text(
                      'Push notifications help you stay secure and informed.\nYou can manage system-level permission in your device settings.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        color: Colors.grey,
      ),
    );
  }

  Widget _buildCard(BuildContext context, List<Widget> children) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool? value,
    required ValueChanged<bool>? onChanged,
    required IconData icon,
    required Color activeColor,
  }) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: activeColor, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            color: theme.textTheme.bodySmall?.color,
          ),
        ),
      ),
      trailing: Switch.adaptive(
        value: value ?? true,
        onChanged: onChanged,
        activeTrackColor: activeColor,
      ),
    );
  }
}
