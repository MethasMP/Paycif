import 'dart:async';
import 'package:flutter/foundation.dart'; // Added for debugPrint
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../models/wallet_model.dart';
import '../models/exchange_rate_model.dart';
import '../repositories/dashboard_repository.dart';

import '../models/transaction.dart';

// State
class DashboardState {
  final Wallet? wallet;
  final ExchangeRate? exchangeRate;
  final bool isBalanceVisible;
  final String formattedBalance;
  final String? dualCurrencyDisplay; // e.g., "≈ 12,500.00 EUR"
  final String status; // 'initial', 'loading', 'success', 'error'
  final String? errorMessage;
  final String selectedCurrency;
  final List<Transaction> transactions; // Restored missing field
  final bool isTransactionsLoaded;
  final bool isDataWarmed;

  DashboardState({
    this.wallet,
    this.exchangeRate,
    this.isBalanceVisible = true,
    this.formattedBalance = '--.--',
    this.dualCurrencyDisplay,
    this.status = 'initial',
    this.errorMessage,
    this.selectedCurrency = 'USD', // Default to USD
    this.transactions = const [],
    this.isTransactionsLoaded = false,
    this.isDataWarmed = false,
  });

  DashboardState copyWith({
    Wallet? wallet,
    ExchangeRate? exchangeRate,
    bool? isBalanceVisible,
    String? formattedBalance,
    String? dualCurrencyDisplay,
    String? status,
    String? errorMessage,
    String? selectedCurrency,
    List<Transaction>? transactions,
    bool? isTransactionsLoaded,
    bool? isDataWarmed,
  }) {
    return DashboardState(
      wallet: wallet ?? this.wallet,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      isBalanceVisible: isBalanceVisible ?? this.isBalanceVisible,
      formattedBalance: formattedBalance ?? this.formattedBalance,
      dualCurrencyDisplay: dualCurrencyDisplay ?? this.dualCurrencyDisplay,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      selectedCurrency: selectedCurrency ?? this.selectedCurrency,
      transactions: transactions ?? this.transactions,
      isTransactionsLoaded: isTransactionsLoaded ?? this.isTransactionsLoaded,
      isDataWarmed: isDataWarmed ?? this.isDataWarmed,
    );
  }
}

// Controller (Cubit)
class DashboardController extends Cubit<DashboardState> {
  final DashboardRepository _repository;
  StreamSubscription? _walletSub;
  StreamSubscription? _txSub;
  String? _subscribedWalletId;

  DashboardController(this._repository) : super(DashboardState()) {
    _listenToAuthChanges();
  }

  StreamSubscription? _authSub;

  void _listenToAuthChanges() {
    _authSub = _repository.authStream.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.initialSession) {
        init();
      } else if (event == AuthChangeEvent.signedOut) {
        reset();
      }
    });
  }

  @override
  Future<void> close() {
    _walletSub?.cancel();
    _txSub?.cancel();
    _authSub?.cancel();
    return super.close();
  }

  void reset() {
    _walletSub?.cancel();
    _txSub?.cancel();
    _subscribedWalletId = null;
    emit(DashboardState());
  }

  void init() {
    // Reset state before starting new subscriptions to avoid stale data
    reset();
    _startSubscriptions(showLoading: true);

    // 10x Eager Loading: Speculative Rate Prefetch
    // Most users use THB/USD. Warming this now saves ~200-500ms later.
    _repository.fetchLatestRate('THB', 'USD').then((rate) {
      if (rate != null && state.wallet == null) {
        // Only update if we still don't have a wallet (to avoid overwriting valid logic)
        // Actually, just warming the ApiService cache is enough.
        debugPrint('🔥 [Audit] Speculative Rate Warmed: THB/USD');
      }
    });
  }

  Future<void> refresh() async {
    // Restart subscriptions without clearing UI
    _startSubscriptions(showLoading: false);
    // Artificial delay to let the UI show the refresh spinner for a moment
    // In a real app, we might wait for the first data emission.
    await Future.delayed(const Duration(seconds: 1));
  }

  void _startSubscriptions({required bool showLoading}) {
    _walletSub?.cancel();
    _txSub
        ?.cancel(); // Also cancel transaction sub when restarting wallet fetch

    if (showLoading) {
      emit(state.copyWith(status: 'loading', isTransactionsLoaded: false));
    }

    // 1. Subscribe to Wallet Stream
    _walletSub = _repository.fetchUserWallet().listen(
      (wallet) {
        if (wallet == null) {
          _repository.createWalletManually();
          // If creation is async, we might remain loading until next emit.
          // Or we should emit error if it takes too long.
        } else {
          _updateWithNewWallet(wallet);
          // Subscribe to transactions only if not already subscribed or ID changed
          if (_subscribedWalletId != wallet.id) {
            _subscribeToTransactions(wallet.id);
            _subscribedWalletId = wallet.id;
          }
        }
      },
      onError: (e) {
        emit(
          state.copyWith(
            status: 'error',
            errorMessage: 'Failed to load wallet: $e',
          ),
        );
      },
    );
  }

  void _subscribeToTransactions(String walletId) {
    _txSub?.cancel(); // Ensure previous sub is cancelled
    _txSub = _repository
        .fetchTransactions(walletId)
        .listen(
          (transactions) {
            final newState = state.copyWith(
              transactions: transactions,
              isTransactionsLoaded: true,
            );

            // Synchronized Display Logic:
            // Only set status to 'success' and 'isDataWarmed' to true
            // if BOTH Wallet and Transactions are ready.
            if (newState.wallet != null) {
              debugPrint(
                '🔥 [Audit] Dashboard Warmed: Data finalized for IDE: ${newState.wallet?.id}',
              );
              emit(newState.copyWith(status: 'success', isDataWarmed: true));
            } else {
              emit(newState); // Keep loading
            }
          },
          onError: (e) {
            debugPrint('⚠️ [Audit] Transaction Stream Error: $e');
            // On transaction error, we still want to show the wallet balance.
            final newState = state.copyWith(
              isTransactionsLoaded: true,
              isDataWarmed:
                  true, // Allow proceeding even if tx fails (resilience)
            );

            if (newState.wallet != null) {
              emit(newState.copyWith(status: 'success'));
            } else {
              emit(newState);
            }
          },
        );
  }

  // ... (changeCurrency kept same)

  Future<void> _updateWithNewWallet(Wallet wallet) async {
    debugPrint('🔥 [Audit] Wallet Received: ID=${wallet.id}');
    // 1. Update Wallet immediately
    var currentState = state.copyWith(wallet: wallet);

    currentState = _calculateDisplayValues(currentState);

    // Check synchronization
    if (currentState.isTransactionsLoaded) {
      currentState = currentState.copyWith(status: 'success');
    }

    emit(currentState);

    // 2. Fetch Exchange Rate in background
    if (wallet.currency != state.selectedCurrency) {
      try {
        final rate = await _repository.fetchLatestRate(
          wallet.currency,
          state.selectedCurrency,
        );
        emit(_calculateDisplayValues(state.copyWith(exchangeRate: rate)));
      } catch (e) {
        // Silently fail
      }
    }
  }

  void toggleBalanceVisibility() {
    final newState = state.copyWith(isBalanceVisible: !state.isBalanceVisible);
    emit(_calculateDisplayValues(newState));
  }

  DashboardState _calculateDisplayValues(DashboardState currentState) {
    if (currentState.wallet == null) return currentState;

    if (!currentState.isBalanceVisible) {
      return currentState.copyWith(
        formattedBalance: '••••••',
        dualCurrencyDisplay: '••••••',
      );
    }

    final balanceMajor =
        currentState.wallet!.balance / 100.0; // Assuming minor units (cents)
    final formatter = NumberFormat.currency(
      symbol: '',
      decimalDigits: 2,
      locale: 'en_US', // Creates "1,000.00" format
    );

    final mainDisplay = formatter.format(balanceMajor);

    String? secondaryDisplay;
    if (currentState.exchangeRate != null) {
      // Estimate Value
      final estimatedVal = currentState.wallet!.getEstimatedHomeValue(
        currentState.exchangeRate!,
      );
      // Wallet balance is minor. getEstimated uses minor * rate.
      // If Rate is 1.0 (THB/THB), result is minor.
      // Convert to Major for display.
      final estimatedMajor = estimatedVal / 100.0;

      final secondaryFmt = NumberFormat.currency(
        symbol: currentState.exchangeRate!.toCurrency,
        decimalDigits: 2,
      ).format(estimatedMajor);

      secondaryDisplay = "≈ $secondaryFmt";
    }

    return currentState.copyWith(
      formattedBalance: mainDisplay,
      dualCurrencyDisplay: secondaryDisplay,
    );
  }

  Future<String> runDiagnostic() async {
    return _repository.runWalletDiagnostic();
  }
}
