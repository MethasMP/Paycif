import 'dart:async';
import 'package:flutter/foundation.dart';
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
    } catch (e, st) {
      if (isClosed) return;
      _logError('initKyc failed', e, st);
      emit(KycFailed(_friendlyErrorMessage()));
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
      } else if (kycStatus == 'REJECTED') {
        emit(KycFailed(_messageForStatus(kycStatus)));
      } else if (kycStatus == 'PENDING_RESUBMISSION') {
        emit(KycFailed(_messageForStatus(kycStatus)));
      } else {
        // Not verified yet — show awaiting state (webhook will update later)
        emit(KycAwaitingResult());
      }
    } catch (e, st) {
      if (isClosed) return;
      _logError('_checkCurrentStatus failed', e, st);
      emit(KycFailed(_friendlyErrorMessage()));
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
        // Permanent rejection — not retryable.
        if (kycStatus == 'REJECTED') {
          _pollTimer?.cancel();
          emit(KycFailed(_messageForStatus(kycStatus)));
          return;
        }
        // Some details couldn't be verified, but the user can re-submit.
        // The "Try Again" button on KycFailed re-runs initKyc().
        if (kycStatus == 'PENDING_RESUBMISSION') {
          _pollTimer?.cancel();
          emit(KycFailed(_messageForStatus(kycStatus)));
          return;
        }
      } catch (e) {
        // Transient network error — keep polling, but record it for debugging.
        debugPrint('[KYC] poll attempt $_pollAttempts hit a transient error: $e');
      }

      if (_pollAttempts >= _maxPollAttempts) {
        _pollTimer?.cancel();
        if (!isClosed) {
          // Honest, actionable copy: there is no real push-notification on
          // completion, so don't promise one. Verification is still running;
          // the user can safely leave and check again later via "Try Again".
          emit(KycFailed(
            'Your verification is still being processed. '
            'You can safely close this and check again in a few minutes.',
          ));
        }
      }
    });
  }

  /// Maps a backend KYC status string into short, calm, non-technical copy.
  String _messageForStatus(String status) {
    switch (status) {
      case 'PENDING_RESUBMISSION':
        return 'Some details couldn\'t be verified. Please try again.';
      case 'REJECTED':
        return 'We weren\'t able to verify your identity. '
            'Please reach out to our support team for help.';
      default:
        return _friendlyErrorMessage();
    }
  }

  /// Generic, user-safe message for unexpected exceptions. The technical
  /// detail is logged via [_logError] — never surfaced to the user.
  String _friendlyErrorMessage() {
    return 'Something went wrong while verifying your identity. '
        'Please check your connection and try again.';
  }

  /// Logs the raw error and stack trace for debugging without exposing them
  /// to the user-facing UI.
  void _logError(String context, Object error, StackTrace stackTrace) {
    debugPrint('[KYC] $context: $error');
    debugPrint('[KYC] $stackTrace');
  }

  @override
  Future<void> close() {
    _pollTimer?.cancel();
    return super.close();
  }
}
