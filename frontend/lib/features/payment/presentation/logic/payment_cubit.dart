import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import 'package:frontend/features/payment/domain/repositories/payment_repository.dart';
import 'package:frontend/features/payment/presentation/logic/payment_state.dart';

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
      final decodeResp = await _paymentRepository.decodeQR(qrString);
      final bool isBusiness = decodeResp['is_business'] ?? false;
      final String? sqrilTxId = decodeResp['tx_id'];

      if (!isBusiness) {
        throw Exception('PERSONAL_QR_NOT_SUPPORTED');
      }

      if (sqrilTxId == null) {
        throw Exception('Failed to decode QR code identifier.');
      }

      // 2. Fetch Quotation via Backend/SQRIL
      final int amountSatang = (amount * 100).toInt();
      double rate = 36.45;
      double feeUSD = 0.0;
      double amountUSD = 0.0;

      if (amountSatang > 0) {
        final quoteResp = await _paymentRepository.getQuotation(sqrilTxId, amountSatang);
        rate = (quoteResp['exchange_rate'] as num?)?.toDouble() ?? 36.45;
        feeUSD = (quoteResp['fee'] as num?)?.toDouble() ?? 0.0;
        amountUSD = (quoteResp['amount_usd'] as num?)?.toDouble() ?? (amount / rate);
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
