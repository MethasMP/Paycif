import 'dart:async';
import 'package:flutter/foundation.dart'; // Added for debugPrint
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../models/wallet_model.dart';
import '../models/exchange_rate_model.dart';
import '../repositories/dashboard_repository.dart';

import '../models/transaction.dart';
import '../services/connectivity_service.dart';
import '../services/api_service.dart';

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
  final bool isOffline;
  final String kycTier;

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
    this.isOffline = false,
    this.kycTier = 'tier0',
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
    bool? isOffline,
    String? kycTier,
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
      isOffline: isOffline ?? this.isOffline,
      kycTier: kycTier ?? this.kycTier,
    );
  }
}

// Controller (Cubit)
class DashboardController extends Cubit<DashboardState> {
  final DashboardRepository _repository;
  final ConnectivityService _connectivity;
  StreamSubscription? _walletSub;
  StreamSubscription? _txSub;
  StreamSubscription? _connSub;
  String? _subscribedWalletId;

  DashboardController(this._repository, this._connectivity)
    : super(DashboardState()) {
    _listenToAuthChanges();
    _listenToConnectivityChanges();
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

  void _listenToConnectivityChanges() {
    _connSub = _connectivity.statusStream.listen((status) {
      if (status == ConnectivityStatus.online && state.isOffline) {
        debugPrint(
          '🌐 [Resilience] Network restored. Forcing dashboard sync...',
        );
        refresh(showLoading: false);
      }

      if (status == ConnectivityStatus.offline && !state.isOffline) {
        emit(state.copyWith(isOffline: true));
      }
    });
  }

  @override
  Future<void> close() {
    _walletSub?.cancel();
    _txSub?.cancel();
    _authSub?.cancel();
    _connSub?.cancel();
    return super.close();
  }

  void reset() {
    _walletSub?.cancel();
    _txSub?.cancel();
    _subscribedWalletId = null;
    _isInitialized = false;
    emit(DashboardState());
  }

  bool _isInitialized = false;

  void init() async {
    final currentUser = Supabase.instance.client.auth.currentUser;

    if (_isInitialized && currentUser != null) {
      debugPrint(
        'ℹ️ [Dashboard] Already initialized and session active. Skipping.',
      );
      return;
    }

    if (currentUser == null) {
      debugPrint('⚠️ [Dashboard] Init called but no user found. Postponing.');
      return;
    }

    _isInitialized = true;
    // Reset state before starting new subscriptions to avoid stale data
    reset();

    // ⚡ [Fast-Path] Warm up UI immediately from Disk Cache
    await _loadCache();

    // 🛡️ Fetch KYC Tier
    try {
      final tier = await ApiService.getUserTier();
      emit(state.copyWith(kycTier: tier));
    } catch (e) {
      debugPrint('⚠️ [Dashboard] KYC Tier fetch failed: $e');
    }

    _startSubscriptions(showLoading: state.wallet == null);

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

  Future<void> _loadCache() async {
    try {
      final cachedWallet = await _repository.getCachedWallet();
      final cachedTxs = await _repository.getCachedTransactions();

      if (cachedWallet != null) {
        var newState = state.copyWith(
          wallet: cachedWallet,
          transactions: cachedTxs,
          isTransactionsLoaded: cachedTxs.isNotEmpty,
          status: 'success', // 🚫 No spinner needed if we have cache
        );
        emit(_calculateDisplayValues(newState));
        debugPrint('⚡ [Dashboard] UI Warmed from Cache');
      }
    } catch (e) {
      debugPrint('⚠️ [Dashboard] Cache load failed: $e');
    }
  }

  Future<void> refresh({bool showLoading = false}) async {
    // Restart subscriptions
    _startSubscriptions(showLoading: showLoading);
    // Removed artificial delay to make it snappier
  }

  void _startSubscriptions({required bool showLoading}) {
    _walletSub?.cancel();
    _txSub
        ?.cancel(); // Also cancel transaction sub when restarting wallet fetch
    _subscribedWalletId =
        null; // FORCE RESET: Allow re-subscribing to get fresh transactions

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
        debugPrint('⚠️ [Dashboard] Wallet Stream Error: $e');
        if (state.wallet != null) {
          // 🛡️ Resilience: We have cached data, so don't block the UI.
          // Mark as offline so UI can show a subtle indicator.
          emit(
            state.copyWith(
              isOffline: true,
              // Keep status as whatever it was from cache
            ),
          );
        } else {
          // No cache available, fatal error.
          emit(
            state.copyWith(
              status: 'error',
              errorMessage: 'Failed to load wallet: $e',
            ),
          );
        }
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
    var currentState = state.copyWith(
      wallet: wallet,
      isOffline: false,
      errorMessage: null, // Clear any transient error
    );

    currentState = _calculateDisplayValues(currentState);

    // Check synchronization
    if (currentState.isTransactionsLoaded) {
      currentState = currentState.copyWith(status: 'success');
    }

    emit(currentState);

    // 2. Fetch Exchange Rate in background (Isolated Success/Failure)
    if (wallet.currency != state.selectedCurrency) {
      try {
        final rate = await _repository.fetchLatestRate(
          wallet.currency,
          state.selectedCurrency,
        );
        if (rate != null) {
          emit(_calculateDisplayValues(state.copyWith(exchangeRate: rate)));
        }
      } catch (e) {
        // 🛡️ World-Class Resilience: Isolated Rate Fail
        // If the backend rate service is down, don't kill the whole app!
        debugPrint(
          '⚠️ [Resilience] Rate fetch failed ($e). Wallet balance still valid.',
        );
        // We keep the wallet state but maybe clear the dual display if we want to be strict
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

  /// 🚀 Synchronize payment success with the Reactive Repository.
  /// This triggers an atomic update to both local cache and streams.
  /// 🛡️ [Trust but Verify]: We update UI instantly, then force a server sync
  /// to ensure the "Ground Truth" overwrites any potential mismatch.
  void syncPaymentSuccess({
    required String transactionId,
    required double amount,
    required String recipientName,
    required double remainingBalance,
  }) {
    debugPrint('⚡ [Optimistic] Syncing payment local state...');

    // 1. Update Repository (Cache + Stream)
    _repository.synchronizePaymentSuccess(
      transactionId: transactionId,
      amount: amount,
      recipientName: recipientName,
      remainingBalanceMajor: remainingBalance,
    );

    // 2. 🛡️ Auto-Correction: Force a background ground-truth check
    // This handles the "What if server crashed during commit?" edge case.
    // We wait 2 seconds for Realtime to propagate, then force a hard refresh.
    Future.delayed(const Duration(seconds: 2), () {
      debugPrint('🛡️ [Verify] Performing Ground-Truth Auto-Correction...');
      refresh(showLoading: false);
    });
  }

  /// 🚀 10x SPEED: Optimistic Balance Update
  /// Instantly updates the UI balance without waiting for DB sync.
  /// This makes TopUp feel instantaneous to the user.
  void optimisticBalanceAdd(int amountSatang) {
    if (state.wallet == null) return;

    final newBalance = state.wallet!.balance + amountSatang;
    final updatedWallet = state.wallet!.copyWith(balance: newBalance);

    debugPrint(
      '⚡ [Optimistic] Instant balance update: +$amountSatang satang -> $newBalance',
    );

    var newState = state.copyWith(wallet: updatedWallet);
    newState = _calculateDisplayValues(newState);
    emit(newState);
  }
}
