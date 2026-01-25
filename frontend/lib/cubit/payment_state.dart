import 'package:equatable/equatable.dart';
import '../models/saved_card.dart';

enum PaymentMethodType { applePay, googlePay, card, promptPay }

class PaymentMethod extends Equatable {
  final String id;
  final PaymentMethodType type;
  final String title;
  final String? subtitle;
  final SavedCard? cardData; // Null if it's Apple/Google Pay or PromptPay

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

abstract class PaymentState extends Equatable {
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

  const PaymentReady({
    required this.method,
    required this.amount,
    this.availableMethods = const [],
  });

  @override
  List<Object?> get props => [method, amount, availableMethods];
}

class PaymentProcessing extends PaymentState {
  final PaymentMethod method;

  const PaymentProcessing({required this.method});

  @override
  List<Object?> get props => [method];
}

class PaymentSuccess extends PaymentState {
  final String transactionId;

  const PaymentSuccess({required this.transactionId});

  @override
  List<Object?> get props => [transactionId];
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
