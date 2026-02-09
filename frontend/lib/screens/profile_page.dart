import 'package:flutter/material.dart';
import 'package:frontend/utils/pay_notify.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart'; // For redirection after logout
import 'help_center_screen.dart';
import 'contact_support_screen.dart';
import 'terms_of_service_screen.dart';
import 'privacy_policy_screen.dart';
import '../services/api_service.dart';
import 'package:frontend/l10n/generated/app_localizations.dart';
import 'package:local_auth/local_auth.dart';
import '../utils/theme_notifier.dart';
import '../utils/language_notifier.dart';
import '../utils/error_translator.dart';
import '../features/security/presentation/widgets/pin_entry_widget.dart';
import '../features/security/presentation/widgets/change_pin_sheet.dart';
import '../features/security/presentation/logic/security_controller.dart';
import '../features/security/presentation/pages/linked_devices_screen.dart';
import 'package:provider/provider.dart';
import 'notification_settings_screen.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _profile;

  // Biometric
  final LocalAuthentication _auth = LocalAuthentication();
  bool _isBiometricEnabled = false;
  bool _isBiometricAvailable = false;
  bool _isBiometricLoading = true;
  bool _isProcessingToggle = false;

  static const String _biometricPrefKey = 'biometric_enabled';

  @override
  void initState() {
    super.initState();
    _fetchProfile();
    _loadBiometricState();
  }

  Future<void> _loadBiometricState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();

      if (mounted) {
        setState(() {
          _isBiometricAvailable = canCheck && isSupported;
          _isBiometricEnabled = prefs.getBool(_biometricPrefKey) ?? false;
          _isBiometricLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading biometric state: $e');
      if (mounted) {
        setState(() => _isBiometricLoading = false);
      }
    }
  }

  Future<void> _saveBiometricState(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricPrefKey, enabled);

    // 🛡️ World-Class Security: Sync Policy to Server
    // This allows support to remotely kill biometrics via 'biometric_enabled = false'
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        await _supabase
            .from('profiles')
            .update({
              'biometric_enabled': enabled,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', user.id);
      }
    } catch (e) {
      // Non-blocking: If network fails, local preference still rules for UX.
      // But we log it.
      debugPrint('⚠️ Failed to sync biometric policy: $e');
    }
  }

  Future<void> _fetchProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _profile = data;
        });
      }
    } catch (e) {
      if (mounted) {
        // Silent fail
        debugPrint('Error loading profile: $e');
      }
    }
  }

  Future<void> _signOut() async {
    // 🛡️ World-Class Sign Out: HARD-RESET Flow

    // 1. Show Premium Loading Overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 30,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A1F71)),
                ),
                const SizedBox(height: 24),
                Text(
                  'Signing out safely...',
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // 2. Clear All Sensitive Caches (Principal Logic)
      ApiService.clearStaticCache();

      // 3. Clear Security Identity & PIN Anchors
      if (mounted) {
        final securityController = context.read<SecurityController>();
        await securityController.clearSecurityState();
      }

      // 4. Terminate Remote Session
      await _supabase.auth.signOut();

      // 5. Hard Navigation Reset
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('🚨 Sign Out Disaster: $e');
      if (mounted) {
        Navigator.pop(context); // Close loading
        PayNotify.error(
          context,
          'Critical error during sign out. Please force close app.',
        );
      }
    }
  }

  void _showSignOutConfirmation(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l10n.signOutConfirmTitle),
        content: Text(l10n.signOutConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _signOut();
            },
            child: Text(
              l10n.signOut,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  void _showLanguageSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.language,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...LanguageNotifier.supportedLocales.map((locale) {
              final isSelected = languageNotifier.value == locale;
              return ListTile(
                title: Text(LanguageNotifier.getLanguageName(locale)),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: Color(0xFF10B981))
                    : null,
                onTap: () {
                  languageNotifier.value = locale;
                  Navigator.pop(context);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    // Fallback if l10n is null (e.g. key missing), though it shouldn't be
    if (l10n == null) return const SizedBox.shrink();

    final user = _supabase.auth.currentUser;
    final String fullName =
        _profile?['full_name'] ??
        user?.userMetadata?['full_name'] ??
        l10n.profileGuestUser;
    final String? avatarUrl =
        _profile?['avatar_url'] ?? user?.userMetadata?['avatar_url'];
    final String kycStatus = _profile?['kyc_status'] ?? 'pending';
    final bool isVerified = kycStatus == 'verified';
    final String walletId = user?.id.substring(0, 8).toUpperCase() ?? 'ID-XXXX';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.profileTitle),
        // Style inherited from AppTheme.titleLarge via AppBarTheme.titleTextStyle
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),

            // ─── Digital Passport Card ──────────────────────────────
            _buildDigitalPassport(
              context,
              fullName,
              walletId,
              avatarUrl,
              isVerified,
              l10n,
            ),

            const SizedBox(height: 32),

            // ─── Account Settings ──────────────────────────────────
            _buildSectionHeader(context, l10n.accountSecurity),
            const SizedBox(height: 16),
            _buildMenuContainer(context, [
              _buildBiometricTile(context, l10n),
              _buildMenuItem(
                Icons.lock_outline,
                l10n.changePin,
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const ChangePinSheet(),
                  );
                },
              ),
              _buildMenuItem(
                Icons.devices,
                l10n.linkedDevices,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LinkedDevicesScreen(),
                  ),
                ),
              ),
            ]),

            const SizedBox(height: 32),

            // ─── App Preferences ───────────────────────────────────
            _buildSectionHeader(context, l10n.preferences),
            const SizedBox(height: 16),
            _buildMenuContainer(context, [
              // Dark Mode Toggle
              ValueListenableBuilder<ThemeMode>(
                valueListenable: themeNotifier,
                builder: (context, currentMode, _) {
                  final isDarkMode = currentMode == ThemeMode.dark;
                  return _buildMenuItem(
                    isDarkMode ? Icons.dark_mode : Icons.light_mode,
                    isDarkMode ? l10n.darkMode : l10n.lightMode,
                    onTap: () {
                      themeNotifier.value = isDarkMode
                          ? ThemeMode.light
                          : ThemeMode.dark;
                    },
                    trailing: Switch.adaptive(
                      value: isDarkMode,
                      activeTrackColor: const Color(0xFFF59E0B),
                      onChanged: (val) {
                        themeNotifier.value = val
                            ? ThemeMode.dark
                            : ThemeMode.light;
                      },
                    ),
                  );
                },
              ),
              _buildMenuItem(
                Icons.language,
                l10n.language,
                subtitle: LanguageNotifier.getLanguageName(
                  languageNotifier.value,
                ),
                onTap: () => _showLanguageSheet(context),
              ),
              _buildMenuItem(
                Icons.notifications_outlined,
                l10n.notifications,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationSettingsScreen(),
                  ),
                ),
              ),
            ]),

            const SizedBox(height: 32),

            // ─── Support ───────────────────────────────────────────
            _buildSectionHeader(context, l10n.support),
            const SizedBox(height: 16),
            _buildMenuContainer(context, [
              _buildMenuItem(
                Icons.help_outline,
                l10n.helpCenter,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HelpCenterScreen()),
                ),
              ),
              _buildMenuItem(
                Icons.chat_bubble_outline,
                l10n.contactSupport,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ContactSupportScreen(),
                  ),
                ),
              ),
            ]),

            const SizedBox(height: 32),

            // ─── About ─────────────────────────────────────────────
            _buildSectionHeader(context, l10n.aboutApp),
            const SizedBox(height: 16),
            _buildMenuContainer(context, [
              _buildMenuItem(
                Icons.description_outlined,
                l10n.termsOfService,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TermsOfServiceScreen(),
                  ),
                ),
              ),
              _buildMenuItem(
                Icons.privacy_tip_outlined,
                l10n.privacyPolicy,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PrivacyPolicyScreen(),
                  ),
                ),
              ),
            ]),

            const SizedBox(height: 48),

            // ─── Sign Out ──────────────────────────────────────────
            Center(
              child: ElevatedButton.icon(
                onPressed: () => _showSignOutConfirmation(context),
                icon: const Icon(Icons.logout_rounded, size: 20),
                label: Text(l10n.signOut),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                  foregroundColor: Colors.redAccent,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            Center(
              child: Text(
                '${l10n.version} 2.0.0 (Build 42)',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildDigitalPassport(
    BuildContext context,
    String name,
    String id,
    String? avatarUrl,
    bool isVerified,
    AppLocalizations l10n,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF0F172A), // Slate 900
                  const Color(0xFF1E293B), // Slate 800
                ]
              : [
                  const Color(0xFF1A1F71), // Navy
                  const Color(0xFF2C3E50), // Lighter Navy
                ],
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : const Color(0xFF1A1F71)).withValues(
              alpha: 0.2,
            ),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background Pattern
          Positioned(
            right: -40,
            top: -40,
            child: Icon(
              Icons.public,
              size: 200,
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Logo / Brand
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.bolt_rounded,
                            color: Color(0xFFF59E0B),
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            l10n.passportLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // KYC Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isVerified
                            ? const Color(0xFF10B981).withValues(alpha: 0.2)
                            : Colors.orange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isVerified ? Icons.verified : Icons.pending,
                            color: isVerified
                                ? const Color(0xFF10B981)
                                : Colors.orange,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isVerified
                                ? l10n.kycStatusVerified
                                : l10n.kycStatusPending,
                            style: TextStyle(
                              color: isVerified
                                  ? const Color(0xFF10B981)
                                  : Colors.orange,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                // ID Info
                Row(
                  children: [
                    // Avatar with Ring
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFF59E0B),
                          width: 2,
                        ), // Gold Ring
                      ),
                      child: CircleAvatar(
                        radius: 32,
                        backgroundColor: Colors.black26,
                        backgroundImage: avatarUrl != null
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: avatarUrl == null
                            ? const Icon(Icons.person, color: Colors.white)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'ID: $id',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 14,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Mini QR
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: QrImageView(
                        data: id,
                        version: QrVersions.auto,
                        size: 40,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title.toUpperCase(),
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).textTheme.bodySmall?.color,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildMenuContainer(BuildContext context, List<Widget> children) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.grey.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: children.asMap().entries.map((entry) {
          final index = entry.key;
          final widget = entry.value;
          final isLast = index == children.length - 1;

          return Column(
            children: [
              widget,
              if (!isLast)
                Divider(
                  height: 1,
                  indent: 60,
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMenuItem(
    IconData icon,
    String title, {
    String? subtitle,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: Theme.of(context).iconTheme.color),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white54
                    : Colors.black54,
              ),
            )
          : null,
      trailing:
          trailing ??
          const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
    );
  }

  Widget _buildBiometricTile(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      onTap: () => _handleBiometricToggle(l10n),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          Icons.fingerprint_rounded,
          size: 20,
          color: Theme.of(context).iconTheme.color,
        ),
      ),
      title: Text(
        l10n.biometricLabel,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      subtitle: _isBiometricLoading
          ? const SizedBox(
              height: 13,
              width: 50,
              child: LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                minHeight: 1,
              ),
            )
          : Text(
              _isBiometricEnabled ? l10n.commonEnabled : l10n.commonDisabled,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white54
                    : Colors.black54,
              ),
            ),
      trailing: _isBiometricLoading
          ? const SizedBox(
              width: 40,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                  ),
                ),
              ),
            )
          : Switch.adaptive(
              value: _isBiometricEnabled,
              activeTrackColor: const Color(0xFF10B981),
              onChanged: _isBiometricAvailable && !_isProcessingToggle
                  ? (v) => _handleBiometricToggle(l10n)
                  : null,
            ),
    );
  }

  Future<void> _handleBiometricToggle(AppLocalizations l10n) async {
    if (_isProcessingToggle) return;

    if (!_isBiometricAvailable) {
      PayNotify.error(context, l10n.biometricNotAvailable);
      return;
    }

    // 🔒 World-Class Security: Gating Biometric Settings with PIN
    _showPinVerificationSheet(l10n, () async {
      try {
        setState(() => _isProcessingToggle = true);

        final newState = !_isBiometricEnabled;
        await _saveBiometricState(newState);

        if (!mounted) return;

        setState(() {
          _isBiometricEnabled = newState;
        });

        PayNotify.success(context, l10n.biometricSettingsUpdated);
      } catch (e) {
        if (!mounted) return;
        PayNotify.error(context, ErrorTranslator.translate(l10n, e.toString()));
      } finally {
        if (mounted) {
          setState(() => _isProcessingToggle = false);
        }
      }
    });
  }

  void _showPinVerificationSheet(
    AppLocalizations l10n,
    VoidCallback onVerified,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              l10n.biometricConfirmManage,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Please verify your PIN to continue.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: PinEntryWidget(
                onSuccess: (pin) {
                  Navigator.pop(context);
                  onVerified();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
