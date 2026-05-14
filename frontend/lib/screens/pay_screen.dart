import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:local_auth/local_auth.dart';
import 'package:frontend/features/security/presentation/widgets/pin_entry_widget.dart';
import 'package:provider/provider.dart';
import '../controllers/dashboard_controller.dart';
import '../controllers/payment_controller.dart';
import '../cubit/payment_cubit.dart';
import '../cubit/payment_state.dart';
import '../models/saved_card.dart';
import '../services/api_service.dart';
import '../utils/error_translator.dart';
import 'package:frontend/l10n/generated/app_localizations.dart';
import 'payment_success_screen.dart';
import 'top_up_view.dart';
import '../features/security/domain/repositories/security_repository.dart';
import '../utils/fee_calculator.dart';
import '../widgets/kyc/payment_method_picker.dart';

class PayScreen extends StatefulWidget {
  final double amount;
  final String merchantName;
  final String? promptPayId;
  final String? billerId;
  final String? reference1;
  final String? reference2;

  const PayScreen({
    super.key,
    required this.amount,
    required this.merchantName,
    this.promptPayId,
    this.billerId,
    this.reference1,
    this.reference2,
  });

  @override
  State<PayScreen> createState() => _PayScreenState();
}

class _PayScreenState extends State<PayScreen> {
  final ApiService _apiService = ApiService();

  // Controllers for Custom Payment Sheet
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController(); // MM/YY
  final _cvvController = TextEditingController();
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // ใช้ชื่อจาก QR Code โดยตรง (EMV Tag 59 = Merchant Name)
  // ถ้าไม่มีชื่อ (Personal QR) EMV Parser จะ format PromptPay ID ให้แล้ว
  String get _displayName => widget.merchantName;

  // Pre-warmed biometric state
  final LocalAuthentication _auth = LocalAuthentication();
  bool _biometricReady = false;

  @override
  void initState() {
    super.initState();
    _prewarmBiometric();
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  /// Pre-warm biometric sensor to eliminate cold-start delay
  void _prewarmBiometric() {
    _auth.canCheckBiometrics
        .then((ready) {
          _biometricReady = ready;
        })
        .catchError((_) {});
  }

  void _showMethodPicker() {
    final paymentController = Provider.of<PaymentController>(
      context,
      listen: false,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PaymentMethodPicker(
        preferredMethodId: paymentController.preferredMethodId,
        preferredMethodType: paymentController.preferredMethodType,
        savedCards: paymentController.savedCards,
        onMethodSelected: (id, type) {
          paymentController.updatePreference(id, type);
        },
        onAddMethod: () {
          _showOpnPaymentSheet();
        },
      ),
    );
  }

  Future<void> _authenticateAndPay(PaymentCubit cubit) async {
    bool isAuthenticated = false;

    // 1. Try Biometrics First (Already pre-warmed)
    if (_biometricReady) {
      try {
        isAuthenticated = await _auth.authenticate(
          localizedReason: 'Scan to pay ฿${widget.amount.toStringAsFixed(2)}',
          persistAcrossBackgrounding: true,
          biometricOnly: true,
        );
      } catch (_) {
        // Biometric canceled/failed, fall through to PIN
      }
    }

    if (isAuthenticated) {
      // ✅ Biometric Success -> Execute with Processing Overlay
      if (mounted) {
        // Give time for iOS native Face ID dialog to dismiss fully
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) _executePaymentWithProcessingOverlay(cubit);
      }
      return;
    }

    // 2. Fallback to PIN (if Biometric failed/skipped)
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        height: MediaQuery.of(sheetContext).size.height * 0.75,
        decoration: BoxDecoration(
          color: Theme.of(sheetContext).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: PinEntryWidget(
                isSetupMode: false,
                showLabel: true,
                onSuccess: (pin) {
                  // ✅ Close sheet and execute with processing overlay
                  Navigator.pop(sheetContext);
                  _executePaymentWithProcessingOverlay(cubit);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// World-Class "Perceived Speed" Pattern
  /// Shows premium processing animation while API runs in parallel
  /// Never shows "Success" until we have real confirmation
  Future<void> _executePaymentWithProcessingOverlay(PaymentCubit cubit) async {
    final paymentController = context.read<PaymentController>();
    final prefId = paymentController.preferredMethodId;
    final prefType = paymentController.preferredMethodType;
    final currentCards = paymentController.savedCards;

    final hasExactApplePay = prefType == 'apple_pay';
    final exactCardIndex = currentCards.indexWhere(
      (c) =>
          prefType == 'card' &&
          (prefId == c.id || (prefId != null && c.id.contains(prefId))),
    );

    bool useWallet = true;
    bool isApplePay = false;
    SavedCard? selectedCard;

    if (prefType == 'wallet' || (prefId == null && prefType == null)) {
      useWallet = true;
    } else if (hasExactApplePay) {
      useWallet = false;
      isApplePay = true;
    } else if (exactCardIndex != -1) {
      useWallet = false;
      selectedCard = currentCards[exactCardIndex];
    }

    // Show processing overlay immediately
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => const _ProcessingOverlay(),
    );

    if (useWallet) {
      // Fire standard Payout API
      cubit.pay(
        recipientPromptPayId: widget.promptPayId,
        recipientName: _displayName,
        billerId: widget.billerId,
        reference1: widget.reference1,
        reference2: widget.reference2,
      );
    } else {
      // 💎 ORCHESTRATED DIRECT PAY (Pay-Per-Use)
      _handleDirectPay(cubit, isApplePay, selectedCard);
    }
  }

  Future<void> _handleDirectPay(
    PaymentCubit cubit,
    bool isApplePay,
    SavedCard? card,
  ) async {
    final securityRepo = context.read<SecurityRepository>();
    final l10n = AppLocalizations.of(context)!;

    // 1. Calculate Fees
    final feeBreakdown = FeeCalculator.calculateFromBaht(
      widget.amount,
      isChargeAmount: false,
    );
    final walletAmountSatang = feeBreakdown.walletAmount.toBigInt().toInt();
    final chargeAmountSatang = feeBreakdown.chargeAmount.toBigInt().toInt();

    final topupRefId = const Uuid().v4();
    final payoutRefId = const Uuid().v4();

    try {
      // 2. Generate Signatures
      final topupHeaders = await securityRepo.generateSignatureHeaders(topupRefId);
      final payoutHeaders = await securityRepo.generateSignatureHeaders(payoutRefId);

      // 3. STEP 1: Top up the exact amount needed
      debugPrint('💎 [DirectPay] Step 1: Charging Card...');
      await _apiService.executeOpnTopUp(
        amountSatang: chargeAmountSatang,
        walletAmountSatang: walletAmountSatang,
        cardId: card?.id,
        isApplePay: isApplePay,
        referenceId: topupRefId,
        description: 'Direct Pay Top-up',
        headers: topupHeaders,
      );

      // 4. STEP 2: Execute Payout
      debugPrint('💎 [DirectPay] Step 2: Executing Payout...');
      // Get wallet ID (assuming THB wallet for now)
      final balanceData = await _apiService.getBalance('THB');
      final walletId = balanceData['wallet_id'];

      final payoutResult = await _apiService.executePayout(
        walletId: walletId,
        amountSatang: walletAmountSatang.toDouble(),
        targetType: widget.promptPayId != null ? 'MOBILE' : (widget.billerId != null ? 'BILLER' : 'MOBILE'),
        targetValue: widget.promptPayId ?? widget.billerId ?? '',
        idempotencyKey: payoutRefId,
        description: 'Direct Payment to $_displayName',
        headers: payoutHeaders,
      );

      if (mounted) {
        // Close processing overlay
        Navigator.of(context, rootNavigator: true).popUntil((route) => route is! DialogRoute);

        // Finalize state in Cubit to trigger success navigation
        cubit.finalizeDirectPaySuccess(
          transactionId: payoutResult['transaction_id'],
          remainingBalance: (payoutResult['new_balance'] ?? 0) / 100.0,
          senderName: payoutResult['sender_name'],
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).popUntil((route) => route is! DialogRoute);

        // 💎 Special Handling for Orchestration Failures
        final isPayoutFailure = e.toString().contains('Payout') || e.toString().contains('payout');

        if (isPayoutFailure) {
          // Top-up likely succeeded but payout failed
          _showPayoutFailedButTopupSucceeded(l10n);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Payment Failed: ${ErrorTranslator.translate(l10n, e.toString())}'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  void _showPayoutFailedButTopupSucceeded(AppLocalizations l10n) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('Partial Success'),
          ],
        ),
        content: const Text(
          'Your card was charged and your wallet was topped up successfully. However, the final payment to the merchant failed. The money remains safe in your Paysif wallet.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Trigger refresh to show the newly added funds from the successful top-up
              context.read<DashboardController>().refresh();
              Navigator.pop(context); // Exit PayScreen
            },
            child: Text(l10n.commonOk),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocProvider(
      create: (context) => PaymentCubit(
        apiService: ApiService(),
        securityRepository: context.read<SecurityRepository>(),
      )..initialize(widget.amount),
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF0F172A)
            : const Color(0xFFF8FAFC),
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: BlocConsumer<PaymentCubit, PaymentState>(
              listener: (context, state) {
                if (state is PaymentSuccess) {
                  // Close processing overlay if open
                  Navigator.of(
                    context,
                    rootNavigator: true,
                  ).popUntil((route) => route is! DialogRoute);

                  // Sync Dashboard
                  try {
                    context.read<DashboardController>().syncPaymentSuccess(
                      transactionId: state.transactionId,
                      amount: widget.amount,
                      recipientName: _displayName,
                      remainingBalance: state.remainingBalance ?? 0.0,
                    );
                  } catch (_) {}

                  // Navigate to Success Screen
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => PaymentSuccessScreen(
                        transactionId: state.transactionId,
                        amount: widget.amount,
                        recipientName: _displayName,
                        senderName: state.senderName,
                        promptPayId: widget.promptPayId,
                        remainingBalance: state.remainingBalance,
                      ),
                    ),
                  );
                } else if (state is PaymentFailure) {
                  // Close processing overlay if open
                  Navigator.of(
                    context,
                    rootNavigator: true,
                  ).popUntil((route) => route is! DialogRoute);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${l10n.confirmPaymentFailed}: ${ErrorTranslator.translate(l10n, state.errorMessage)}',
                      ),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              },
              builder: (context, state) {
                if (state is PaymentLoading || state is PaymentInitial) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state is PaymentInsufficientFunds) {
                  return _buildInsufficientFundsView(
                    context,
                    state,
                    isDark,
                    l10n,
                  );
                }

                if (state is PaymentReady || state is PaymentProcessing) {
                  final isReady = state is PaymentReady;
                  final balance = isReady ? state.balance : 0.0;
                  final isProcessing = state is PaymentProcessing;

                  return _buildPaymentView(
                    context,
                    isDark,
                    l10n,
                    balance,
                    isProcessing,
                  );
                }

                return Center(child: Text(l10n.commonSomethingWentWrong));
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentView(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
    double balance,
    bool isProcessing,
  ) {
    return Consumer<PaymentController>(
      builder: (context, paymentController, child) {
        final prefId = paymentController.preferredMethodId;
        final prefType = paymentController.preferredMethodType;
        final currentCards = paymentController.savedCards;

        final isApplePayAvailable = (Platform.isIOS || Platform.isMacOS);
        final hasExactApplePay = prefType == 'apple_pay';
        final exactCardIndex = currentCards.indexWhere(
          (c) =>
              prefType == 'card' &&
              (prefId == c.id || (prefId != null && c.id.contains(prefId))),
        );

        bool useWallet = true;
        bool isApplePay = false;
        SavedCard? displayCard;

        if (prefType == 'wallet' || (prefId == null && prefType == null)) {
          useWallet = true;
        } else if (hasExactApplePay) {
          useWallet = false;
          isApplePay = true;
        } else if (exactCardIndex != -1) {
          useWallet = false;
          displayCard = currentCards[exactCardIndex];
        } else {
          useWallet = true;
        }

        // Calculate fees if using card
        FeeBreakdown? feeBreakdown;
        if (!useWallet) {
          feeBreakdown = FeeCalculator.calculateFromBaht(
            widget.amount,
            isChargeAmount: false,
          );
        }

        return Column(
          children: [
            const Spacer(flex: 2),

            // 1. Amount Display
            Text(
              '฿${widget.amount.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
                letterSpacing: -1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _displayName,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            if (widget.promptPayId != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  widget.promptPayId!,
                  style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                ),
              ),

            const Spacer(flex: 1),

            // 2. Payment Method Selector
            InkWell(
              onTap: _showMethodPicker,
              borderRadius: BorderRadius.circular(20),
              child: useWallet
                  ? _buildWalletCard(isDark, balance)
                  : _buildCardMethodCard(isDark, isApplePay, displayCard),
            ),

            if (!useWallet && feeBreakdown != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  '+ ฿${feeBreakdown.totalFeeBaht.toStringAsFixed(2)} fee (Total ฿${feeBreakdown.chargeAmountBaht.toStringAsFixed(2)})',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
              ),

            const Spacer(flex: 2),

            // 3. Pay Button
            _buildPayButton(context, isDark, isProcessing, !useWallet),

            const SizedBox(height: 48),
          ],
        );
      },
    );
  }

  Widget _buildCardMethodCard(
    bool isDark,
    bool isApplePay,
    SavedCard? displayCard,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isApplePay ? Icons.apple : Icons.credit_card_rounded,
              color: Colors.black87,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isApplePay
                      ? 'Apple Pay'
                      : (displayCard != null
                          ? '${displayCard.brand} •••• ${displayCard.lastDigits}'
                          : 'Select Card'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Direct Payment',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.expand_more_rounded,
            color: Colors.grey,
            size: 24,
          ),
        ],
      ),
    );
  }

  Widget _buildWalletCard(bool isDark, double balance) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Paysif Wallet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '฿${balance.toStringAsFixed(2)} Available',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF10B981),
            size: 24,
          ),
        ],
      ),
    );
  }

  Widget _buildPayButton(
    BuildContext context,
    bool isDark,
    bool isProcessing,
    bool isDirectPay,
  ) {
    return Container(
      width: double.infinity,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: isProcessing
            ? null
            : () => _authenticateAndPay(context.read<PaymentCubit>()),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6366F1),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: isProcessing
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                isDirectPay ? 'Pay with Card' : 'Confirm Payment',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildInsufficientFundsView(
    BuildContext context,
    PaymentInsufficientFunds state,
    bool isDark,
    AppLocalizations l10n,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.account_balance_wallet_outlined,
            color: Colors.redAccent,
            size: 48,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Insufficient Balance',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'You need ฿${state.shortfall.toStringAsFixed(2)} more to complete this payment.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.grey[500]),
        ),
        const SizedBox(height: 8),
        Text(
          'Current Balance: ฿${state.availableBalance.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () {
              // Navigate to Top Up screen
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const TopUpView()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Top Up Wallet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
        ),
      ],
    );
  }

  void _showOpnPaymentSheet() {
    var sheetAutovalidateMode = AutovalidateMode.disabled;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final l10n = AppLocalizations.of(context)!;
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              height: 600,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 20),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        autovalidateMode: sheetAutovalidateMode,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Add Payment Card',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 32),
                            _buildField(
                              label: l10n.topUpCardNumber,
                              hint: '0000 0000 0000 0000',
                              controller: _cardNumberController,
                              icon: Icons.credit_card,
                              formatters: [CardNumberInputFormatter()],
                              validator: (value) {
                                final clean = value?.replaceAll(' ', '') ?? '';
                                if (clean.isEmpty) return l10n.commonRequired;
                                if (clean.length < 16) return l10n.cardInvalidNumber;
                                return null;
                              },
                              maxLength: 19,
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildField(
                                    label: l10n.topUpExpiry,
                                    hint: 'MM/YY',
                                    controller: _expiryController,
                                    icon: Icons.calendar_today,
                                    formatters: [ExpiryDateInputFormatter()],
                                    validator: (value) {
                                      if (value == null || value.isEmpty) return l10n.commonRequired;
                                      return null;
                                    },
                                    maxLength: 5,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildField(
                                    label: l10n.topUpCVV,
                                    hint: '123',
                                    controller: _cvvController,
                                    icon: Icons.lock,
                                    obscure: true,
                                    formatters: [FilteringTextInputFormatter.digitsOnly],
                                    maxLength: 3,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) return l10n.commonRequired;
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _buildField(
                              label: l10n.topUpNameOnCard,
                              hint: 'NAME ON CARD',
                              controller: _nameController,
                              icon: Icons.person,
                              textCapitalization: TextCapitalization.characters,
                              formatters: [UpperCaseTextFormatter()],
                              validator: (value) {
                                if (value == null || value.isEmpty) return l10n.commonRequired;
                                return null;
                              },
                            ),
                            const SizedBox(height: 40),
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: () {
                                  if (_formKey.currentState!.validate()) {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Card details accepted. Please proceed with payment.')),
                                    );
                                  } else {
                                    setSheetState(() {
                                      sheetAutovalidateMode = AutovalidateMode.onUserInteraction;
                                    });
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6366F1),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text(
                                  'Confirm Card',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    bool obscure = false,
    List<TextInputFormatter>? formatters,
    int? maxLength,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    FocusNode? focusNode,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    List<TextInputFormatter> effectiveFormatters = formatters ?? [];
    if (maxLength != null) {
      effectiveFormatters.add(LengthLimitingTextInputFormatter(maxLength));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          inputFormatters: effectiveFormatters,
          textCapitalization: textCapitalization,
          validator: validator,
          onChanged: onChanged,
          focusNode: focusNode,
          decoration: InputDecoration(
            hintText: hint,
            counterText: '',
            filled: true,
            fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            prefixIcon: Icon(icon, size: 20, color: Colors.grey),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}

/// World-Class Processing Overlay
/// Premium animation that hides network latency while providing user feedback
class _ProcessingOverlay extends StatelessWidget {
  const _ProcessingOverlay();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Premium Spinner
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDark ? Colors.white : const Color(0xFF6366F1),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.confirmProcessing,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.selection.baseOffset == 0) return newValue;
    final text = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if ((i + 1) % 4 == 0 && i != text.length - 1) buffer.write(' ');
    }
    final string = buffer.toString();
    return newValue.copyWith(text: string, selection: TextSelection.collapsed(offset: string.length));
  }
}

class ExpiryDateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.selection.baseOffset == 0) return newValue;
    final text = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if (i == 1 && i != text.length - 1) buffer.write('/');
    }
    final string = buffer.toString();
    return newValue.copyWith(text: string, selection: TextSelection.collapsed(offset: string.length));
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(text: newValue.text.toUpperCase(), selection: newValue.selection);
  }
}
