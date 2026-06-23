import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:frontend/features/security/presentation/widgets/pin_entry_widget.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/paycif_icon_container.dart';
import 'package:frontend/core/widgets/paycif_amount_text.dart';
import 'package:frontend/core/network/api_service.dart';

import 'package:frontend/features/payment/domain/entities/payment_breakdown.dart';
import 'package:frontend/features/payment/data/repositories/payment_repository_impl.dart';
import 'package:frontend/features/payment/presentation/logic/payment_cubit.dart';
import 'package:frontend/features/payment/presentation/logic/payment_state.dart';
import 'package:frontend/features/security/domain/repositories/security_repository.dart';
import 'package:frontend/features/payment/presentation/widgets/fx_breakdown_card.dart';
import 'package:frontend/core/widgets/paycif_button.dart';
import 'package:frontend/features/profile/domain/saved_card.dart';
import 'package:frontend/core/l10n/generated/app_localizations.dart';

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
  SavedCard? _selectedCard;
  bool _loadingCard = true;

  @override
  void initState() {
    super.initState();
    _prewarmBiometric();
    _loadPaymentMethod();
  }

  Future<void> _loadPaymentMethod() async {
    try {
      final cards = await ApiService().getSavedCards();
      if (!mounted) return;
      setState(() {
        _selectedCard = cards.isNotEmpty ? cards.first : null;
        _loadingCard = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingCard = false);
    }
  }

  Future<void> _prewarmBiometric() async {
    try {
      final ready = await _auth.canCheckBiometrics;
      if (mounted) setState(() => _biometricReady = ready);
    } catch (_) {}
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
    final l10n = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;
    final breakdown = PaymentBreakdown(amountTHB: widget.amount);

    return BlocProvider(
      create: (context) => PaymentCubit(
        paymentRepository: PaymentRepositoryImpl(
          apiService: ApiService(),
          securityRepository: context.read<SecurityRepository>(),
        ),
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
            l10n.payReviewTitle,
            style: theme.appBarTheme.titleTextStyle?.copyWith(
              color: isDark ? Colors.white : AppTheme.textPrimary,
            ),
          ),
        ),
        body: BlocConsumer<PaymentCubit, PaymentState>(
          listener: (context, state) {
            if (state is PaymentSuccess) {
              context.pushReplacement('/payment_success', extra: {
                'transactionId': state.transactionId,
                'amount': widget.amount,
                'recipientName': widget.merchantName,
                'promptPayId': widget.promptPayId,
              });
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
                  _buildPaymentMethodCard(theme, isDark, l10n),
                  const SizedBox(height: 16),
                  Text(
                    l10n.payCrossBorderDisclaimer,
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

  Widget _buildPaymentMethodCard(ThemeData theme, bool isDark, AppLocalizations l10n) {
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
            child: _loadingCard
                ? Container(
                    width: double.infinity,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedCard != null ? l10n.payMethodPayPerUse : l10n.payNoMethodSelected,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_selectedCard != null)
                        Text(
                          '${_selectedCard!.brand} •••• ${_selectedCard!.lastDigits}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
          ),
          if (!_loadingCard && _selectedCard != null)
            const Icon(PhosphorIcons.checkCircle, color: AppTheme.successGreen),
        ],
      ),
    );
  }
}
