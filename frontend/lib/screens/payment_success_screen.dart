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
  final String? senderName; // Added sender name
  final String? promptPayId;
  final double? remainingBalance;

  PaymentSuccessScreen({
    super.key,
    required this.transactionId,
    required this.amount,
    required this.recipientName,
    this.senderName,
    this.promptPayId,
    this.remainingBalance,
  });

  final GlobalKey _boundaryKey = GlobalKey();

  String _maskPromptPayId(String? id) {
    if (id == null) return '';
    // Clean up
    final clean = id.replaceAll(RegExp(r'[-\s]'), '');

    if (clean.length == 10) {
      // Phone: 0961234567 -> XXX-XXX-4567
      return 'XXX-XXX-${clean.substring(clean.length - 4)}';
    } else if (clean.length == 13) {
      // ID Card: Mask all but last 4
      return 'XXXXXXXXX${clean.substring(clean.length - 4)}';
    }
    return id; // Fallback
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Header with close button
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

                    // Success Animation
                    _buildSuccessIcon(isDark),

                    const SizedBox(height: 24),

                    // Success Text
                    Text(
                      'Payment Successful',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Your payment has been processed successfully',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    ),

                    const SizedBox(height: 40),

                    // Receipt Card (Saveable/Shareable Slip)
                    RepaintBoundary(
                      key: _boundaryKey,
                      child: _buildReceiptCard(
                        context,
                        isDark,
                        dateFormat.format(now),
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            // Bottom Actions
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Done Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => _navigateToHome(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Save Receipt Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: () => _saveReceipt(context),
                        icon: Icon(
                          Icons.download_rounded,
                          color: Colors.grey[600],
                        ),
                        label: Text(
                          'Save',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                      const SizedBox(width: 20),
                      TextButton.icon(
                        onPressed: () {
                          // Note: share_plus is required for full sharing functionality
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Sharing coming soon...'),
                            ),
                          );
                        },
                        icon: Icon(
                          Icons.share_rounded,
                          color: Colors.grey[600],
                        ),
                        label: Text(
                          'Share',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessIcon(bool isDark) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF059669)],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: const Icon(Icons.check_rounded, color: Colors.white, size: 56),
    );
  }

  Widget _buildReceiptCard(BuildContext context, bool isDark, String dateTime) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      child: Column(
        children: [
          // Amount
          Text(
            '฿${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),

          const SizedBox(height: 24),

          // Divider
          Divider(color: Colors.grey.withValues(alpha: 0.2)),

          const SizedBox(height: 16),

          // Details - Thai Banking Standard (ตามมาตรฐานสลิปธนาคารไทย)
          // แสดงเฉพาะข้อมูลที่จำเป็นสำหรับการยืนยันกับร้านค้า
          _buildDetailRow('ผู้รับเงิน', recipientName, isDark),
          if (promptPayId != null)
            _buildDetailRow('พร้อมเพย์', _maskPromptPayId(promptPayId), isDark),
          _buildDetailRow('วันที่/เวลา', dateTime, isDark),
          _buildDetailRow(
            'เลขที่อ้างอิง',
            _formatTransactionId(transactionId),
            isDark,
          ),
          _buildDetailRow('สถานะ', 'สำเร็จ', isDark, isStatus: true),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    bool isDark, {
    bool isStatus = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[500])),
          if (isStatus)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF10B981),
                ),
              ),
            )
          else
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatTransactionId(String id) {
    // World-Class: Show FULL reference for merchant verification
    return id;
  }

  void _navigateToHome(BuildContext context) {
    // Auto-refresh dashboard silently (Optimistic UI already handled the visuals)
    try {
      context.read<DashboardController>().refresh(showLoading: false);
    } catch (_) {
      // Dashboard controller may not be available in test context
    }

    // Pop all screens and go back to home
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _saveReceipt(BuildContext context) async {
    try {
      final RenderRepaintBoundary boundary =
          _boundaryKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData == null) return;
      final Uint8List pngBytes = byteData.buffer.asUint8List();

      final result = await ImageGallerySaverPlus.saveImage(
        pngBytes,
        quality: 100,
        name: "Paysif-Receipt-${DateTime.now().millisecondsSinceEpoch}",
      );

      if (context.mounted) {
        if (result['isSuccess'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Receipt saved to gallery!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          throw Exception(result['errorMessage'] ?? 'Save failed');
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving receipt: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
