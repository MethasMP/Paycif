abstract class SecurityRepository {
  /// Sets up a new PIN for the user.
  Future<void> setupPin(String pin);

  /// Verifies the PIN locally (AES-256-GCM). Use for app unlock.
  /// For payment confirmation, pass [serverVerify: true] to also run
  /// Argon2id verification on the server.
  Future<void> verifyPin(String pin, {bool serverVerify = false});

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

  /// 🛡️ Generates signature headers for any arbitrary payload.
  /// Used to harden sensitive actions (Transfers, Top-ups) with Device Identity.
  Future<Map<String, String>> generateSignatureHeaders(String payload);

  /// 🔒 Hard-Clear: Wipes all sensitive in-memory and disk caches (Logout).
  Future<void> clearSecurityData();

  /// Clear local PIN hash, salt and cache (used for PIN reset flow).
  Future<void> clearAllPinData();
}
