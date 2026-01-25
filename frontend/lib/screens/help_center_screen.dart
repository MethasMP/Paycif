import 'package:flutter/material.dart';
import 'package:frontend/l10n/generated/app_localizations.dart';
import 'package:frontend/screens/contact_support_screen.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // FAQ categories with questions
    final List<_FAQCategory> categories = [
      _FAQCategory(
        icon: Icons.account_balance_wallet_outlined,
        title: l10n.helpWalletTitle,
        questions: [
          _FAQ(l10n.helpWalletQ1, l10n.helpWalletA1),
          _FAQ(l10n.helpWalletQ2, l10n.helpWalletA2),
          _FAQ(l10n.helpWalletQ3, l10n.helpWalletA3),
        ],
      ),
      _FAQCategory(
        icon: Icons.payment_outlined,
        title: l10n.helpPaymentTitle,
        questions: [
          _FAQ(l10n.helpPaymentQ1, l10n.helpPaymentA1),
          _FAQ(l10n.helpPaymentQ2, l10n.helpPaymentA2),
          _FAQ(l10n.helpPaymentQ3, l10n.helpPaymentA3),
        ],
      ),
      _FAQCategory(
        icon: Icons.security_outlined,
        title: l10n.helpSecurityTitle,
        questions: [
          _FAQ(l10n.helpSecurityQ1, l10n.helpSecurityA1),
          _FAQ(l10n.helpSecurityQ2, l10n.helpSecurityA2),
        ],
      ),
      _FAQCategory(
        icon: Icons.credit_card_outlined,
        title: l10n.helpCardTitle,
        questions: [
          _FAQ(l10n.helpCardQ1, l10n.helpCardA1),
          _FAQ(l10n.helpCardQ2, l10n.helpCardA2),
        ],
      ),
    ];

    // Filter based on search
    final filteredCategories = _searchQuery.isEmpty
        ? categories
        : categories
              .map((cat) {
                final filteredQuestions = cat.questions
                    .where(
                      (q) =>
                          q.question.toLowerCase().contains(
                            _searchQuery.toLowerCase(),
                          ) ||
                          q.answer.toLowerCase().contains(
                            _searchQuery.toLowerCase(),
                          ),
                    )
                    .toList();
                return _FAQCategory(
                  icon: cat.icon,
                  title: cat.title,
                  questions: filteredQuestions,
                );
              })
              .where((cat) => cat.questions.isNotEmpty)
              .toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: Text(l10n.helpCenter), centerTitle: true),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: l10n.helpSearchHint,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),

          // FAQ List
          Expanded(
            child: filteredCategories.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.helpNoResults,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredCategories.length,
                    itemBuilder: (context, index) {
                      final category = filteredCategories[index];
                      return _buildCategorySection(context, category, isDark);
                    },
                  ),
          ),

          // Still need help section
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                    : [const Color(0xFF667EEA), const Color(0xFF764BA2)],
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
                  child: const Icon(
                    Icons.headset_mic_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.helpStillNeedHelp,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.helpContactTeam,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ContactSupportScreen(),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(
    BuildContext context,
    _FAQCategory category,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  category.icon,
                  color: const Color(0xFFF59E0B),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                category.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Container(
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
            children: category.questions.asMap().entries.map((entry) {
              final isLast = entry.key == category.questions.length - 1;
              return Column(
                children: [
                  _buildFAQTile(entry.value, isDark),
                  if (!isLast)
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: Theme.of(
                        context,
                      ).dividerColor.withValues(alpha: 0.3),
                    ),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildFAQTile(_FAQ faq, bool isDark) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(
          faq.question,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        children: [
          Text(
            faq.answer,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.black54,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _FAQCategory {
  final IconData icon;
  final String title;
  final List<_FAQ> questions;

  _FAQCategory({
    required this.icon,
    required this.title,
    required this.questions,
  });
}

class _FAQ {
  final String question;
  final String answer;

  _FAQ(this.question, this.answer);
}
