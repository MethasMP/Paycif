import 'package:supabase_flutter/supabase_flutter.dart';

class SecurityRemoteDataSource {
  final SupabaseClient _supabase;

  SecurityRemoteDataSource(this._supabase);

  Future<void> setupPin(String pin, {Map<String, String>? headers}) async {
    await _supabase.functions.invoke(
      'setup-pin',
      body: {'pin': pin},
      headers: headers ?? {},
    );
  }

  Future<void> verifyPin(String pin, {Map<String, String>? headers}) async {
    final response = await _supabase.functions.invoke(
      'verify-pin',
      body: {'pin': pin},
      headers: headers ?? {},
    );

    if (response.status != 200) {
      throw Exception(
        'Verification failed: ${response.data['error'] ?? 'Unknown error'}',
      );
    }
  }

  Future<void> bindDevice({
    required String publicKey,
    required String deviceId,
    required String deviceName,
  }) async {
    await _supabase.functions.invoke(
      'bind-device',
      body: {
        'public_key': publicKey,
        'device_id': deviceId,
        'device_name': deviceName,
      },
    );
  }

  Future<void> initiatePinReset({
    required String answer,
    Map<String, String>? headers,
  }) async {
    final response = await _supabase.functions.invoke(
      'initiate-pin-reset',
      body: {'answer': answer},
      headers: headers ?? {},
    );
    if (response.status != 200) {
      throw Exception(response.data['error'] ?? 'Reset failed');
    }
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
}
