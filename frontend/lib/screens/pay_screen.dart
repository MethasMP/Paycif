import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/payment_cubit.dart';
import '../cubit/payment_state.dart';
import '../services/api_service.dart';
import 'package:frontend/l10n/generated/app_localizations.dart';

class PayScreen extends StatelessWidget {
  final double amount;
  final String merchantName;

  const PayScreen({
    super.key,
    required this.amount,
    required this.merchantName,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocProvider(
      create: (context) =>
          PaymentCubit(apiService: ApiService())..initialize(amount),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
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
                  // Navigate to Success Screen or Pop with Result
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.paymentSuccessTitle)),
                  );
                  Navigator.of(context).pop(true);
                } else if (state is PaymentFailure) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${l10n.confirmPaymentFailed}: ${state.errorMessage}',
                      ),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              },
              builder: (context, state) {
                // Show Loading or Content
                if (state is PaymentLoading || state is PaymentInitial) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state is PaymentReady || state is PaymentProcessing) {
                  final method = (state is PaymentReady)
                      ? state.method
                      : (state as PaymentProcessing).method;
                  final isProcessing = state is PaymentProcessing;

                  return Column(
                    children: [
                      const Spacer(flex: 2),
                      // 1. Amount Display
                      Text(
                        '฿ ${amount.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.displayMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        merchantName,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: Colors.grey[600]),
                      ),
                      const Spacer(flex: 3),

                      // 2. Primary Pay Button
                      _buildPayButton(context, method, isProcessing),

                      const SizedBox(height: 24),

                      // 3. Change Method Link
                      if (!isProcessing)
                        TextButton(
                          onPressed: () =>
                              _showMethodPicker(context, state as PaymentReady),
                          child: Text(
                            '${l10n.paymentChangeMethod} ▸',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ),
                      const Spacer(flex: 1),
                    ],
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

  Widget _buildPayButton(
    BuildContext context,
    PaymentMethod method,
    bool isProcessing,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Special UI for Apple Pay
    if (method.type == PaymentMethodType.applePay) {
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: isProcessing
              ? null
              : () => context.read<PaymentCubit>().pay(),
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark ? Colors.white : Colors.black,
            foregroundColor: isDark ? Colors.black : Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(100),
            ),
          ),
          icon: isProcessing
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: isDark ? Colors.black : Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.apple, size: 28),
          label: Text(
            isProcessing ? l10n.splashLoading : l10n.paymentPayWithApple,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
        ),
      );
    }

    // Default UI for Cards
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isProcessing
            ? null
            : () => context.read<PaymentCubit>().pay(),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: isDark ? Colors.black : Colors.white,
          elevation: 4,
          shadowColor: Theme.of(context).primaryColor.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: isProcessing
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.credit_card, size: 22),
                  const SizedBox(width: 12),
                  Text(
                    l10n.paymentPayWith(method.title),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _showMethodPicker(BuildContext context, PaymentReady state) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.sheetAddPayment,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ...state.availableMethods.map((method) {
              final isSelected = method.id == state.method.id;
              return ListTile(
                leading: Icon(
                  method.type == PaymentMethodType.applePay
                      ? Icons.apple
                      : Icons.credit_card,
                  color: isSelected ? Theme.of(context).primaryColor : null,
                ),
                title: Text(
                  method.title,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : null,
                  ),
                ),
                subtitle: method.subtitle != null
                    ? Text(method.subtitle!)
                    : null,
                trailing: isSelected
                    ? Icon(
                        Icons.check_circle,
                        color: Theme.of(context).primaryColor,
                      )
                    : null,
                onTap: () {
                  context.read<PaymentCubit>().selectMethod(method);
                  Navigator.pop(context);
                },
              );
            }),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
