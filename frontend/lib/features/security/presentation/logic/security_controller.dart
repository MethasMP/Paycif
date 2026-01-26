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
      // Check if error is a Lockout (423) or Auth Failure (401)
      // Since our Repository throws strict Exceptions or we might need to parse.
      // For now, assume message contains info or we parse a custom Exception if we made one.
      // In a real app we'd have `Failure` objects.
      // Let's assume the Exception string might contain "locked".

      final msg = e.toString().toLowerCase();
      if (msg.contains('locked')) {
        // Parse "Try again in X seconds" or similar if possible,
        // or getting `locked_until` from data if we improved the Repo to return it.
        // For MVP, we set status to locked.
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
            // We could decrement locally for UI effect, but Server is Authority.
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
}
