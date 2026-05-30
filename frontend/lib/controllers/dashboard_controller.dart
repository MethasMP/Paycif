import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/dashboard_repository.dart';
import '../models/transaction.dart';
import '../services/connectivity_service.dart';
import '../services/api_service.dart';

class DashboardState {
  final String status; // 'initial', 'loading', 'success', 'error'
  final String? errorMessage;
  final List<Transaction> transactions;
  final bool isTransactionsLoaded;
  final bool isOffline;
  final String kycTier;

  DashboardState({
    this.status = 'initial',
    this.errorMessage,
    this.transactions = const [],
    this.isTransactionsLoaded = false,
    this.isOffline = false,
    this.kycTier = 'tier0',
  });

  bool get isDataWarmed => status == 'success';

  DashboardState copyWith({
    String? status,
    String? errorMessage,
    List<Transaction>? transactions,
    bool? isTransactionsLoaded,
    bool? isOffline,
    String? kycTier,
  }) {
    return DashboardState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      transactions: transactions ?? this.transactions,
      isTransactionsLoaded: isTransactionsLoaded ?? this.isTransactionsLoaded,
      isOffline: isOffline ?? this.isOffline,
      kycTier: kycTier ?? this.kycTier,
    );
  }
}

class DashboardController extends Cubit<DashboardState> {
  final DashboardRepository _repository;
  final ConnectivityService _connectivity;
  StreamSubscription? _txSub;
  StreamSubscription? _connSub;
  StreamSubscription? _authSub;

  DashboardController(this._repository, this._connectivity) : super(DashboardState()) {
    _listenToAuthChanges();
    _listenToConnectivityChanges();
  }

  void _listenToAuthChanges() {
    _authSub = _repository.authStream.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.initialSession) {
        init();
      } else if (event == AuthChangeEvent.signedOut) {
        reset();
      }
    });
  }

  void _listenToConnectivityChanges() {
    _connSub = _connectivity.statusStream.listen((status) {
      if (status == ConnectivityStatus.online && state.isOffline) {
        refresh();
      }
      if (status == ConnectivityStatus.offline && !state.isOffline) {
        emit(state.copyWith(isOffline: true));
      }
    });
  }

  @override
  Future<void> close() {
    _txSub?.cancel();
    _authSub?.cancel();
    _connSub?.cancel();
    return super.close();
  }

  void reset() {
    _txSub?.cancel();
    emit(DashboardState());
  }

  void init() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    emit(state.copyWith(status: 'loading'));

    try {
      final tier = await ApiService.getUserTier();
      
      emit(state.copyWith(
        kycTier: tier,
        status: 'success',
      ));

      _subscribeToTransactions(currentUser.id);
      
    } catch (e) {
      emit(state.copyWith(status: 'error', errorMessage: e.toString()));
    }
  }

  void _subscribeToTransactions(String profileId) {
    _txSub?.cancel();
    _txSub = _repository.fetchTransactions(profileId).listen(
      (transactions) {
        emit(state.copyWith(
          transactions: transactions,
          isTransactionsLoaded: true,
        ));
      },
      onError: (e) {
        debugPrint('⚠️ [Dashboard] Real-time Sync Error: $e');
        // Fallback: One-time query if Real-time fails
        _repository.getTransactionsOnce(profileId).then((transactions) {
          emit(state.copyWith(
            transactions: transactions,
            isTransactionsLoaded: true,
          ));
        });
      },
    );
  }

  Future<void> refresh() async {
    init();
  }

  void syncPaymentSuccess({
    required String transactionId,
    required double amount,
    required String recipientName,
    required double remainingBalance,
  }) {
    refresh();
  }
}
