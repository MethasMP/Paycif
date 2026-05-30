import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:frontend/l10n/generated/app_localizations.dart';
import '../widgets/paycif_text.dart';
import '../theme/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: Text(l10n.privacyPolicy), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                      : [const Color(0xFF10B981), const Color(0xFF059669)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      PhosphorIcons.shield,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PaycifText(
                          l10n.privacyPolicy,
                          style: PaycifTextStyle.h2,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                        SizedBox(height: 4),
                        PaycifText(
                          l10n.privacyLastUpdated,
                          style: PaycifTextStyle.caption,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 24),

            // Privacy highlights
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        PhosphorIcons.shield,
                        color: Color(0xFFF59E0B),
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      PaycifText(
                        l10n.privacyHighlightsTitle,
                        style: PaycifTextStyle.body,
                        color: AppTheme.textPrimaryColor(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  _buildHighlightItem(context, l10n.privacyHighlight1, isDark),
                  _buildHighlightItem(context, l10n.privacyHighlight2, isDark),
                  _buildHighlightItem(context, l10n.privacyHighlight3, isDark),
                  _buildHighlightItem(context, l10n.privacyHighlight4, isDark),
                ],
              ),
            ),

            SizedBox(height: 24),

            // Privacy Sections
            _buildSection(
              context,
              l10n.privacySection1Title,
              l10n.privacySection1Content,
              PhosphorIcons.database,
              isDark,
            ),
            _buildSection(
              context,
              l10n.privacySection2Title,
              l10n.privacySection2Content,
              PhosphorIcons.hardDrive,
              isDark,
            ),
            _buildSection(
              context,
              l10n.privacySection3Title,
              l10n.privacySection3Content,
              PhosphorIcons.share,
              isDark,
            ),
            _buildSection(
              context,
              l10n.privacySection4Title,
              l10n.privacySection4Content,
              PhosphorIcons.shield,
              isDark,
            ),
            _buildSection(
              context,
              l10n.privacySection5Title,
              l10n.privacySection5Content,
              PhosphorIcons.person,
              isDark,
            ),

            SizedBox(height: 24),

            // Contact Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PaycifText(
                    l10n.privacyContactTitle,
                    style: PaycifTextStyle.body,
                    color: AppTheme.textPrimaryColor(context),
                    fontWeight: FontWeight.w600,
                  ),
                  SizedBox(height: 8),
                  PaycifText(
                    l10n.privacyContactContent,
                    style: PaycifTextStyle.caption,
                    color: AppTheme.textSecondaryColor(context),
                  ),
                  SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          PhosphorIcons.envelope,
                          size: 16,
                          color: Color(0xFF10B981),
                        ),
                        SizedBox(width: 6),
                        PaycifText(
                          'privacy@paycif.com',
                          style: PaycifTextStyle.caption,
                          color: const Color(0xFF10B981),
                          fontWeight: FontWeight.w600,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightItem(BuildContext context, String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            PhosphorIcons.checkCircle,
            color: Color(0xFF10B981),
            size: 18,
          ),
          SizedBox(width: 8),
          Expanded(
            child: PaycifText(
              text,
              style: PaycifTextStyle.caption,
              color: AppTheme.textSecondaryColor(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    String content,
    IconData icon,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.grey.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: const Color(0xFF10B981)),
              ),
              SizedBox(width: 12),
              Expanded(
                child: PaycifText(
                  title,
                  style: PaycifTextStyle.body,
                  color: AppTheme.textPrimaryColor(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          PaycifText(
            content,
            style: PaycifTextStyle.body,
            color: AppTheme.textSecondaryColor(context),
          ),
        ],
      ),
    );
  }
}
