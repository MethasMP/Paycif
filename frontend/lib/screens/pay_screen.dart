import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:local_auth/local_auth.dart';
import 'package:frontend/features/security/presentation/widgets/pin_entry_widget.dart';
import '../cubit/payment_cubit.dart';
import '../cubit/payment_state.dart';
import '../services/api_service.dart';
import 'payment_success_screen.dart';
import '../features/security/domain/repositories/security_repository.dart';
import '../widgets/paycif_icon_container.dart';
import '../widgets/paycif_amount_text.dart';
import 'package:frontend/theme/app_theme.dart';

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
  final LocalAuthentication _auth = LocalAuthentication();
  bool _biometricReady = false;

  @override
  void initState() {
    super.initState();
    _prewarmBiometric();
  }

  void _prewarmBiometric() {
    _auth.canCheckBiometrics.then((ready) => _biometricReady = ready).catchError((_) {
      return false;
    });
  }

  Future<void> _authenticateAndPay(PaymentCubit cubit) async {
    bool authenticated = false;
    if (_biometricReady) {
      try {
        final double totalUSD = (widget.amount / 36.45) * 1.035;
        authenticated = await _auth.authenticate(
          localizedReason: 'Confirm payment of \$${totalUSD.toStringAsFixed(2)} USD (฿${widget.amount.toStringAsFixed(2)})',
          biometricOnly: true,
        );
      } catch (_) {}
    }

    if (authenticated) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) _executePayment(cubit);
    } else {
      // Fallback to PIN
      _showPinEntry(cubit);
    }
  }

  void _showPinEntry(PaymentCubit cubit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: PinEntryWidget(
          isSetupMode: false,
          onSuccess: (pin) {
            Navigator.pop(context);
            _executePayment(cubit);
          },
        ),
      ),
    );
  }

  void _executePayment(PaymentCubit cubit) {
    cubit.pay(
      recipientPromptPayId: widget.promptPayId,
      recipientName: widget.merchantName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BlocProvider(
      create: (context) => PaymentCubit(
        apiService: ApiService(),
        securityRepository: context.read<SecurityRepository>(),
      )..initialize(widget.amount),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: AppTheme.primaryTeal,
          leading: IconButton(
            icon: Icon(PhosphorIcons.x, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: BlocConsumer<PaymentCubit, PaymentState>(
          listener: (context, state) {
            if (state is PaymentSuccess) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => PaymentSuccessScreen(
                    transactionId: state.transactionId,
                    amount: widget.amount,
                    recipientName: widget.merchantName,
                    promptPayId: widget.promptPayId,
                  ),
                ),
              );
            } else if (state is PaymentFailure) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Payment Failed: ${state.errorMessage}")),
              );
            }
          },
          builder: (context, state) {
            final double totalUSD = (widget.amount / 36.45) * 1.035;
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const Spacer(),
                  PaycifAmountText(
                    amount: widget.amount,
                    style: theme.textTheme.displayLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "≈ \$${totalUSD.toStringAsFixed(2)} USD",
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: AppTheme.textSecondaryColor(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.merchantName,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  _buildFXBreakdownCard(theme),
                  _buildPaymentMethodCard(theme, isDark),
                  const SizedBox(height: 16),
                  Text(
                    "* Your card issuer may apply cross-border fees.",
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: () => _authenticateAndPay(context.read<PaymentCubit>()),
                      child: const Text("Confirm Payment"),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPaymentMethodCard(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.primaryColor.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          PaycifIconContainer(icon: PhosphorIcons.creditCard),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Pay per use",
                  style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  "Visa **** 8899",
                  style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                ),
              ],
            ),
          ),
          const Icon(PhosphorIcons.checkCircle, color: AppTheme.successGreen),
        ],
      ),
    );
  }

  Widget _buildFXBreakdownCard(ThemeData theme) {
    final double amountUSD = widget.amount / 36.45;
    final double feeUSD = amountUSD * 0.035;
    final double totalUSD = amountUSD * 1.035;

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.primaryColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          _buildBreakdownRow("Exchange Rate", "1 USD ≈ 36.45 THB", theme),
          const SizedBox(height: 8),
          _buildBreakdownRow("Base Amount", "฿${widget.amount.toStringAsFixed(2)}", theme),
          const SizedBox(height: 8),
          _buildBreakdownRow("Convenience Fee (3.5%)", "\$${feeUSD.toStringAsFixed(2)} USD", theme),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppTheme.borderGrey),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Guaranteed Charge",
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
              Text(
                "\$${totalUSD.toStringAsFixed(2)} USD",
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentGold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(String label, String value, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppTheme.textSecondaryColor(context),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimaryColor(context),
          ),
        ),
      ],
    );
  }
}
