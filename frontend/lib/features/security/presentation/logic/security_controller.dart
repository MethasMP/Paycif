import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import '../../domain/repositories/security_repository.dart';

/// 🚀 The Sentinel Identity Protocol (50 Years Ahead UX)
/// Instead of just "checking hardware", it analyzes the "Confidence State".
class BiometricProfile {
  final List<BiometricType> availableTypes;
  final BiometricType? primaryType;
  final double
  identityConfidence; // 0.0 to 1.0 (How sure are we this is the owner?)
  final String contextualGuidance; // Intelligent message for User Experience

  const BiometricProfile({
    required this.availableTypes,
    this.primaryType,
    this.identityConfidence = 0.0,
    this.contextualGuidance = "Detecting Identity...",
  });

  factory BiometricProfile.analyze(
    List<BiometricType> types, {
    double confidence = 0.0,
  }) {
    BiometricType? primary;
    String guidance = "Locked"; // Default guidance if no primary type found

    // Priority Logic (The "Standard")
    if (types.contains(BiometricType.face)) {
      primary = BiometricType.face;
      guidance = "Looking for you...";
    } else if (types.contains(BiometricType.iris)) {
      primary = BiometricType.iris;
      guidance = "Scan your iris";
    } else if (types.contains(BiometricType.fingerprint)) {
      primary = BiometricType.fingerprint;
      guidance = "Touch to Verify";
    } else if (types.isNotEmpty) {
      // Fallback for future types (e.g. weak biometrics)
      primary = types.first;
      guidance = "Verify your identity";
    }

    return BiometricProfile(
      availableTypes: types,
      primaryType: primary,
      identityConfidence: confidence,
      contextualGuidance: guidance,
    );
  }

  /// 🧠 Device Empathy: Suggests the best interaction
  bool get shouldAutoTrigger => identityConfidence < 0.8;
  bool get isTrustedState => identityConfidence >= 0.95;
}

enum SecurityStatus { initial, loading, success, error, locked }

class SecurityState {
  final SecurityStatus status;
  final String? errorMessage;
  final DateTime? lockedUntil;
  final DateTime?
  lastVerifiedAt; // 🛡️ Sentinel Anchor: When was the identity last proven?
  final int remainingAttempts;

  const SecurityState({
    this.status = SecurityStatus.initial,
    this.errorMessage,
    this.lockedUntil,
    this.lastVerifiedAt,
    this.remainingAttempts = 3,
  });

  SecurityState copyWith({
    SecurityStatus? status,
    String? errorMessage,
    DateTime? lockedUntil,
    DateTime? lastVerifiedAt,
    int? remainingAttempts,
  }) {
    return SecurityState(
      status: status ?? this.status,
      errorMessage: errorMessage,
      lockedUntil: lockedUntil ?? this.lockedUntil,
      lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
      remainingAttempts: remainingAttempts ?? this.remainingAttempts,
    );
  }
}

class SecurityController extends ChangeNotifier {
  final SecurityRepository _repository;

  SecurityController(this._repository);

  bool? _hasPinCached;
  bool? get hasPinCached => _hasPinCached;

  SecurityState _state = const SecurityState();
  SecurityState get state => _state;

  void _setState(SecurityState newState) {
    _state = newState;
    notifyListeners();
  }

  /// 🕯️ Warm Up: Pre-fetch security state in the background
  Future<void> warmUp() async {
    _hasPinCached = await _repository.hasPin();
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
      _setState(
        _state.copyWith(
          status: SecurityStatus.success,
          lastVerifiedAt: DateTime.now(), // 🛡️ Anchor the time
        ),
      );
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

  /// changes the user's PIN securely.
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

  /// returns the biometric profile of the device using our standard priority logic.
  /// 🛡️ Sentinel Logic: Includes 'Chain of Trust' analysis.
  Future<BiometricProfile> getBiometricProfile() async {
    final auth = LocalAuthentication();
    try {
      final canCheck = await auth.canCheckBiometrics;
      if (!canCheck) {
        return const BiometricProfile(
          availableTypes: [],
          contextualGuidance: "No biometrics available",
        );
      }

      final available = await auth.getAvailableBiometrics();

      // 🛡️ The 30-Second Rule (Global Security Standard)
      // Even if the system is "success", if it's been more than 30s, trust drops to Zero.
      double confidence = 0.0;
      if (_state.status == SecurityStatus.success &&
          _state.lastVerifiedAt != null) {
        final age = DateTime.now().difference(_state.lastVerifiedAt!);
        if (age.inSeconds < 30) {
          confidence = 0.98; // High trust only for very recent interaction
        }
      }

      return BiometricProfile.analyze(available, confidence: confidence);
    } catch (e) {
      debugPrint('Sentinel Analysis Failed: $e');
      return const BiometricProfile(
        availableTypes: [],
        contextualGuidance: "Biometric analysis failed",
      );
    }
  }

  /// 🔒 Hard-Lock: Immediately invalidates all trust anchors.
  void lockSecurity() {
    _setState(
      _state.copyWith(
        status: SecurityStatus.initial,
        lastVerifiedAt: null, // Wipe the anchor!
      ),
    );
  }

  /// 🧹 Hard-Clear: Wipes all sensitive data (Logout)
  Future<void> clearSecurityState() async {
    await _repository.clearSecurityData();
    _hasPinCached = null;
    _setState(const SecurityState());
  }
}
