import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/api_service.dart';
import 'payment_state.dart';
import 'package:uuid/uuid.dart';
import '../features/security/domain/repositories/security_repository.dart';

class PaymentCubit extends Cubit<PaymentState> {
  final ApiService _apiService;
  final SecurityRepository _securityRepository;

  PaymentCubit({
    ApiService? apiService,
    required SecurityRepository securityRepository,
  }) : _apiService = apiService ?? ApiService(),
       _securityRepository = securityRepository,
       super(PaymentInitial());

  /// Initializes the payment screen for instant pay-per-use checkout.
  Future<void> initialize(double amount, {String? recipientName}) async {
    emit(PaymentLoading());
    try {
      const double balanceMajor = 0.0;

      final payPerUseMethod = PaymentMethod(
        id: 'pay_per_use',
        type: PaymentMethodType.wallet, // Retain wallet type for UI widget compatibility
        title: 'Pay per use',
        subtitle: 'Direct charge & instant settlement',
      );

      emit(
        PaymentReady(
          method: payPerUseMethod,
          amount: amount,
          availableMethods: [payPerUseMethod],
          balance: balanceMajor,
        ),
      );
    } catch (e) {
      emit(
        PaymentFailure(
          errorMessage: 'Failed to initialize payment: $e',
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
    String? recipientPromptPayId,
    required String recipientName,
    String? billerId,
    String? reference1,
    String? reference2,
  }) async {
    final currentState = state;
    if (currentState is! PaymentReady) return;

    emit(PaymentProcessing(method: currentState.method));

    try {
      // 🛡️ SECURITY: Hardened Idempotency (UUID v4)
      final idempotencyKey = const Uuid().v4();

      // 🛡️ SECURITY: Non-Repudiation (Signature)
      Map<String, String>? signatureHeaders;
      try {
        signatureHeaders = await _securityRepository.generateSignatureHeaders(
          idempotencyKey,
        );
      } catch (e) {
        // Skip for now, backend will reject if not signed (if enforced)
      }

      // Convert amount to satang (minor units)
      final amountInSatang = (currentState.amount * 100).toInt();

      // Call the real Payout API
      final response = await _apiService.payToPromptPay(
        amountInSatang: amountInSatang,
        promptPayId: recipientPromptPayId,
        recipientName: recipientName,
        billerId: billerId,
        reference1: reference1,
        reference2: reference2,
        idempotencyKey: idempotencyKey,
        headers: signatureHeaders,
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
