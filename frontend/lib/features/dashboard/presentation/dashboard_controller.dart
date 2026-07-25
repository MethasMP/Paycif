import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:frontend/features/dashboard/data/dashboard_repository.dart';
import 'package:frontend/features/transactions/domain/transaction.dart';
import 'package:frontend/core/network/connectivity_service.dart';
import 'package:frontend/core/network/api_service.dart';

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

  bool _isRefreshing = false;

  /// Tracks the profileId currently subscribed to. Prevents double-subscribe
  /// when init() is triggered multiple times by racing auth events.
  String? _subscribedProfileId;

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
    _subscribedProfileId = null;
    emit(DashboardState());
  }

  Future<void> init({int retryCount = 0}) async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        _isRefreshing = false;
        return;
      }

      if (retryCount == 0) {
        emit(state.copyWith(status: 'loading'));
      }

      try {
        String kycStatus = 'UNVERIFIED';
        try {
          final statusData = await ApiService.getKycStatus();
          kycStatus = (statusData['kyc_status'] as String? ?? 'UNVERIFIED').toUpperCase();
        } catch (_) {
          // Non-fatal — dashboard loads even if KYC status fails
        }
        
        if (isClosed) return;

        emit(state.copyWith(
          kycTier: kycStatus,
          status: 'success',
        ));

        _subscribeToTransactions(currentUser.id);

      } catch (e) {
        if (!isClosed) {
          if (retryCount < 3) {
            _isRefreshing = false;
            Future.delayed(Duration(seconds: 2 * (retryCount + 1)), () {
              if (!isClosed) init(retryCount: retryCount + 1);
            });
            return;
          }
          emit(state.copyWith(status: 'error', errorMessage: e.toString()));
        }
      } finally {
        _isRefreshing = false;
      }
    } catch (e) {
      _isRefreshing = false;
      if (!isClosed) {
        if (retryCount < 3) {
          Future.delayed(Duration(seconds: 2 * (retryCount + 1)), () {
            if (!isClosed) init(retryCount: retryCount + 1);
          });
          return;
        }
        emit(state.copyWith(status: 'error', errorMessage: e.toString()));
      }
    }
  }

  /// Subscribes to the transaction stream for [profileId].
  ///
  /// Guarded by [_subscribedProfileId]: if the same profileId is already
  /// subscribed, this is a no-op. This prevents redundant stream rebuilds
  /// when init() races with auth events.
  void _subscribeToTransactions(String profileId) {
    if (_subscribedProfileId == profileId) {
      // Repository's _activeProfileId guard will handle de-duplication at the
      // channel level, but we avoid rebuilding the stream pipeline entirely.
      debugPrint('📡 [DashboardController] Already subscribed to profile $profileId — skipping.');
      return;
    }

    _txSub?.cancel();
    _subscribedProfileId = profileId;
    _startListening(profileId);
  }

  void _startListening(String profileId) {
    if (isClosed) return;

    _txSub = _repository.fetchTransactions(profileId).listen(
      (transactions) {
        if (!isClosed) {
          emit(state.copyWith(
            transactions: transactions,
            isTransactionsLoaded: true,
          ));
        }
      },
      onError: (e) async {
        debugPrint('⚠️ [Dashboard] Real-time sync error: $e');
        if (isClosed) return;

        // The repository's channelError/timedOut handler already calls
        // fetchAndEmit() internally. We do a single one-time query here as
        // an immediate UI fallback — no retry loop or stream rebuild needed.
        try {
          final transactions = await _repository.getTransactionsOnce(profileId);
          if (!isClosed) {
            emit(state.copyWith(
              transactions: transactions,
              isTransactionsLoaded: true,
            ));
          }
        } catch (err) {
          debugPrint('⚠️ [Dashboard] Fallback transactions load failed: $err');
        }
      },
    );
  }

  Future<void> refresh() async {
    init();
  }

  /// Lightweight sync after a successful payment — avoids a full init()
  /// (no KYC re-fetch, no stream rebuild). Just refreshes transaction data.
  void syncPaymentSuccess({
    required String transactionId,
    required double amount,
    required String recipientName,
    required double remainingBalance,
  }) {
    final profileId = Supabase.instance.client.auth.currentUser?.id;
    if (profileId == null || isClosed) return;

    _repository.getTransactionsOnce(profileId).then((transactions) {
      if (!isClosed) {
        emit(state.copyWith(
          transactions: transactions,
          isTransactionsLoaded: true,
        ));
      }
    }).catchError((e) {
      debugPrint('⚠️ [Dashboard] syncPaymentSuccess fallback failed: $e');
    });
  }
}
