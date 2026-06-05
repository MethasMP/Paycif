import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../domain/repositories/payment_repository.dart';
import '../../domain/entities/payment_breakdown.dart';
import 'payment_state.dart';

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

      final breakdown = PaymentBreakdown(amountTHB: currentState.amount);
      final amountInSatang = (breakdown.amountTHB * 100).toInt();

      final transactionId = await _paymentRepository.payToPromptPay(
        amountInSatang: amountInSatang,
        recipientName: recipientName,
        promptPayId: recipientPromptPayId,
        billerId: billerId,
        reference1: reference1,
        reference2: reference2,
        idempotencyKey: idempotencyKey,
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
        ),
      );
    }
  }
}
