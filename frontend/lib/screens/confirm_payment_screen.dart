import 'dart:math';
import 'dart:ui' as ui;
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:local_auth/local_auth.dart';
import 'package:frontend/l10n/generated/app_localizations.dart';
import 'package:intl/intl.dart';
import '../utils/error_translator.dart';
import '../utils/pay_notify.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/api_service.dart';
import 'package:uuid/uuid.dart';
import '../features/security/domain/repositories/security_repository.dart';
import 'package:provider/provider.dart';
import 'payment_success_screen.dart';

class ConfirmPaymentScreen extends StatefulWidget {
  final double amount;
  final String recipient;
  final bool isPromptPay;
  final String? promptPayId;
  final VoidCallback onConfirmed;

  const ConfirmPaymentScreen({
    super.key,
    required this.amount,
    required this.recipient,
    this.isPromptPay = false,
    this.promptPayId,
    required this.onConfirmed,
  });

  @override
  State<ConfirmPaymentScreen> createState() => _ConfirmPaymentScreenState();
}

class _ConfirmPaymentScreenState extends State<ConfirmPaymentScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  final ApiService _apiService = ApiService();

  double _slidePosition = 0.0;
  bool _isProcessing = false;
  String _selectedPaymentMethod = 'card_default'; // Pay per use: Default to linked card

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      await auth.canCheckBiometrics;
    } catch (e) {
      debugPrint('Error checking biometrics: $e');
    }
  }

  Future<void> _authenticate() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isProcessing = true);

    try {
      final authenticated = await auth.authenticate(
        localizedReason: 'Confirm payment of ฿${NumberFormat('#,##0.00').format(widget.amount)}',
        options: const AuthenticationOptions(biometricOnly: true),
      );

      if (authenticated) {
        HapticFeedback.heavyImpact();
        await _executePayment();
      } else {
        setState(() {
          _slidePosition = 0.0;
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() {
        _slidePosition = 0.0;
        _isProcessing = false;
      });
      PayNotify.error(context, ErrorTranslator.translate(l10n, e.toString()));
    }
  }

  Future<void> _executePayment() async {
    final l10n = AppLocalizations.of(context)!;
    final securityRepo = context.read<SecurityRepository>();
    try {
      final idempotencyKey = const Uuid().v4();
      final signatureHeaders = await securityRepo.generateSignatureHeaders(idempotencyKey);

      final result = await _apiService.executePayout(
        walletId: 'pay_per_use_gateway', // Special ID for pay per use
        amountSatang: widget.amount * 100,
        targetType: widget.isPromptPay ? 'MOBILE' : 'EWALLET',
        targetValue: widget.promptPayId ?? widget.recipient,
        idempotencyKey: idempotencyKey,
        description: "Payment to ${widget.recipient}",
        headers: signatureHeaders,
      );

      if (result['success'] == true && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentSuccessScreen(
              transactionId: result['transaction_id'] as String,
              amount: widget.amount,
              recipientName: widget.recipient,
              promptPayId: widget.promptPayId,
            ),
          ),
        );
      } else {
        throw Exception(result['error'] ?? "Payment failed");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _slidePosition = 0.0;
          _isProcessing = false;
        });
        PayNotify.error(context, ErrorTranslator.translate(l10n, e.toString()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currencyFormat = NumberFormat('#,##0.00');

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Confirm Payment"),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              _buildAmountCard(theme, isDark, currencyFormat),
              const SizedBox(height: 24),
              _buildPaymentMethodSection(theme, isDark),
              const SizedBox(height: 24),
              _buildRecipientSection(theme, isDark),
              const Spacer(),
              _buildSlideToPay(),
              const SizedBox(height: 16),
              const Text(
                "Secure payment powered by Paycif",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmountCard(ThemeData theme, bool isDark, NumberFormat format) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF085041) : const Color(0xFF0F6E56),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Text("Amount to Pay", style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          Text(
            "฿${format.format(widget.amount)}",
            style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSection(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Payment Method", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.primaryColor.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              const Icon(Icons.credit_card, color: Color(0xFFEF9F27)),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Linked Visa Card", style: TextStyle(fontWeight: FontWeight.w600)),
                    Text("**** 8899", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text("Change", style: TextStyle(color: Color(0xFFEF9F27))),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecipientSection(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Recipient", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: theme.primaryColor.withOpacity(0.1),
                child: Text(widget.recipient[0], style: TextStyle(color: theme.primaryColor)),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.recipient, style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (widget.promptPayId != null)
                    Text(widget.promptPayId!, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSlideToPay() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFFEF9F27).withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Stack(
        children: [
          const Center(
            child: Text(
              "Slide to Pay",
              style: TextStyle(color: Color(0xFFEF9F27), fontWeight: FontWeight.bold),
            ),
          ),
          Positioned(
            left: _slidePosition,
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                if (_isProcessing) return;
                setState(() {
                  _slidePosition = max(0, min(details.localPosition.dx, 250));
                });
              },
              onHorizontalDragEnd: (details) {
                if (_slidePosition > 200) {
                  _authenticate();
                } else {
                  setState(() => _slidePosition = 0);
                }
              },
              child: Container(
                width: 56,
                height: 56,
                margin: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Color(0xFFEF9F27),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_forward_ios, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
