import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/payment/presentation/logic/payment_cubit.dart';
import 'package:frontend/features/payment/presentation/logic/payment_state.dart';
import 'package:frontend/features/security/domain/repositories/security_repository.dart';
import 'package:frontend/features/payment/data/repositories/payment_repository_impl.dart';
import 'package:frontend/core/network/api_service.dart';
import 'package:frontend/core/l10n/generated/app_localizations.dart';
import 'package:frontend/core/widgets/paycif_amount_text.dart';
import 'package:frontend/core/widgets/paycif_icon_container.dart';
import 'package:frontend/core/widgets/virtual_keypad.dart';
import 'package:frontend/core/widgets/kyc/swipe_to_pay_slider.dart';
import 'package:frontend/features/payment/data/qr_aggregator_service.dart';
import 'package:frontend/features/payment/domain/entities/payment_breakdown.dart';
import 'package:frontend/features/dashboard/presentation/dashboard_controller.dart';
import 'package:go_router/go_router.dart';

enum UnifiedSheetStep { amountInput, preview, polling, success, failure }

class UnifiedPaymentSheet extends StatefulWidget {
  final PaymentContext payContext;

  const UnifiedPaymentSheet({super.key, required this.payContext});

  @override
  State<UnifiedPaymentSheet> createState() => _UnifiedPaymentSheetState();
}

class _UnifiedPaymentSheetState extends State<UnifiedPaymentSheet> {
  late UnifiedSheetStep _step;
  final TextEditingController _amountController = TextEditingController();

  String? _lookupName;
  bool _isLookingUp = false;
  double _customAmount = 0.0;
  String _failureMessage = '';

  @override
  void initState() {
    super.initState();
    final hasAmount = (widget.payContext.amount ?? 0) > 0;
    _step = hasAmount ? UnifiedSheetStep.preview : UnifiedSheetStep.amountInput;
    _customAmount = widget.payContext.amount ?? 0.0;
    _amountController.text = hasAmount ? _customAmount.toStringAsFixed(2) : '';
    _lookupRecipientName();
  }

  Future<void> _lookupRecipientName() async {
    if (widget.payContext.accountId == null) return;
    setState(() => _isLookingUp = true);
    try {
      final api = ApiService();
      final name = await api.lookupPromptPayName(widget.payContext.accountId!);
      if (mounted) {
        setState(() {
          _lookupName = name;
          _isLookingUp = false;
        });
      }
    } catch (e) {
      debugPrint('⚠️ [PaymentSheet] Failed to look up recipient name: $e');
      if (mounted) setState(() => _isLookingUp = false);
    }
  }

  String get _displayName {
    if (_lookupName != null && _lookupName!.isNotEmpty) {
      return _lookupName!;
    }
    return widget.payContext.title;
  }

  PaymentBreakdown get _localBreakdown => PaymentBreakdown(amountTHB: _customAmount);

  double get _feeUSD {
    try {
      final state = context.read<PaymentCubit>().state;
      if (state is PaymentReady && state.feeUSD != null) {
        return state.feeUSD!;
      }
    } catch (_) {}
    return _localBreakdown.feeUSD;
  }

  double get _totalUSD {
    try {
      final state = context.read<PaymentCubit>().state;
      if (state is PaymentReady && state.totalUSD != null) {
        return state.totalUSD!;
      }
    } catch (_) {}
    return _localBreakdown.totalUSD;
  }

  double get _exchangeRate {
    try {
      final state = context.read<PaymentCubit>().state;
      if (state is PaymentReady && state.exchangeRate != null) {
        return state.exchangeRate!;
      }
    } catch (_) {}
    return 36.45;
  }

  bool get _canGoBack {
    return _step == UnifiedSheetStep.preview && (widget.payContext.amount ?? 0) == 0;
  }

  void _handleBackPress() {
    if (_step == UnifiedSheetStep.preview) {
      setState(() => _step = UnifiedSheetStep.amountInput);
    }
  }

  void _handleKeypadInput(String key) {
    if (_step != UnifiedSheetStep.amountInput) return;
    String currentText = _amountController.text;

    if (key == '⌫') {
      if (currentText.isNotEmpty) {
        currentText = currentText.substring(0, currentText.length - 1);
      }
    } else if (key == '.') {
      if (currentText.isEmpty) {
        currentText = '0.';
      } else if (!currentText.contains('.')) {
        currentText += '.';
      }
    } else {
      if (currentText == '0') {
        currentText = key;
      } else {
        currentText += key;
      }
    }

    if (currentText.contains('.')) {
      final parts = currentText.split('.');
      if (parts[1].length > 2) return;
    }
    if (currentText.replaceAll('.', '').length > 10) return;

    setState(() {
      _amountController.text = currentText;
      _customAmount = double.tryParse(currentText) ?? 0.0;
    });
  }

  void _goToPreview(PaymentCubit cubit) {
    if (_customAmount <= 0) return;
    // Re-initialize Cubit with typed amount and fetch SQRIL Quotation
    cubit.initializeWithQR(
      qrString: widget.payContext.metadata['raw'] ?? '',
      amount: _customAmount,
    );
    setState(() {
      _step = UnifiedSheetStep.preview;
    });
  }

  bool _isInitiating = false;

  Future<void> _initiateOnRamp(PaymentCubit cubit) async {
    if (_isInitiating) return;
    _isInitiating = true;

    try {
      cubit.initiateOnRamp(
        promptPayId: widget.payContext.accountId ?? '',
        recipientName: _displayName,
        fiatCurrency: 'USD',
        billerId: widget.payContext.billerId,
        reference1: widget.payContext.reference1,
        reference2: widget.payContext.reference2,
      );
    } finally {
      _isInitiating = false;
    }
  }

  /// Opens the AlchemyPay checkout URL.
  /// iOS: in-app WebView (required for Apple Pay camera access)
  /// Android: external browser (required for Google Pay popup)
  Future<void> _launchCheckout(String webUrl, String intentId, PaymentCubit cubit) async {
    final uri = Uri.parse(webUrl);

    if (Platform.isIOS) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _AchCheckoutPage(uri: uri),
        ),
      );
      // User returned from WebView (via paycif:// redirect or close button)
      if (mounted) cubit.pollForCompletion(intentId);
    } else {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      // Android: start polling immediately since we can't intercept browser close
      if (mounted) cubit.pollForCompletion(intentId);
    }
  }

  void _handleSuccess(BuildContext context) {
    try {
      context.read<DashboardController>().refresh();
    } catch (_) {}
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BlocProvider(
      create: (context) => PaymentCubit(
        paymentRepository: PaymentRepositoryImpl(
          apiService: ApiService(),
          securityRepository: context.read<SecurityRepository>(),
        ),
      )..initializeWithQR(
          qrString: widget.payContext.metadata['raw'] ?? '',
          amount: _customAmount,
        ),
      child: BlocConsumer<PaymentCubit, PaymentState>(
        listener: (context, state) {
          if (state is PaymentSuccess) {
            Navigator.of(context).pop();
            context.push('/payment_success', extra: {
              'transactionId': state.transactionId,
              'amount': _customAmount,
              'recipientName': _displayName,
              'promptPayId': widget.payContext.accountId,
            });
          } else if (state is PaymentFailure) {
            setState(() {
              _step = UnifiedSheetStep.failure;
              _failureMessage = state.errorMessage;
            });
          } else if (state is PaymentOnRampReady) {
            _launchCheckout(state.webUrl, state.intentId, context.read<PaymentCubit>());
          } else if (state is PaymentPolling) {
            setState(() => _step = UnifiedSheetStep.polling);
          }
        },
        builder: (context, state) {
          final cubit = context.read<PaymentCubit>();

          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 16,
                left: 24,
                right: 24,
              ),
              decoration: BoxDecoration(
                color: isDark ? Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Navigation Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_canGoBack)
                        IconButton(
                          icon: Icon(
                            PhosphorIcons.caretLeft,
                            color: isDark ? Colors.white70 : Colors.black87,
                            size: 20,
                          ),
                          onPressed: _handleBackPress,
                        )
                      else if (_step == UnifiedSheetStep.amountInput || _step == UnifiedSheetStep.preview)
                        IconButton(
                          icon: Icon(
                            PhosphorIcons.x,
                            color: isDark ? Colors.white70 : Colors.black87,
                            size: 20,
                          ),
                          onPressed: () => Navigator.of(context).pop(false),
                        )
                      else
                        const SizedBox(width: 48, height: 48),
                      
                      // Grab Handle
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      
                      const SizedBox(width: 48, height: 48),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Header / Recipient View (Shown in input and failure steps; inline in preview)
                  if (_step == UnifiedSheetStep.amountInput || _step == UnifiedSheetStep.failure) ...[
                    _buildRecipientCard(isDark),
                    const SizedBox(height: 20),
                  ],

                  // Conditional Step Layouts
                  _buildStepContent(context, cubit, isDark),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecipientCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: Row(
        children: [
          const PaycifIconContainer(icon: PhosphorIcons.user, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isLookingUp)
                  Row(
                    children: [
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentGold),
                      ),
                      const SizedBox(width: 8),
                      Text('Looking up...', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                    ],
                  )
                else
                  Text(
                    _displayName,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                if (widget.payContext.accountId != null)
                  Text(
                    widget.payContext.accountId!,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const Icon(PhosphorIcons.sealCheck, color: AppTheme.successGreen, size: 20),
        ],
      ),
    );
  }

  Widget _buildStepContent(BuildContext context, PaymentCubit cubit, bool isDark) {
    final state = cubit.state;
    if (state is PaymentLoading) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(
          color: AppTheme.primaryTeal,
        ),
      );
    }

    switch (_step) {
      case UnifiedSheetStep.amountInput:
        return _buildAmountInputView(cubit);
      case UnifiedSheetStep.preview:
        return _buildPreviewView(cubit, isDark);
      case UnifiedSheetStep.polling:
        return _buildPollingView();
      case UnifiedSheetStep.success:
        return _buildSuccessReceiptView(isDark);
      case UnifiedSheetStep.failure:
        return _buildFailureView(cubit);
    }
  }

  Widget _buildAmountInputView(PaymentCubit cubit) {
    final double amountTHB = _customAmount;

    return Column(
      children: [
        const Text(
          'Input Amount',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        PaycifAmountText(amount: amountTHB, isLarge: true),
        if (amountTHB > 0) ...[
          const SizedBox(height: 8),
          Text(
            '≈ \$${_totalUSD.toStringAsFixed(2)} USD',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.accentGold),
          ),
        ],
        const SizedBox(height: 16),
        VirtualKeypad(onKeyPressed: _handleKeypadInput),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: amountTHB > 0 ? () => _goToPreview(cubit) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentGold,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
            ),
            child: const Text('Review Payment', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewView(PaymentCubit cubit, bool isDark) {
    final double amountTHB = _customAmount;
    // Platform-aware payment method label
    final String payMethodLabel = Platform.isIOS ? 'Apple Pay / Card' : 'Google Pay / Card';
    final IconData payMethodIcon = Platform.isIOS ? PhosphorIcons.appleLogo : PhosphorIcons.googleLogo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(child: PaycifAmountText(amount: amountTHB, isLarge: true)),
        const SizedBox(height: 4),
        Center(
          child: Text(
            "≈ \$${_totalUSD.toStringAsFixed(2)} USD",
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppTheme.accentGold),
          ),
        ),
        const SizedBox(height: 24),

        // ─── PAYMENT METHOD (FROM) ───
        Text(
          "PAY WITH / จ่ายด้วย",
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0,
              color: isDark ? Colors.white60 : Colors.black54),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.01),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryTeal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(payMethodIcon, color: AppTheme.primaryTeal, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(payMethodLabel,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    Text(AppLocalizations.of(context)!.paySecuredByPartner,
                        style: TextStyle(color: AppTheme.textSecondaryColor(context), fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.accentGold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Pay per use',
                    style: TextStyle(color: AppTheme.accentGold, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
        ),

        // Visual Connector Arrow
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.02),
              shape: BoxShape.circle,
            ),
            child: Icon(PhosphorIcons.arrowDown, size: 14,
                color: isDark ? Colors.white54 : Colors.black54),
          ),
        ),

        // ─── RECIPIENT (TO) ───
        Text(
          "TO / ถึง",
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0,
              color: isDark ? Colors.white60 : Colors.black54),
        ),
        const SizedBox(height: 6),
        _buildRecipientCard(isDark),
        const SizedBox(height: 20),

        // ─── FEE BREAKDOWN ───
        Text(
          "BREAKDOWN / รายละเอียดค่าใช้จ่าย",
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0,
              color: isDark ? Colors.white60 : Colors.black54),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.01),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
            ),
          ),
          child: Column(
            children: [
              _buildBreakdownRow("Exchange Rate", "1 USD ≈ ${_exchangeRate.toStringAsFixed(2)} THB"),
              const SizedBox(height: 8),
              _buildBreakdownRow("Amount (THB)", "฿${amountTHB.toStringAsFixed(2)}"),
              const SizedBox(height: 8),
              _buildBreakdownRow("Convenience Fee", "\$${_feeUSD.toStringAsFixed(2)} USD"),
              const Divider(height: 16, thickness: 0.5, color: Colors.grey),
              _buildBreakdownRow("Total Charged (USD)", "\$${_totalUSD.toStringAsFixed(2)} USD"),
              if (widget.payContext.billerId != null ||
                  widget.payContext.reference1 != null ||
                  widget.payContext.reference2 != null) ...[
                const Divider(height: 16, thickness: 0.5, color: Colors.grey),
                if (widget.payContext.billerId != null) ...[
                  _buildBreakdownRow("Biller ID", widget.payContext.billerId!),
                  const SizedBox(height: 8),
                ],
                if (widget.payContext.reference1 != null) ...[
                  _buildBreakdownRow("Reference 1", widget.payContext.reference1!),
                  const SizedBox(height: 8),
                ],
                if (widget.payContext.reference2 != null)
                  _buildBreakdownRow("Reference 2", widget.payContext.reference2!),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),

        SwipeToPaySlider(
          onSwipeComplete: () => _initiateOnRamp(cubit),
          text: "Swipe to Pay",
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildBreakdownRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    );
  }

  Widget _buildPollingView() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: const Column(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentGold),
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Confirming payment...',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.2),
          ),
          SizedBox(height: 8),
          Text(
            'This usually takes a few seconds.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessReceiptView(bool isDark) {
    final double amountTHB = _customAmount;

    final now = DateTime.now();
    final dateVal = DateFormat('dd MMM yyyy, HH:mm').format(now);
    final txnId = "${DateFormat('yyyyMMddHHmmss').format(now)}8899";

    return Column(
      children: [
        const Icon(PhosphorIcons.checkCircle, color: AppTheme.successGreen, size: 64),
        const SizedBox(height: 16),
        const Text(
          'Payment Successful',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Your checkout settled instantly.',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
        const SizedBox(height: 24),

        // Receipt Card layout inside sheet
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.01),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
            ),
          ),
          child: Column(
            children: [
              PaycifAmountText(amount: amountTHB, isLarge: true),
              const SizedBox(height: 4),
              Text(
                "≈ \$${_totalUSD.toStringAsFixed(2)} USD",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              _buildReceiptRow("Recipient", _displayName),
              const SizedBox(height: 8),
              if (widget.payContext.accountId != null) ...[
                _buildReceiptRow("PromptPay ID", widget.payContext.accountId!),
                const SizedBox(height: 8),
              ],
              _buildReceiptRow("Date/Time", dateVal),
              const SizedBox(height: 8),
              _buildReceiptRow("Reference ID", txnId),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Done button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () => _handleSuccess(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
            ),
            child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        Flexible(
          child: Text(value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  Widget _buildFailureView(PaymentCubit cubit) {
    final isPersonalQr = _failureMessage == 'PERSONAL_QR_NOT_SUPPORTED';
    final displayMessage = isPersonalQr
        ? 'We only support registered Merchant QRs due to regulatory requirements. Personal QRs are not allowed.'
        : _failureMessage;
    final displayHeader = isPersonalQr ? 'Personal QR Not Supported' : 'Payment Failed';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const Icon(PhosphorIcons.warningCircle, color: Colors.red, size: 56),
          const SizedBox(height: 16),
          Text(
            displayHeader,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            displayMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              if (!isPersonalQr) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _step = UnifiedSheetStep.preview;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentGold,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    ),
                    child: const Text('Retry'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// In-app WebView for AlchemyPay checkout (iOS only).
/// Intercepts paycif:// deep-link redirect to detect when the user completes payment.
class _AchCheckoutPage extends StatefulWidget {
  final Uri uri;

  const _AchCheckoutPage({required this.uri});

  @override
  State<_AchCheckoutPage> createState() => _AchCheckoutPageState();
}

class _AchCheckoutPageState extends State<_AchCheckoutPage> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _loading = true),
        onPageFinished: (_) => setState(() => _loading = false),
        onNavigationRequest: (req) {
          if (req.url.startsWith('paycif://')) {
            Navigator.of(context).pop(req.url);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(widget.uri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Payment'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
