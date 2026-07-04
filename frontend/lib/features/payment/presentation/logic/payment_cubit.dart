import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import 'package:frontend/features/payment/domain/repositories/payment_repository.dart';
import 'package:frontend/features/payment/presentation/logic/payment_state.dart';
import 'package:frontend/core/models/decoded_qr.dart';
import 'package:frontend/core/models/quotation_model.dart';
class PaymentCubit extends Cubit<PaymentState> {
  final IPaymentRepository _paymentRepository;

  PaymentCubit({
    required IPaymentRepository paymentRepository,
  }) : _paymentRepository = paymentRepository,
       super(PaymentInitial());

  Future<void> initialize(double amount, {String? recipientName}) async {
    emit(PaymentLoading());
    try {
      const double balanceMajor = 0.0;

      const payPerUseMethod = PaymentMethod(
        id: 'pay_per_use',
        type: PaymentMethodType.wallet,
        title: 'Pay per use',
        subtitle: 'Direct charge & instant settlement',
      );

      emit(
        PaymentReady(
          method: payPerUseMethod,
          amount: amount,
          availableMethods: const [payPerUseMethod],
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

  Future<void> initializeWithQR({
    required String qrString,
    required double amount,
  }) async {
    emit(PaymentLoading());
    try {
      // 1. Decode QR via Backend/SQRIL
      final DecodedQr decodeResp = await _paymentRepository.decodeQR(qrString);
      final bool isBusiness = decodeResp.isBusiness;
      final String sqrilTxId = decodeResp.txId;



      if (sqrilTxId.isEmpty) {
        throw Exception('Failed to decode QR code identifier.');
      }

      // 2. Fetch Quotation via Backend/SQRIL
      final int amountSatang = (amount * 100).toInt();
      double rate = 36.45;
      double feeUSD = 0.0;
      double amountUSD = 0.0;

      if (amountSatang > 0) {
        final QuotationModel quoteResp = await _paymentRepository.getQuotation(sqrilTxId, amountSatang);
        rate = quoteResp.exchangeRate;
        feeUSD = quoteResp.fee;
        amountUSD = quoteResp.amountUsd;
      }

      const payPerUseMethod = PaymentMethod(
        id: 'pay_per_use',
        type: PaymentMethodType.wallet,
        title: 'Pay per use',
        subtitle: 'Direct charge & instant settlement',
      );

      emit(
        PaymentReady(
          method: payPerUseMethod,
          amount: amount,
          availableMethods: const [payPerUseMethod],
          balance: 0.0,
          sqrilTxId: sqrilTxId,
          exchangeRate: rate,
          feeUSD: feeUSD,
          totalUSD: amountUSD + feeUSD,
          isBusiness: isBusiness,
        ),
      );
    } catch (e) {
      String errMsg = e.toString().replaceAll('Exception: ', '');
      emit(
        PaymentFailure(
          errorMessage: errMsg,
          failedMethod: const PaymentMethod(
            id: 'error',
            type: PaymentMethodType.wallet,
            title: 'Error',
          ),
        ),
      );
    }
  }

  /// Pay-per-use on-ramp: creates a PayoutIntent on the backend, which returns
  /// an AlchemyPay checkout URL. Flutter opens that URL; when the user completes
  /// payment, the backend webhook fires → SQRIL off-ramp → PromptPay.
  Future<void> initiateOnRamp({
    required String promptPayId,
    required String recipientName,
    required String fiatCurrency,
    String? billerId,
    String? reference1,
    String? reference2,
    String? email,
  }) async {
    final currentState = state;
    if (currentState is! PaymentReady) return;

    emit(PaymentProcessing(method: currentState.method));

    try {
      final amountSatang = (currentState.amount * 100).toInt();
      final sqrilTxId = currentState.sqrilTxId ?? '';

      final result = await _paymentRepository.createOnRampIntent(
        amountSatang: amountSatang,
        sqrilTxId: sqrilTxId,
        promptPayId: promptPayId,
        recipientName: recipientName,
        fiatCurrency: fiatCurrency,
        billerId: billerId,
        reference1: reference1,
        reference2: reference2,
        email: email,
      );

      if (isClosed) return;

      emit(PaymentOnRampReady(
        webUrl: result.webUrl,
        intentId: result.intentId,
        method: currentState.method,
      ));
    } catch (e) {
      if (isClosed) return;
      emit(PaymentFailure(
        errorMessage: e.toString().replaceAll('Exception: ', ''),
        failedMethod: currentState.method,
      ));
    }
  }

  /// Polls backend for intent completion. Call this after the AlchemyPay
  /// checkout closes (redirect/deep-link) to detect success or failure.
  Future<void> pollForCompletion(String intentId) async {
    emit(PaymentPolling(intentId: intentId));

    const maxAttempts = 45; // 45 × 2s = 90s max
    for (var i = 0; i < maxAttempts; i++) {
      if (isClosed) return;
      await Future.delayed(const Duration(seconds: 2));
      if (isClosed) return;

      try {
        final status = await _paymentRepository.getIntentStatus(intentId);

        if (status == 'COMPLETED') {
          emit(PaymentSuccess(
            transactionId: intentId,
            senderName: 'Card Payment',
            remainingBalance: 0.0,
          ));
          return;
        }

        if (status == 'FAILED' || status == 'ACH_FAILED') {
          emit(PaymentFailure(
            errorMessage: 'Payment did not complete. Please try again.',
            failedMethod: const PaymentMethod(
              id: 'pay_per_use',
              type: PaymentMethodType.wallet,
              title: 'Pay per use',
            ),
          ));
          return;
        }
        // PENDING / PAYMENT_SUCCESS_PAYOUT_PENDING → keep polling
      } catch (_) {
        // Network blip — keep polling
      }
    }

    // Timeout: payment may still succeed via webhook. Show neutral message.
    if (!isClosed) {
      emit(PaymentFailure(
        errorMessage: 'Payment is being confirmed. Check your transaction history in a moment.',
        failedMethod: const PaymentMethod(
          id: 'pay_per_use',
          type: PaymentMethodType.wallet,
          title: 'Pay per use',
        ),
      ));
    }
  }

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
      final idempotencyKey = const Uuid().v4();

      final amountInSatang = (currentState.amount * 100).toInt();

      final transactionId = await _paymentRepository.payToPromptPay(
        amountInSatang: amountInSatang,
        recipientName: recipientName,
        promptPayId: recipientPromptPayId,
        billerId: billerId,
        reference1: reference1,
        reference2: reference2,
        idempotencyKey: idempotencyKey,
        sqrilTxId: currentState.sqrilTxId,
      );

      if (isClosed) return;

      emit(
        PaymentSuccess(
          transactionId: transactionId,
          senderName: 'Tourist Wallet',
          remainingBalance: 0.0,
        ),
      );
    } catch (e) {
      if (isClosed) return;
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
          sqrilTxId: currentState.sqrilTxId,
          exchangeRate: currentState.exchangeRate,
          feeUSD: currentState.feeUSD,
          totalUSD: currentState.totalUSD,
          isBusiness: currentState.isBusiness,
        ),
      );
    }
  }
}
