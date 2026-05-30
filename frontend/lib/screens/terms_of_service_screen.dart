import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:frontend/l10n/generated/app_localizations.dart';
import '../widgets/paycif_text.dart';
import '../theme/app_theme.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: Text(l10n.termsOfService), centerTitle: true),
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
                      : [const Color(0xFF1A1F71), const Color(0xFF2C3E50)],
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
                      PhosphorIcons.fileText,
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
                          l10n.termsOfService,
                          style: PaycifTextStyle.h2,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                        SizedBox(height: 4),
                        PaycifText(
                          l10n.termsLastUpdated,
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

            // Terms Sections
            _buildSection(
              context,
              l10n.termsSection1Title,
              l10n.termsSection1Content,
              isDark,
            ),
            _buildSection(
              context,
              l10n.termsSection2Title,
              l10n.termsSection2Content,
              isDark,
            ),
            _buildSection(
              context,
              l10n.termsSection3Title,
              l10n.termsSection3Content,
              isDark,
            ),
            _buildSection(
              context,
              l10n.termsSection4Title,
              l10n.termsSection4Content,
              isDark,
            ),
            _buildSection(
              context,
              l10n.termsSection5Title,
              l10n.termsSection5Content,
              isDark,
            ),
            _buildSection(
              context,
              l10n.termsSection6Title,
              l10n.termsSection6Content,
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
              child: Row(
                children: [
                  Icon(
                    PhosphorIcons.info,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: PaycifText(
                      l10n.termsContact,
                      style: PaycifTextStyle.caption,
                      color: AppTheme.textSecondaryColor(context),
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

  Widget _buildSection(
    BuildContext context,
    String title,
    String content,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
          PaycifText(
            title,
            style: PaycifTextStyle.body,
            color: AppTheme.textPrimaryColor(context),
            fontWeight: FontWeight.w600,
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
