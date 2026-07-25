import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/utils/app_notification_toast.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/core/network/api_service.dart';
import 'package:frontend/core/l10n/generated/app_localizations.dart';
import 'package:local_auth/local_auth.dart';
import 'package:frontend/core/utils/theme_notifier.dart';
import 'package:frontend/core/utils/language_notifier.dart';
import 'package:frontend/core/utils/error_translator.dart';
import 'package:frontend/features/security/presentation/widgets/pin_entry_widget.dart';
import 'package:frontend/features/security/presentation/widgets/change_pin_sheet.dart';
import 'package:frontend/features/security/presentation/logic/security_controller.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/app_icon.dart';

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
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor(context)),
                ),
                SizedBox(height: 24),
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
        HapticFeedback.mediumImpact();
        context.go('/login');
      }
    } catch (e) {
      debugPrint('🚨 Sign Out Disaster: $e');
      if (mounted) {
        Navigator.pop(context); // Close loading
        AppNotificationToast.error(
          context,
          AppLocalizations.of(context)!.profileSignOutCriticalError,
        );
      }
    }
  }

  void _showSignOutConfirmation(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curve = Curves.easeInOut.transform(anim1.value);
        return Transform.scale(
          scale: 0.9 + (0.1 * curve),
          child: Opacity(
            opacity: anim1.value,
            child: AlertDialog(
              backgroundColor: isDark ? theme.cardColor : Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : AppTheme.borderGrey,
                  width: 1,
                ),
              ),
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              title: Text(
                l10n.signOutConfirmTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
              content: Text(
                l10n.signOutConfirmMessage,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.8),
                ),
              ),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: TextButton.styleFrom(
                            backgroundColor: isDark
                                ? Colors.white.withValues(alpha: 0.04)
                                : AppTheme.borderGrey.withValues(alpha: 0.3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            l10n.commonCancel,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimaryColor(context),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _signOut();
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: isDark
                                ? AppTheme.errorRed.withValues(alpha: 0.15)
                                : AppTheme.errorRed.withValues(alpha: 0.1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            l10n.signOut,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.errorRedText,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLanguageSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : AppTheme.borderGrey,
              width: 1,
            ),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Premium Drag Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : AppTheme.borderGrey.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                l10n.language,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  letterSpacing: -0.5,
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
              const SizedBox(height: 16),
              ...LanguageNotifier.supportedLocales.map((locale) {
                final isSelected = languageNotifier.value == locale;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark ? Colors.white.withValues(alpha: 0.04) : AppTheme.primaryTealLight.withValues(alpha: 0.4))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? (isDark ? Colors.white.withValues(alpha: 0.08) : AppTheme.primaryTeal.withValues(alpha: 0.15))
                          : Colors.transparent,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: Text(
                      LanguageNotifier.getLanguageName(locale),
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? AppTheme.primaryColor(context)
                            : AppTheme.textPrimaryColor(context),
                      ),
                    ),
                    trailing: isSelected
                        ? const AppIcon(
                            PhosphorIcons.circleWavyCheck,
                            color: AppTheme.successGreen,
                            size: AppIconSize.sm,
                          )
                        : null,
                    onTap: () {
                      languageNotifier.value = locale;
                      Navigator.pop(context);
                    },
                  ),
                );
              }),
            ],
          ),
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

    final String kycStatus = _profile?['kyc_status'] ?? 'PENDING';
    final bool isVerified = kycStatus.toUpperCase() == 'VERIFIED';
    
    // Fetch OAuth Profile Image from user metadata
    final user = _supabase.auth.currentUser;
    final String? avatarUrl = user?.userMetadata?['avatar_url'] ?? user?.userMetadata?['picture'];
    final String email = _profile?['email'] ?? user?.email ?? '';
    final String fullName = _profile?['full_name'] ?? _profile?['username'] ?? user?.userMetadata?['full_name'] ?? 'User';

    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.profileTitle),
        leading: canPop
            ? IconButton(
                icon: AppIcon(
                  PhosphorIcons.caretLeft,
                  color: AppTheme.textPrimaryColor(context),
                  size: AppIconSize.md,
                ),
                onPressed: () => Navigator.of(context).pop(),
              )
            : (GoRouterState.of(context).uri.path == '/profile'
                ? IconButton(
                    icon: AppIcon(
                      PhosphorIcons.house,
                      color: AppTheme.textPrimaryColor(context),
                      size: AppIconSize.md,
                    ),
                    onPressed: () => context.go('/main'),
                  )
                : null),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // ─── USER PROFILE CARD HEADER ────────────────────────
            // Flat-at-Rest: separation comes from the border + tonal step off
            // canvas, never an idle shadow (design.md §4).
            // ─── USER PROFILE HEADER ────────────────────────
            // Borderless asymmetric hero block for a premium, custom visual hierarchy
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
              child: Row(
                children: [
                  // Premium Avatar Container (72x72)
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.04)
                          : AppTheme.primaryTealLight,
                      border: Border.all(
                        color: theme.brightness == Brightness.dark
                            ? Colors.white.withValues(alpha: 0.08)
                            : AppTheme.primaryTeal.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                    child: ClipOval(
                      child: avatarUrl != null
                          ? Image.network(
                              avatarUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => AppIcon(
                                PhosphorIcons.user,
                                size: AppIconSize.lg,
                                color: AppTheme.primaryColor(context),
                              ),
                            )
                          : AppIcon(
                              PhosphorIcons.user,
                              size: AppIconSize.lg,
                              color: AppTheme.primaryColor(context),
                            ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  // User Details Column (Asymmetric & Breathable)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                fullName,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                  color: AppTheme.textPrimaryColor(context),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isVerified) ...[
                              const SizedBox(width: 6),
                              Tooltip(
                                message: l10n.profileVerifiedBadge,
                                child: const AppIcon(
                                  PhosphorIcons.shieldCheck,
                                  size: AppIconSize.sm,
                                  color: AppTheme.successGreen,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ─── KYC ACTION CARD (Show only if not verified) ───────
            if (!isVerified) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark
                      ? AppTheme.stateWarningSubtleDark
                      : AppTheme.stateWarningSubtleLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.stateWarning.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const AppIcon(PhosphorIcons.warningCircle, color: AppTheme.stateWarning, size: AppIconSize.sm),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.profileKycRequiredTitle,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.stateWarning,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.profileKycRequiredMessage,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondaryColor(context),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: ElevatedButton(
                        onPressed: () async {
                          final verified = await context.push<bool>('/kyc');
                          if (verified == true && mounted) _fetchProfile();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryTeal,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(l10n.profileVerifyNowCta, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // ─── Group 1: Payment ────────────────────────────────
            // Moved off the bottom nav bar (Session 002): card management is
            // an occasional action, not a daily one, unlike Home/History/Scan.
            _buildSectionHeader(context, l10n.paymentSettingsTitle),
            const SizedBox(height: 8),
            _buildMenuContainer(context, [
              _buildMenuItem(
                context: context,
                icon: PhosphorIcons.cardsThree,
                title: l10n.paymentSettingsTitle,
                subtitle: l10n.homeActionCards,
                onTap: () => context.push('/payment_settings'),
              ),
            ]),

            const SizedBox(height: 24),

            // ─── Group 2: Security & Safety ─────────────────────────
            _buildSectionHeader(context, l10n.accountSecurity),
            const SizedBox(height: 8),
            _buildMenuContainer(context, [
              _buildBiometricTile(context, l10n),
              _buildMenuItem(
                context: context,
                icon: PhosphorIcons.lock,
                title: l10n.changePin,
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
                context: context,
                icon: PhosphorIcons.devices,
                title: l10n.linkedDevices,
                onTap: () => context.push('/linked_devices'),
              ),
            ]),

            const SizedBox(height: 24),

            // ─── Group 3: Preferences ─────────────────────────────
            _buildSectionHeader(context, l10n.preferences),
            const SizedBox(height: 8),
            _buildMenuContainer(context, [
              // Dark Mode Toggle
              ValueListenableBuilder<ThemeMode>(
                valueListenable: themeNotifier,
                builder: (context, currentMode, _) {
                  final isDarkMode = currentMode == ThemeMode.dark;
                  return _buildMenuItem(
                    context: context,
                    icon: isDarkMode ? PhosphorIcons.moon : PhosphorIcons.sun,
                    title: isDarkMode ? l10n.darkMode : l10n.lightMode,
                    onTap: () {
                      themeNotifier.value = isDarkMode
                          ? ThemeMode.light
                          : ThemeMode.dark;
                    },
                    trailing: Transform.scale(
                      scale: 0.85,
                      child: Switch.adaptive(
                        value: isDarkMode,
                        activeTrackColor: AppTheme.primaryColor(context),
                        onChanged: (val) {
                          themeNotifier.value = val
                              ? ThemeMode.dark
                              : ThemeMode.light;
                        },
                      ),
                    ),
                  );
                },
              ),
              _buildMenuItem(
                context: context,
                icon: PhosphorIcons.globe,
                title: l10n.language,
                subtitle: LanguageNotifier.getLanguageName(
                  languageNotifier.value,
                ),
                onTap: () => _showLanguageSheet(context),
              ),
              _buildMenuItem(
                context: context,
                icon: PhosphorIcons.bell,
                title: l10n.notifications,
                onTap: () => context.push('/notification_settings'),
              ),
            ]),

            const SizedBox(height: 24),

            // ─── Group 4: Help & Support ───────────────────────────
            _buildSectionHeader(context, l10n.support),
            const SizedBox(height: 8),
            _buildMenuContainer(context, [
              _buildMenuItem(
                context: context,
                icon: PhosphorIcons.question,
                title: l10n.helpCenter,
                onTap: () => context.push('/help'),
              ),
              _buildMenuItem(
                context: context,
                icon: PhosphorIcons.chat,
                title: l10n.contactSupport,
                onTap: () => context.push('/contact_support'),
              ),
            ]),

            const SizedBox(height: 32),

            // ─── Footer Section: Inline Legal Links & Version ──────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => context.push('/terms'),
                  child: Text(
                    l10n.termsOfService,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondaryColor(context),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                Text(
                  '  •  ',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondaryColor(context),
                  ),
                ),
                GestureDetector(
                  onTap: () => context.push('/privacy'),
                  child: Text(
                    l10n.privacyPolicy,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondaryColor(context),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),

            // ─── Sign Out Button ───────────────────────────────────
            _buildMenuContainer(context, [
              _buildMenuItem(
                context: context,
                icon: PhosphorIcons.signOut,
                title: l10n.signOut,
                titleColor: theme.brightness == Brightness.dark
                    ? AppTheme.errorRed.withValues(alpha: 0.8)
                    : AppTheme.errorRedText,
                iconColor: theme.brightness == Brightness.dark
                    ? AppTheme.errorRed.withValues(alpha: 0.8)
                    : AppTheme.errorRedText,
                trailing: const SizedBox.shrink(),
                onTap: () => _showSignOutConfirmation(context),
              ),
            ]),

            const SizedBox(height: 16),

            Center(
              child: Text(
                '${l10n.version} 2.0.0 (Build 42)',
                style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textSecondaryColor(context)),
              ),
            ),
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }


  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.6,
          color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.6),
        ),
      ),
    );
  }

  Widget _buildMenuContainer(BuildContext context, List<Widget> children) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AppTheme.borderGrey,
        ),
      ),
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
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
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : AppTheme.borderGrey.withValues(alpha: 0.4),
                ),
            ],
          );
        }).toList(),
      ),
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Widget? trailing,
    Color? titleColor,
    Color? iconColor,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      horizontalTitleGap: 12,
      leading: AppIcon(
        icon,
        size: AppIconSize.md,
        color: iconColor ?? AppTheme.textSecondaryColor(context).withValues(alpha: 0.75),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: titleColor ?? AppTheme.textPrimaryColor(context),
            ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.8),
                  ),
            )
          : null,
      trailing:
          trailing ??
          AppIcon(PhosphorIcons.caretRight, color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.35), size: AppIconSize.xs),
    );
  }

  Widget _buildBiometricTile(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      onTap: () => _handleBiometricToggle(l10n),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      horizontalTitleGap: 12,
      leading: AppIcon(
        PhosphorIcons.fingerprint,
        size: AppIconSize.md,
        color: AppTheme.textSecondaryColor(context),
      ),
      title: Text(
        l10n.biometricLabel,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryColor(context),
            ),
      ),
      subtitle: _isBiometricLoading
          ? SizedBox(
              height: 13,
              width: 50,
              child: LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.textSecondaryColor(context)),
                minHeight: 1,
              ),
            )
          : Text(
              _isBiometricEnabled ? l10n.commonEnabled : l10n.commonDisabled,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondaryColor(context),
                  ),
            ),
      trailing: _isBiometricLoading
          ? SizedBox(
              width: 40,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.textSecondaryColor(context)),
                  ),
                ),
              ),
            )
          : Transform.scale(
              scale: 0.85,
              child: Switch.adaptive(
                value: _isBiometricEnabled,
                activeTrackColor: AppTheme.successGreen,
                onChanged: _isBiometricAvailable && !_isProcessingToggle
                    ? (v) => _handleBiometricToggle(l10n)
                    : null,
              ),
            ),
    );
  }

  Future<void> _handleBiometricToggle(AppLocalizations l10n) async {
    if (_isProcessingToggle) return;

    if (!_isBiometricAvailable) {
      AppNotificationToast.error(context, l10n.biometricNotAvailable);
      return;
    }

    // 🔒 World-Class Security: Gating Biometric Settings with PIN
    _showPinVerificationSheet(l10n, () async {
      try {
        // Read controller before any async operations
        final securityController = context.read<SecurityController>();
        
        setState(() => _isProcessingToggle = true);

        final newState = !_isBiometricEnabled;
        await _saveBiometricState(newState);

        if (!mounted) return;

        setState(() {
          _isBiometricEnabled = newState;
        });

        // 🚀 CRITICAL: Re-bind device immediately to rotate keys based on new preference!
        await securityController.bindDevice();

        if (!mounted) return;

        HapticFeedback.lightImpact();
        AppNotificationToast.success(context, l10n.biometricSettingsUpdated);
      } catch (e) {
        if (!mounted) return;
        AppNotificationToast.error(context, ErrorTranslator.translate(l10n, e.toString()));
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
            SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.borderGrey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 32),
            Text(
              l10n.biometricConfirmManage,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryColor(context),
                  ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              l10n.biometricPinPrompt,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondaryColor(context),
                  ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: PinEntryWidget(
                onSubmit: (pinList) async {
                  final pin = pinList.join();
                  final securityController = context.read<SecurityController>();
                  final navigator = Navigator.of(context);
                  final success = await securityController.verifyPin(pin);
                  if (success) {
                    navigator.pop();
                    onVerified();
                    return null;
                  }
                  return 'Incorrect PIN. Try again.';
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
