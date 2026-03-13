import 'package:flutter/foundation.dart';
import '../../../security/data/datasources/hardware_security_bridge.dart';
import '../../domain/entities/passport_data.dart';

/// 🏛️ Identity Coordinator
/// 
/// The "Steve Jobs" level orchestration. This class binds the 
/// Physical Identity (Passport) to the Digital Hardware Identity (Enclave).
class IdentityCoordinator {
  final HardwareSecurityBridge _hardwareBridge;

  IdentityCoordinator({HardwareSecurityBridge? bridge}) 
    : _hardwareBridge = bridge ?? HardwareSecurityBridge();

  /// 🔐 The Master Ritual
  /// 
  /// 1. Verifies the Passport Data from NFC (ICAO 9303)
  /// 2. Generates a new Hardware Key in the Secure Enclave
  /// 3. Signs the Passport Attestation with the Hardware Key
  /// 4. Returns a "Secure Identity Binding" that can be sent to the backend.
  Future<String?> upgradeToHardwareIdentity(PassportData data) async {
    try {
      debugPrint('🏛️ [Coordinator] Starting Identity Upgrade Ritual...');

      // 1. Verify integrity (In production, check PA/AA from chip)
      if (!data.isChipVerified) {
        throw Exception('Passport chip integrity could not be verified.');
      }

      // 2. Generate Hardware Identity
      // We name the key based on the document number to tie them together
      final publicKey = await _hardwareBridge.createHardwareKeyPair(
        keyName: 'id_binding_${data.documentNumber}',
      );

      if (publicKey == null) return null;

      // 3. Create Binding Payload
      // We sign the fact that "This Passport" is now bound to "This Hardware"
      final payload = 'BIND_PASSPORT:${data.documentNumber}:PUBKEY:$publicKey';
      
      final signature = await _hardwareBridge.signPayload(
        payload: payload,
        promptMessage: 'Bind your identity to this device',
      );

      if (signature == null) return null;

      debugPrint('🏛️ [Coordinator] Identity successfully bound to Hardware.');
      
      // Return the complete attestation package
      return 'ATTESTATION:$payload:SIG:$signature';
      
    } catch (e) {
      debugPrint('❌ [Coordinator] Upgrade failed: $e');
      return null;
    }
  }
}
