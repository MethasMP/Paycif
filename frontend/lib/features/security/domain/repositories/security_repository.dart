abstract class SecurityRepository {
  /// Sets up a new PIN for the user.
  Future<void> setupPin(String pin);

  /// Verifies the PIN. Returns true if valid, or throws failure.
  Future<void> verifyPin(String pin);

  /// Binds the current device to the user's account using hardware keys.
  Future<void> bindCurrentDevice();

  /// Initiates PIN reset via KYC challenge.
  Future<void> initiatePinReset({required String challengeAnswer});

  /// Checks if the device is currently bound.
  Future<bool> isDeviceBound();

  /// Checks if the user has a PIN set up.
  Future<bool> hasPin();
}
