import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:frontend/features/payment/domain/repositories/payment_repository.dart';
import 'package:frontend/features/payment/presentation/logic/payment_state.dart';
import 'package:frontend/core/models/decoded_qr.dart';
import 'package:frontend/core/models/quotation_model.dart';
import 'package:frontend/core/utils/location_service.dart';
class PaymentCubit extends Cubit<PaymentState> {
  final IPaymentRepository _paymentRepository;

  PaymentCubit({
    required IPaymentRepository paymentRepository,
  }) : _paymentRepository = paymentRepository,
       super(PaymentInitial());

  bool _canTransition(PaymentState nextState) {
    final current = state;
    if (current.runtimeType == nextState.runtimeType &&
        (current is PaymentLoading || current is PaymentProcessing || current is PaymentPolling)) {
      return false;
    }

    if (current is PaymentProcessing) {
      return nextState is PaymentSuccess ||
             nextState is PaymentFailure ||
             nextState is PaymentOnRampReady;
    }

    if (current is PaymentPolling) {
      return nextState is PaymentSuccess ||
             nextState is PaymentFailure;
    }

    return true;
  }

  @override
  void emit(PaymentState state) {
    if (isClosed) return;
    if (!_canTransition(state)) {
      debugPrint('🚫 [PaymentCubit] Blocked invalid transition: ${this.state.runtimeType} -> ${state.runtimeType}');
      return;
    }
    super.emit(state);
  }


  Future<void> initialize(double amount, {String? recipientName}) async {
    emit(PaymentLoading());
    try {
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
      final int amountSatang = (amount * 100).round();
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
    required String idempotencyKey,
    String? billerId,
    String? reference1,
    String? reference2,
    String? email,
  }) async {
    final currentState = state;
    if (currentState is! PaymentReady) {
      emit(PaymentFailure(
        errorMessage: 'Invalid state for transaction.',
        failedMethod: const PaymentMethod(
          id: 'pay_per_use',
          type: PaymentMethodType.wallet,
          title: 'Pay per use',
        ),
      ));
      return;
    }

    emit(PaymentProcessing(method: currentState.method));

    try {
      final amountSatang = (currentState.amount * 100).round();
      final sqrilTxId = currentState.sqrilTxId ?? '';

      // Mandatory location check to enforce geofence compliance.
      final location = await getCurrentLocation();

      final result = await _paymentRepository.createOnRampIntent(
        amountSatang: amountSatang,
        sqrilTxId: sqrilTxId,
        promptPayId: promptPayId,
        recipientName: recipientName,
        fiatCurrency: fiatCurrency,
        idempotencyKey: idempotencyKey,
        billerId: billerId,
        reference1: reference1,
        reference2: reference2,
        email: email,
        lat: location.lat,
        lng: location.lng,
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
  /// Polls backend for intent completion using real-time database changes.
  /// Call this after the AlchemyPay checkout closes to detect success/failure.
  Future<void> pollForCompletion(String intentId) async {
    emit(PaymentPolling(intentId: intentId));

    StreamSubscription<String>? subscription;
    Timer? timeoutTimer;
    final completer = Completer<void>();

    void handleStatus(String status) {
      if (isClosed) {
        if (!completer.isCompleted) completer.complete();
        return;
      }

      if (status == 'COMPLETED') {
        emit(PaymentSuccess(
          transactionId: intentId,
          senderName: 'Card Payment',
        ));
        if (!completer.isCompleted) completer.complete();
      } else if (status == 'FAILED' || status == 'ACH_FAILED') {
        emit(PaymentFailure(
          errorMessage: 'Payment did not complete. Please try again.',
          failedMethod: const PaymentMethod(
            id: 'pay_per_use',
            type: PaymentMethodType.wallet,
            title: 'Pay per use',
          ),
        ));
        if (!completer.isCompleted) completer.complete();
      }
    }

    try {
      // 1. Subscribe to Real-time Stream
      subscription = _paymentRepository.watchIntentStatus(intentId).listen(
        handleStatus,
        onError: (e) {
          debugPrint('⚠️ [PaymentCubit] Real-time stream error: $e');
        },
      );

      // 2. Set a 180-second timeout
      timeoutTimer = Timer(const Duration(seconds: 180), () {
        if (!completer.isCompleted) {
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
          completer.complete();
        }
      });

      // Wait until complete (COMPLETED, FAILED, or Timeout)
      await completer.future;

    } catch (e) {
      debugPrint('⚠️ [PaymentCubit] Stream initialization failed, falling back to one-time query: $e');
      // Fallback: If streaming setup fails, run a quick one-time query check
      try {
        final status = await _paymentRepository.getIntentStatus(intentId);
        handleStatus(status);
      } catch (_) {}
    } finally {
      await subscription?.cancel();
      timeoutTimer?.cancel();
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

      final amountInSatang = (currentState.amount * 100).round();

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
          senderName: 'Card Payment',
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
