import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../../../../services/api_service.dart';

class SecurityRemoteDataSource {
  final SupabaseClient _supabase;

  SecurityRemoteDataSource(this._supabase);

  // 🛡️ World-Class Resilience: Standardized Invocation via ApiService
  Future<dynamic> _invokeEdgeFunction(
    String functionName, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    // We now delegate everything to the Universal Invoker in ApiService.
    // This solves the "Double Interceptor" and "Invalid JWT" loop issues.
    return await ApiService.invokeEdgeFunction(
      functionName,
      body: body,
      headers: headers,
    );
  }

  Future<void> setupPin(String pin, {Map<String, String>? headers}) async {
    await _invokeEdgeFunction(
      'setup-pin',
      body: {'pin': pin},
      headers: headers,
    );
  }

  Future<void> verifyPin(String pin, {Map<String, String>? headers}) async {
    try {
      await _invokeEdgeFunction(
        'verify-pin',
        body: {'pin': pin},
        headers: headers,
      );
    } catch (e) {
      if (e is Exception && e.toString().contains('Verification failed')) {
        rethrow;
      }
      // Re-map FunctionException to generic Exception for repository compatibility
      // OR let repository handle it. Ideally repository handles it.
      rethrow;
    }
  }

  Future<void> bindDevice({
    required String publicKey,
    required String deviceId,
    required String deviceName,
    required String osType,
    Map<String, dynamic>? metadata,
    int? trustScore,
  }) async {
    await _invokeEdgeFunction(
      'bind-device',
      body: {
        'public_key': publicKey,
        'device_id': deviceId,
        'device_name': deviceName,
        'os_type': osType,
        'metadata': metadata,
        'trust_score': trustScore,
      },
    );
  }

  Future<void> initiatePinReset({
    required String answer,
    Map<String, String>? headers,
  }) async {
    await _invokeEdgeFunction(
      'initiate-pin-reset',
      body: {'answer': answer},
      headers: headers,
    );
  }

  Future<bool> isDeviceBound(String deviceId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    final response = await _supabase
        .from('user_device_bindings')
        .select('id')
        .eq('user_id', user.id)
        .eq('device_id', deviceId)
        .maybeSingle();

    return response != null;
  }

  Future<Map<String, dynamic>?> getProfileStatus() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    return await _supabase
        .from('profiles')
        .select('has_pin, kyc_status')
        .eq('id', user.id)
        .maybeSingle();
  }

  Future<void> changePin({
    required String oldPin,
    required String newPin,
    Map<String, String>? headers,
  }) async {
    await _invokeEdgeFunction(
      'change-pin',
      body: {'old_pin': oldPin, 'new_pin': newPin},
      headers: headers,
    );
  }

  Future<List<Map<String, dynamic>>> getLinkedDevices() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    try {
      final response = await _supabase
          .from('user_device_bindings')
          .select()
          .eq('user_id', user.id)
          .eq('is_active', true)
          .order('last_used_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  Future<void> revokeDevice(String deviceId, {String? reason}) async {
    await _invokeEdgeFunction(
      'revoke-device',
      body: {'device_id': deviceId, 'reason': reason},
    );
  }

  /// 🛰️ World-Class Real-time Sync
  Stream<List<Map<String, dynamic>>> watchLinkedDevices() {
    final user = _supabase.auth.currentUser;
    if (user == null) return Stream.value([]);

    return _supabase
        .from('user_device_bindings')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .map(
          (data) => List<Map<String, dynamic>>.from(
            data.where((d) => d['is_active'] == true).toList(),
          ),
        );
  }
}
