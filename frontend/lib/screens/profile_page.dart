import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'login_screen.dart'; // For redirection after logout
import 'package:frontend/l10n/generated/app_localizations.dart';
import '../utils/theme_notifier.dart';
import '../utils/language_notifier.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
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
    await _supabase.auth.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
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
              _buildMenuItem(
                Icons.fingerprint,
                l10n.biometricLogin,
                subtitle: l10n.commonEnabled,
                isToggle: true,
              ),
              _buildMenuItem(Icons.lock_outline, l10n.changePin),
              _buildMenuItem(Icons.devices, l10n.linkedDevices),
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
              _buildMenuItem(Icons.notifications_outlined, l10n.notifications),
            ]),

            const SizedBox(height: 32),

            // ─── Support ───────────────────────────────────────────
            _buildSectionHeader(context, l10n.support),
            const SizedBox(height: 16),
            _buildMenuContainer(context, [
              _buildMenuItem(Icons.help_outline, l10n.helpCenter),
              _buildMenuItem(Icons.chat_bubble_outline, l10n.contactSupport),
            ]),

            const SizedBox(height: 48),

            // ─── Sign Out ──────────────────────────────────────────
            Center(
              child: TextButton(
                onPressed: _signOut,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  foregroundColor: Colors.redAccent,
                ),
                child: Text(
                  l10n.signOut,
                  style: const TextStyle(fontWeight: FontWeight.w600),
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
                  const Color(0xFF1E1B4B),
                  const Color(0xFF312E81),
                ] // Indigo 950 -> 900
              : [
                  const Color(0xFF312E81),
                  const Color(0xFF4338CA),
                ], // Indigo 900 -> 700
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF312E81).withValues(alpha: 0.4),
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
                    // Verification Badge
                    if (isVerified)
                      const Icon(
                        Icons.verified,
                        color: Color(0xFF10B981),
                        size: 24,
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
    bool isToggle = false,
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
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            )
          : null,
      trailing:
          trailing ??
          (isToggle
              ? Switch.adaptive(
                  value: true,
                  activeTrackColor: const Color(0xFF10B981),
                  onChanged: (v) {},
                )
              : const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey,
                  size: 20,
                )),
    );
  }
}
