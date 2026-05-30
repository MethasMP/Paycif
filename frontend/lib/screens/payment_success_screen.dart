import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../controllers/dashboard_controller.dart';
import '../widgets/paycif_amount_text.dart';
import '../theme/app_theme.dart';

class PaymentSuccessScreen extends StatelessWidget {
  final String transactionId;
  final double amount;
  final String recipientName;
  final String? promptPayId;

  PaymentSuccessScreen({
    super.key,
    required this.transactionId,
    required this.amount,
    required this.recipientName,
    this.promptPayId,
  });

  final GlobalKey _boundaryKey = GlobalKey();

  static const _thShortMonths = [
    'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
    'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? theme.scaffoldBackgroundColor : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: Icon(PhosphorIcons.x, color: AppTheme.textPrimaryColor(context)),
                    onPressed: () => _navigateToHome(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    SizedBox(height: 20),
                    _buildSuccessIcon(theme),
                    SizedBox(height: 24),
                    Text(
                      'Payment Successful',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryColor(context),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Your payment has been processed successfully',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondaryColor(context),
                      ),
                    ),
                    SizedBox(height: 40),
                    RepaintBoundary(
                      key: _boundaryKey,
                      child: _buildReceiptCard(context, isDark),
                    ),
                    SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => _navigateToHome(context),
                  child: const Text('Done'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessIcon(ThemeData theme) {
    final successColor = theme.brightness == Brightness.dark
        ? const Color(0xFF2BBF9E)
        : const Color(0xFF0F6E56);
    return Icon(
      PhosphorIcons.checkCircle,
      color: successColor, // primary-600
      size: 64, // 64px check icon
    );
  }

  Widget _buildReceiptCard(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final enDate = DateFormat('dd MMM yyyy').format(now);
    final enTime = DateFormat('HH:mm').format(now);
    final enDateVal = "$enDate, $enTime";

    final thMonth = _thShortMonths[now.month - 1];
    final thBuddhistYear = (now.year + 543) % 100;
    final thDateVal = "${now.day} $thMonth $thBuddhistYear, $enTime";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? theme.cardColor : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE5E5E3)), // border token
      ),
      child: Column(
        children: [
          PaycifAmountText(
            amount: amount,
            style: theme.textTheme.displayLarge, // Amount 32px
          ),
          SizedBox(height: 24),
          const Divider(color: Color(0xFFE5E5E3), height: 1),
          SizedBox(height: 16),
          _buildBilingualDetailRow(
            context,
            englishLabel: 'Recipient',
            thaiLabel: 'ผู้รับเงิน',
            englishValue: recipientName,
            thaiValue: '',
            theme: theme,
          ),
          if (promptPayId != null)
            _buildBilingualDetailRow(
              context,
              englishLabel: 'PromptPay',
              thaiLabel: 'พร้อมเพย์',
              englishValue: promptPayId!,
              thaiValue: '',
              theme: theme,
            ),
          _buildBilingualDetailRow(
            context,
            englishLabel: 'Date/Time',
            thaiLabel: 'วันที่/เวลา',
            englishValue: enDateVal,
            thaiValue: thDateVal,
            theme: theme,
          ),
          _buildBilingualDetailRow(
            context,
            englishLabel: 'Reference ID',
            thaiLabel: 'รหัสอ้างอิง',
            englishValue: transactionId,
            thaiValue: '',
            theme: theme,
          ),
          _buildBilingualDetailRow(
            context,
            englishLabel: 'Status',
            thaiLabel: 'สถานะ',
            englishValue: 'Success',
            thaiValue: 'สำเร็จ',
            theme: theme,
            isStatus: true,
          ),
        ],
      ),
    );
  }

  Widget _buildBilingualDetailRow(
    BuildContext context, {
    required String englishLabel,
    required String thaiLabel,
    required String englishValue,
    required String thaiValue,
    required ThemeData theme,
    bool isStatus = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Labels (EN/TH stacked)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                englishLabel,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500, // EN 14px medium
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
              SizedBox(height: 2),
              Text(
                thaiLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w400, // TH 12px regular below
                  color: AppTheme.textSecondaryColor(context),
                ),
              ),
            ],
          ),
          // Values (EN/TH stacked or aligned right)
          if (isStatus)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE1F5EE), // primary-100
                borderRadius: BorderRadius.circular(999), // pill
              ),
              child: Text(
                'Success',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0F6E56),
                ),
              ),
            )
          else
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    englishValue,
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimaryColor(context),
                    ),
                  ),
                  if (thaiValue.isNotEmpty) ...[
                    SizedBox(height: 2),
                    Text(
                      thaiValue,
                      textAlign: TextAlign.right,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w400,
                        color: AppTheme.textSecondaryColor(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _navigateToHome(BuildContext context) {
    try {
      context.read<DashboardController>().refresh();
    } catch (_) {}
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}
