import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:local_auth/local_auth.dart';
import 'package:frontend/features/security/presentation/widgets/pin_entry_widget.dart';
import 'package:frontend/theme/app_theme.dart';
import 'package:frontend/widgets/paycif_icon_container.dart';
import 'package:frontend/widgets/paycif_amount_text.dart';
import 'package:frontend/services/api_service.dart';

import '../../domain/entities/payment_breakdown.dart';
import '../../data/repositories/payment_repository_impl.dart';
import '../logic/payment_cubit.dart';
import '../logic/payment_state.dart';
import '../widgets/fx_breakdown_card.dart';
import '../../../../core/widgets/paycif_button.dart';
import 'payment_success_screen.dart';

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
    final breakdown = PaymentBreakdown(amountTHB: widget.amount);
    bool authenticated = false;
    if (_biometricReady) {
      try {
        authenticated = await _auth.authenticate(
          localizedReason: 'Confirm payment of \$${breakdown.totalUSD.toStringAsFixed(2)} USD (฿${widget.amount.toStringAsFixed(2)})',
          biometricOnly: true,
        );
      } catch (_) {}
    }

    if (authenticated) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) _executePayment(cubit);
    } else {
      if (mounted) _showPinEntry(context, cubit);
    }
  }

  void _showPinEntry(BuildContext context, PaymentCubit cubit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => Container(
        height: MediaQuery.of(bottomSheetContext).size.height * 0.75,
        decoration: BoxDecoration(
          color: Theme.of(bottomSheetContext).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: PinEntryWidget(
          isSetupMode: false,
          onSuccess: (pin) {
            Navigator.pop(bottomSheetContext);
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
      billerId: widget.billerId,
      reference1: widget.reference1,
      reference2: widget.reference2,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final breakdown = PaymentBreakdown(amountTHB: widget.amount);

    return BlocProvider(
      create: (context) => PaymentCubit(
        paymentRepository: PaymentRepositoryImpl(apiService: ApiService()),
      )..initialize(widget.amount),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(PhosphorIcons.x, color: isDark ? Colors.white : AppTheme.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            "Review Payment",
            style: theme.appBarTheme.titleTextStyle?.copyWith(
              color: isDark ? Colors.white : AppTheme.textPrimary,
            ),
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
            final cubit = context.read<PaymentCubit>();
            final isLoading = state is PaymentProcessing;

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
                    "≈ \$${breakdown.totalUSD.toStringAsFixed(2)} USD",
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: AppTheme.textSecondaryColor(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.merchantName,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const Spacer(),
                  FxBreakdownCard(breakdown: breakdown),
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
                    child: PaycifButton(
                      text: "Pay \$${breakdown.totalUSD.toStringAsFixed(2)}",
                      isLoading: isLoading,
                      onPressed: () => _authenticateAndPay(cubit),
                      variant: PaycifButtonVariant.primary,
                      size: PaycifButtonSize.lg,
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
}
