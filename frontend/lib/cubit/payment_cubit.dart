import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/api_service.dart';
import 'payment_state.dart';

class PaymentCubit extends Cubit<PaymentState> {
  final ApiService _apiService;

  PaymentCubit({ApiService? apiService})
    : _apiService = apiService ?? ApiService(),
      super(PaymentInitial());

  /// Initializes the payment screen with wallet balance check.
  Future<void> initialize(double amount, {String? recipientName}) async {
    emit(PaymentLoading());
    try {
      // 1. Fetch Wallet Balance (THB) with retry for race conditions
      Map<String, dynamic>? balanceData;
      int retries = 0;
      const maxRetries = 3;

      while (retries < maxRetries) {
        try {
          balanceData = await _apiService.getBalance('THB');
          // If we got a valid response, break out of retry loop
          if (balanceData['balance'] != null) break;
        } catch (_) {
          // Connection error, retry
        }
        retries++;
        if (retries < maxRetries) {
          await Future.delayed(Duration(milliseconds: 500 * retries));
        }
      }

      final int balanceMinor = balanceData?['balance'] ?? 0;
      final double balanceMajor = balanceMinor / 100.0;

      // 2. Check if sufficient funds
      final bool hasSufficientFunds = balanceMajor >= amount;

      // 3. Create Wallet Payment Method
      final walletMethod = PaymentMethod(
        id: 'wallet_thb',
        type: PaymentMethodType.wallet,
        title: 'Paysif Wallet',
        subtitle: '฿${balanceMajor.toStringAsFixed(2)} Available',
      );

      if (hasSufficientFunds) {
        emit(
          PaymentReady(
            method: walletMethod,
            amount: amount,
            availableMethods: [walletMethod],
            balance: balanceMajor,
          ),
        );
      } else {
        // Insufficient Balance: Emit special state
        emit(
          PaymentInsufficientFunds(
            availableBalance: balanceMajor,
            requiredAmount: amount,
          ),
        );
      }
    } catch (e) {
      emit(
        PaymentFailure(
          errorMessage: 'Failed to load wallet: $e',
          failedMethod: const PaymentMethod(
            id: 'error',
            type: PaymentMethodType.wallet,
            title: 'Error',
          ),
        ),
      );
    }
  }

  /// Executes the payment from the wallet to PromptPay.
  Future<void> pay({
    required String recipientPromptPayId,
    required String recipientName,
  }) async {
    final currentState = state;
    if (currentState is! PaymentReady) return;

    emit(PaymentProcessing(method: currentState.method));

    try {
      // Generate unique idempotency key
      final idempotencyKey =
          'pay_${currentState.amount.toInt()}_${DateTime.now().millisecondsSinceEpoch}';

      // Convert amount to satang (minor units)
      final amountInSatang = (currentState.amount * 100).toInt();

      // Call the real Payout API
      final response = await _apiService.payToPromptPay(
        amountInSatang: amountInSatang,
        promptPayId: recipientPromptPayId,
        recipientName: recipientName,
        idempotencyKey: idempotencyKey,
      );

      // Success!
      final transactionId = response['transaction_id'] ?? idempotencyKey;
      final senderName = response['sender_name'];
      final newBalanceRaw = response['new_balance'];
      final remainingBalance = newBalanceRaw != null
          ? (newBalanceRaw as num).toDouble() / 100.0
          : null;

      emit(
        PaymentSuccess(
          transactionId: transactionId,
          senderName: senderName,
          remainingBalance: remainingBalance,
        ),
      );
    } catch (e) {
      emit(
        PaymentFailure(
          errorMessage: e.toString().replaceAll('Exception: ', ''),
          failedMethod: currentState.method,
        ),
      );
    }
  }

  void selectMethod(PaymentMethod method) {
    if (state is PaymentReady) {
      final currentState = state as PaymentReady;
      emit(
        PaymentReady(
          method: method,
          amount: currentState.amount,
          balance: currentState.balance,
        ),
      );
    }
  }
}
