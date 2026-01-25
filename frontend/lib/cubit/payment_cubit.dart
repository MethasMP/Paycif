import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/api_service.dart';
import 'payment_state.dart';
import '../models/saved_card.dart';

class PaymentCubit extends Cubit<PaymentState> {
  final ApiService _apiService;

  PaymentCubit({ApiService? apiService})
    : _apiService = apiService ?? ApiService(),
      super(PaymentInitial());

  Future<void> initialize(double amount) async {
    emit(PaymentLoading());
    try {
      // 1. Fetch User Profile & Cards
      // In a real app, these might already be cached or passed in.
      final results = await Future.wait([
        _apiService.getUserProfile(),
        _apiService.getSavedCards(),
      ]);

      final profile = results[0] as Map<String, dynamic>?;
      final cards = results[1] as List<SavedCard>;

      // 2. Determine Available Methods
      final availableMethods = <PaymentMethod>[];
      if (Platform.isIOS) {
        availableMethods.add(
          const PaymentMethod(
            id: 'apple_pay',
            type: PaymentMethodType.applePay,
            title: 'Apple Pay',
            subtitle: 'Fast and secure',
          ),
        );
      }
      availableMethods.addAll(cards.map(_mapCardToMethod));

      // 3. Determine Default Method
      final defaultMethod = _selectDefaultMethod(profile, cards);

      emit(
        PaymentReady(
          method: defaultMethod,
          amount: amount,
          availableMethods: availableMethods,
        ),
      );
    } catch (e) {
      // If initialization fails, we might default to "Add Card" state or retry.
      // For now, let's assume we can at least show a "Needs Setup" state if empty.
      // But strictly following the design: "No Method Available" triggers Add Card.
      // For simplicity here, we'll emit a "No Method" state wrapped in Ready?
      // Actually, let's allow PaymentReady to have a "None" method type for that case.
      // But for now, closest valid fallback:
      emit(
        PaymentFailure(
          errorMessage: "Failed to load payment methods",
          failedMethod: const PaymentMethod(
            id: 'error',
            type: PaymentMethodType.card,
            title: 'Error',
          ),
        ),
      );
    }
  }

  PaymentMethod _selectDefaultMethod(
    Map<String, dynamic>? profile,
    List<SavedCard> cards,
  ) {
    // Priority 1: Device Wallet (Apple Pay / Google Pay)
    if (Platform.isIOS) {
      // Check if user has Apple Pay setup (mocked check for now)
      // In production: await Stripe.instance.isApplePaySupported();
      return const PaymentMethod(
        id: 'apple_pay',
        type: PaymentMethodType.applePay,
        title: 'Apple Pay',
        subtitle: 'Fast and secure',
      );
    }
    // Android Google Pay logic would go here

    // Priority 2: User's Preferred Method
    if (profile != null) {
      final preferredId = profile['preferred_payment_method_id'];
      if (preferredId != null) {
        // Try to find it in cards
        try {
          final preferredCard = cards.firstWhere((c) => c.id == preferredId);
          return _mapCardToMethod(preferredCard);
        } catch (_) {
          // Preferred card might be deleted or invalid, fall through
        }
      }
    }

    // Priority 3: Most Recently Used / First Card
    if (cards.isNotEmpty) {
      // Sort by lastUsedAt descending
      cards.sort((a, b) {
        if (a.lastUsedAt == null && b.lastUsedAt == null) return 0;
        if (a.lastUsedAt == null) return 1;
        if (b.lastUsedAt == null) return -1;
        return b.lastUsedAt!.compareTo(a.lastUsedAt!);
      });

      return _mapCardToMethod(cards.first);
    }

    // Priority 4: No Method (Trigger Add Card flow in UI)
    // We'll return a placeholder that UI recognizes to show "Add Card"
    return const PaymentMethod(
      id: 'add_new',
      type: PaymentMethodType.card,
      title: 'Add Payment Method',
    );
  }

  PaymentMethod _mapCardToMethod(SavedCard card) {
    return PaymentMethod(
      id: card.id,
      type: PaymentMethodType.card,
      title: '${card.brand} •••• ${card.lastDigits}',
      subtitle: 'Expires ${card.formattedExpiry}',
      cardData: card,
    );
  }

  Future<void> pay() async {
    final currentState = state;
    if (currentState is! PaymentReady) return;

    final method = currentState.method;

    // Guard: If it's the "Add New" placeholder, we shouldn't "pay" yet.
    if (method.id == 'add_new') return;

    emit(PaymentProcessing(method: method));

    try {
      // Simulate Payment Processing
      await Future.delayed(const Duration(seconds: 2));

      // Success!
      emit(const PaymentSuccess(transactionId: 'tx_mock_12345'));
    } catch (e) {
      emit(PaymentFailure(errorMessage: e.toString(), failedMethod: method));
      // Auto-recovery logic could be triggered here or in the UI listener
    }
  }

  void selectMethod(PaymentMethod method) {
    if (state is PaymentReady) {
      emit(
        PaymentReady(method: method, amount: (state as PaymentReady).amount),
      );
    }
  }
}
