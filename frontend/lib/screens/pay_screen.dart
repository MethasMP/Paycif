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
        authenticated = await _auth.authenticate(
          localizedReason: 'Confirm payment of ฿${widget.amount.toStringAsFixed(2)}',
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
          backgroundColor: const Color(0xFF0F6E56),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
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
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const Spacer(),
                  PaycifAmountText(
                    amount: widget.amount,
                    style: theme.textTheme.displayLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(widget.merchantName, style: theme.textTheme.titleLarge),
                  const Spacer(),
                  _buildPaymentMethodCard(theme, isDark),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: () => _authenticateAndPay(context.read<PaymentCubit>()),
                      child: const Text("Confirm Payment"),
                    ),
                  ),
                  const SizedBox(height: 48),
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
          const PaycifIconContainer(icon: Icons.credit_card),
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
          const Icon(Icons.check_circle, color: Color(0xFF10B981)),
        ],
      ),
    );
  }
}
