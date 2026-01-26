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

  /// Changes the user's PIN securely.
  Future<void> changePin({required String oldPin, required String newPin});

  /// Gets the list of active devices linked to the account.
  Future<List<Map<String, dynamic>>> getLinkedDevices({
    bool forceRefresh = false,
  });

  /// Real-time stream of linked devices.
  Stream<List<Map<String, dynamic>>> watchLinkedDevices();

  /// Revokes a specific device by ID.
  Future<void> revokeDevice(String deviceId, {String? reason});

  /// Gets the unique ID of the current device binding.
  Future<String?> getCurrentDeviceId();
}
