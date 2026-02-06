import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:local_auth/local_auth.dart';
import 'package:frontend/features/security/presentation/widgets/pin_entry_widget.dart';
import '../controllers/dashboard_controller.dart';
import '../cubit/payment_cubit.dart';
import '../cubit/payment_state.dart';
import '../services/api_service.dart';
import '../utils/error_translator.dart';
import 'package:frontend/l10n/generated/app_localizations.dart';
import 'payment_success_screen.dart';
import 'top_up_view.dart';
import '../features/security/domain/repositories/security_repository.dart';

class PayScreen extends StatefulWidget {
  final double amount;
  final String merchantName;
  final String? promptPayId;

  const PayScreen({
    super.key,
    required this.amount,
    required this.merchantName,
    this.promptPayId,
  });

  @override
  State<PayScreen> createState() => _PayScreenState();
}

class _PayScreenState extends State<PayScreen> {
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

  /// Pre-warm biometric sensor to eliminate cold-start delay
  void _prewarmBiometric() {
    _auth.canCheckBiometrics
        .then((ready) {
          _biometricReady = ready;
        })
        .catchError((_) {});
  }

  Future<void> _authenticateAndPay(PaymentCubit cubit) async {
    bool isAuthenticated = false;

    // 1. Try Biometrics First (Already pre-warmed)
    if (_biometricReady) {
      try {
        isAuthenticated = await _auth.authenticate(
          localizedReason: 'Scan to pay ฿${widget.amount.toStringAsFixed(2)}',
          options: const AuthenticationOptions(
            stickyAuth: true,
            biometricOnly: true,
          ),
        );
      } catch (_) {
        // Biometric canceled/failed, fall through to PIN
      }
    }

    if (isAuthenticated) {
      // ✅ Biometric Success -> Execute with Processing Overlay
      if (mounted) {
        _executePaymentWithProcessingOverlay(cubit);
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
    // Show processing overlay immediately
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => const _ProcessingOverlay(),
    );

    // Fire API and wait for result
    cubit.pay(
      recipientPromptPayId: widget.promptPayId ?? '',
      recipientName: _displayName,
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
    return Column(
      children: [
        const Spacer(flex: 2),

        // 1. Amount Display (Large, Clear)
        Text(
          '฿${widget.amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 56,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
            letterSpacing: -2,
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

        // 2. Wallet Balance Card
        _buildWalletCard(isDark, balance),

        const Spacer(flex: 2),

        // 3. Pay Button (Now with Auth)
        _buildPayButton(context, isDark, isProcessing),

        const SizedBox(height: 48),
      ],
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

  Widget _buildPayButton(BuildContext context, bool isDark, bool isProcessing) {
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
            : const Text(
                'Confirm Payment',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
