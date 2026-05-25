import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:provider/provider.dart';
import '../controllers/dashboard_controller.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final now = DateTime.now();
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
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
                    const SizedBox(height: 20),
                    _buildSuccessIcon(theme),
                    const SizedBox(height: 24),
                    Text(
                      'Payment Successful',
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your payment has been processed successfully',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                    ),
                    const SizedBox(height: 40),
                    RepaintBoundary(
                      key: _boundaryKey,
                      child: _buildReceiptCard(context, isDark, dateFormat.format(now)),
                    ),
                    const SizedBox(height: 40),
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
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: const Color(0xFF10B981),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withOpacity(0.3),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: const Icon(Icons.check_rounded, color: Colors.white, size: 56),
    );
  }

  Widget _buildReceiptCard(BuildContext context, bool isDark, String dateTime) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.primaryColor.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Text(
            '฿${amount.toStringAsFixed(2)}',
            style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          _buildDetailRow('Recipient', recipientName, theme),
          if (promptPayId != null) _buildDetailRow('PromptPay', promptPayId!, theme),
          _buildDetailRow('Date/Time', dateTime, theme),
          _buildDetailRow('Reference ID', transactionId, theme),
          _buildDetailRow('Status', 'Success', theme, isStatus: true),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, ThemeData theme, {bool isStatus = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
          if (isStatus)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Success',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
              ),
            )
          else
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
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
