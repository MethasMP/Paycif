import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/network/api_service.dart';

sealed class KycState {}

class KycInitial extends KycState {}

class KycLoading extends KycState {}

/// KYC URL is ready — frontend should launch it in the browser.
class KycUrlReady extends KycState {
  final String kycUrl;
  KycUrlReady(this.kycUrl);
}

/// User was already registered — waiting for webhook to set status.
class KycAwaitingResult extends KycState {}

/// Polling after browser return — waiting for backend webhook to confirm.
class KycPolling extends KycState {}

class KycVerified extends KycState {}

class KycFailed extends KycState {
  final String reason;
  KycFailed(this.reason);
}

/// Cubit that drives the Alchemy Pay delegated KYC flow.
class SumsubKycCubit extends Cubit<KycState> {
  Timer? _pollTimer;
  int _pollAttempts = 0;
  static const int _maxPollAttempts = 60; // 3 min at 3s intervals

  SumsubKycCubit() : super(KycInitial());

  /// Step 1: Register with Alchemy Pay and get the KYC URL.
  Future<void> initKyc() async {
    emit(KycLoading());
    try {
      final res = await ApiService.initiateKyc();
      if (isClosed) return;

      final status = res['status'] as String? ?? '';

      if (status == 'already_registered') {
        // User was registered before — check if they're already verified.
        await _checkCurrentStatus();
        return;
      }

      final kycUrl = res['kyc_url'] as String? ?? '';
      if (kycUrl.isEmpty) {
        emit(KycFailed('No verification URL returned. Please try again.'));
        return;
      }

      emit(KycUrlReady(kycUrl));
    } catch (e) {
      if (isClosed) return;
      emit(KycFailed(e.toString()));
    }
  }

  /// Step 2: Called after the user returns from the external KYC browser.
  /// Starts polling /kyc/status until VERIFIED or timeout.
  void onReturnedFromBrowser() {
    if (isClosed) return;
    emit(KycPolling());
    _startPolling();
  }

  Future<void> _checkCurrentStatus() async {
    try {
      final statusData = await ApiService.getKycStatus();
      if (isClosed) return;
      final kycStatus = (statusData['kyc_status'] as String? ?? '').toUpperCase();
      if (kycStatus == 'VERIFIED') {
        emit(KycVerified());
      } else {
        // Not verified yet — show awaiting state (webhook will update later)
        emit(KycAwaitingResult());
      }
    } catch (e) {
      if (isClosed) return;
      emit(KycFailed(e.toString()));
    }
  }

  void _startPolling() {
    _pollAttempts = 0;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (isClosed) {
        _pollTimer?.cancel();
        return;
      }
      _pollAttempts++;
      try {
        final statusData = await ApiService.getKycStatus();
        if (isClosed) return;

        final kycStatus = (statusData['kyc_status'] as String? ?? '').toUpperCase();

        if (kycStatus == 'VERIFIED') {
          _pollTimer?.cancel();
          emit(KycVerified());
          return;
        }
        if (kycStatus == 'REJECTED') {
          _pollTimer?.cancel();
          emit(KycFailed('Verification was rejected. Please contact support.'));
          return;
        }
      } catch (_) {
        // Transient network error — keep polling
      }

      if (_pollAttempts >= _maxPollAttempts) {
        _pollTimer?.cancel();
        if (!isClosed) {
          emit(KycFailed('Verification is taking longer than expected. We\'ll notify you when it\'s done.'));
        }
      }
    });
  }

  @override
  Future<void> close() {
    _pollTimer?.cancel();
    return super.close();
  }
}
