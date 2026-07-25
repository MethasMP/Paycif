import 'package:equatable/equatable.dart';
import 'package:frontend/features/profile/domain/saved_card.dart';

enum PaymentMethodType { wallet, applePay, googlePay, card, promptPay }

class PaymentMethod extends Equatable {
  final String id;
  final PaymentMethodType type;
  final String title;
  final String? subtitle;
  final SavedCard? cardData;

  const PaymentMethod({
    required this.id,
    required this.type,
    required this.title,
    this.subtitle,
    this.cardData,
  });

  @override
  List<Object?> get props => [id, type, title, subtitle, cardData];
}

sealed class PaymentState extends Equatable {
  const PaymentState();

  @override
  List<Object?> get props => [];
}

class PaymentInitial extends PaymentState {}

class PaymentLoading extends PaymentState {}

class PaymentReady extends PaymentState {
  final PaymentMethod method;
  final double amount;
  final List<PaymentMethod> availableMethods;
  final String? sqrilTxId;
  final double? exchangeRate;
  final double? feeUSD;
  final double? totalUSD;
  final bool? isBusiness;

  const PaymentReady({
    required this.method,
    required this.amount,
    this.availableMethods = const [],
    this.sqrilTxId,
    this.exchangeRate,
    this.feeUSD,
    this.totalUSD,
    this.isBusiness,
  });

  @override
  List<Object?> get props => [
        method,
        amount,
        availableMethods,
        sqrilTxId,
        exchangeRate,
        feeUSD,
        totalUSD,
        isBusiness,
      ];
}

class PaymentProcessing extends PaymentState {
  final PaymentMethod method;

  const PaymentProcessing({required this.method});

  @override
  List<Object?> get props => [method];
}

class PaymentSuccess extends PaymentState {
  final String transactionId;
  final String? senderName;

  const PaymentSuccess({
    required this.transactionId,
    this.senderName,
  });

  @override
  List<Object?> get props => [transactionId, senderName];
}

class PaymentFailure extends PaymentState {
  final String errorMessage;
  final PaymentMethod failedMethod;

  const PaymentFailure({
    required this.errorMessage,
    required this.failedMethod,
  });

  @override
  List<Object?> get props => [errorMessage, failedMethod];
}

/// AlchemyPay checkout URL is ready — Flutter should open it immediately.
class PaymentOnRampReady extends PaymentState {
  final String webUrl;
  final String intentId;
  final PaymentMethod method;

  const PaymentOnRampReady({
    required this.webUrl,
    required this.intentId,
    required this.method,
  });

  @override
  List<Object?> get props => [webUrl, intentId, method];
}

/// Checkout launched — polling backend until COMPLETED or FAILED.
class PaymentPolling extends PaymentState {
  final String intentId;

  const PaymentPolling({required this.intentId});

  @override
  List<Object?> get props => [intentId];
}
