import 'package:flutter/foundation.dart';
import '../../domain/repositories/security_repository.dart';

enum SecurityStatus { initial, loading, success, error, locked }

class SecurityState {
  final SecurityStatus status;
  final String? errorMessage;
  final DateTime? lockedUntil;
  final int remainingAttempts;

  const SecurityState({
    this.status = SecurityStatus.initial,
    this.errorMessage,
    this.lockedUntil,
    this.remainingAttempts = 3,
  });

  SecurityState copyWith({
    SecurityStatus? status,
    String? errorMessage,
    DateTime? lockedUntil,
    int? remainingAttempts,
  }) {
    return SecurityState(
      status: status ?? this.status,
      errorMessage: errorMessage, // Nullable to clear error on new state
      lockedUntil: lockedUntil ?? this.lockedUntil,
      remainingAttempts: remainingAttempts ?? this.remainingAttempts,
    );
  }
}

class SecurityController extends ChangeNotifier {
  final SecurityRepository _repository;

  SecurityController(this._repository);

  SecurityState _state = const SecurityState();
  SecurityState get state => _state;

  void _setState(SecurityState newState) {
    _state = newState;
    notifyListeners();
  }

  /// Sets up a new PIN.
  Future<void> setupPin(String pin) async {
    _setState(_state.copyWith(status: SecurityStatus.loading));
    try {
      await _repository.setupPin(pin);
      _setState(_state.copyWith(status: SecurityStatus.success));
    } catch (e) {
      _setState(
        _state.copyWith(
          status: SecurityStatus.error,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  /// Verifies the PIN. Handles Server-Side Lockout responses (423).
  Future<bool> verifyPin(String pin) async {
    _setState(_state.copyWith(status: SecurityStatus.loading));
    try {
      await _repository.verifyPin(pin);
      _setState(_state.copyWith(status: SecurityStatus.success));
      return true;
    } catch (e) {
      final errorStr = e.toString();
      final isDeviceError = errorStr.contains('Device not recognized');

      if (isDeviceError) {
        _setState(
          _state.copyWith(
            status: SecurityStatus.error,
            errorMessage: 'Device link broken. Please log in again.',
          ),
        );
        // Special case: Unlike normal 401, this usually needs a full re-auth to re-bind
        return false;
      }

      if (errorStr.contains('401') ||
          errorStr.contains('Unauthorized') ||
          errorStr.contains('Invalid JWT')) {
        // 🛡️ World-Class Security: Log warning but don't force logout here.
        // The API Interceptor/DataSource will handle refresh or force logout if refresh truly fails.
        _setState(
          _state.copyWith(
            status: SecurityStatus.error,
            errorMessage: 'Session error. Please try again.',
          ),
        );
        return false;
      }

      final msg = e.toString().toLowerCase();
      if (msg.contains('locked')) {
        _setState(
          _state.copyWith(
            status: SecurityStatus.locked,
            errorMessage: e.toString().replaceAll('Exception:', '').trim(),
          ),
        );
      } else {
        _setState(
          _state.copyWith(
            status: SecurityStatus.error,
            errorMessage: 'Incorrect PIN',
          ),
        );
      }
      return false;
    }
  }

  /// Binds the device via Biometrics.
  Future<void> bindDevice() async {
    _setState(_state.copyWith(status: SecurityStatus.loading));
    try {
      await _repository.bindCurrentDevice();
      _setState(_state.copyWith(status: SecurityStatus.success));
    } catch (e) {
      _setState(
        _state.copyWith(
          status: SecurityStatus.error,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  /// Silently ensures the device is bound (Background).
  Future<void> ensureDeviceBinding() async {
    try {
      await _repository.bindCurrentDevice();
    } catch (e) {
      debugPrint('Silent binding failed: $e');
      // Do not update UI state to avoid disruption
    }
  }

  /// Initiates PIN Reset via KYC Challenge.
  Future<bool> initiatePinReset(String answer) async {
    _setState(_state.copyWith(status: SecurityStatus.loading));
    try {
      await _repository.initiatePinReset(challengeAnswer: answer);
      _setState(_state.copyWith(status: SecurityStatus.success));
      return true;
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('locked')) {
        _setState(
          _state.copyWith(
            status: SecurityStatus.locked,
            errorMessage: e.toString().replaceAll('Exception:', '').trim(),
          ),
        );
      } else {
        _setState(
          _state.copyWith(
            status: SecurityStatus.error,
            errorMessage: e.toString(),
          ),
        );
      }
      return false;
    }
  }

  /// Checks if the user has a PIN correctly configured.
  Future<bool> hasPin() async {
    return await _repository.hasPin();
  }

  /// Changes the user's PIN securely.
  Future<bool> changePin({
    required String oldPin,
    required String newPin,
  }) async {
    _setState(_state.copyWith(status: SecurityStatus.loading));
    try {
      await _repository.changePin(oldPin: oldPin, newPin: newPin);
      _setState(_state.copyWith(status: SecurityStatus.success));
      return true;
    } catch (e) {
      final msg = e.toString().replaceAll('Exception:', '').trim();
      _setState(
        _state.copyWith(status: SecurityStatus.error, errorMessage: msg),
      );
      return false;
    }
  }
}
