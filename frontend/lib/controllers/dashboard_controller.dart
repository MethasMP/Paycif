import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
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
    );
  }
}

// Controller (Cubit)
class DashboardController extends Cubit<DashboardState> {
  final DashboardRepository _repository;
  StreamSubscription? _walletSub;
  StreamSubscription? _txSub;
  String? _subscribedWalletId;

  DashboardController(this._repository) : super(DashboardState());

  @override
  Future<void> close() {
    _walletSub?.cancel();
    _txSub?.cancel();
    return super.close();
  }

  void init() {
    _startSubscriptions(showLoading: true);
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
        // Handle error...
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
            // Only set status to 'success' if BOTH Wallet and Transactions are ready.
            if (newState.wallet != null) {
              emit(newState.copyWith(status: 'success'));
            } else {
              emit(newState); // Keep loading
            }
          },
          onError: (e) {
            // Even on error, we might want to finish loading with empty transactions?
            // For now, let's assume retry or silent fail.
            // If critical, set isTransactionsLoaded = true (empty) so UI unblocks.
            emit(state.copyWith(isTransactionsLoaded: true));
          },
        );
  }

  // ... (changeCurrency kept same)

  Future<void> _updateWithNewWallet(Wallet wallet) async {
    // 1. Update Wallet immediately
    // Don't set 'success' yet - wait for transactions!
    var currentState = state.copyWith(
      wallet: wallet,
      // status: 'success', // <--- REMOVED: Wait for sync
    );

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
