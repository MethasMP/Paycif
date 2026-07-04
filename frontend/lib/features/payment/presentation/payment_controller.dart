import 'package:flutter/foundation.dart';
import 'package:frontend/core/network/api_service.dart';

/// Centralized state for ACH on-ramp preferences.
/// Stores only non-sensitive pre-fill data (last-used fiat/crypto/network)
/// and the ACH accessToken for skip-email-verify flow.
/// Card credentials are owned entirely by AlchemyPay — not stored here.
class PaymentController extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  String _lastUsedFiat = 'USD';
  String _lastUsedCrypto = 'USDC';
  String _lastUsedNetwork = 'BASE'; // Base network: Paycif pool wallet lives on Base
  bool _hasValidAchToken = false;
  bool _isLoading = false;

  String get lastUsedFiat => _lastUsedFiat;
  String get lastUsedCrypto => _lastUsedCrypto;
  String get lastUsedNetwork => _lastUsedNetwork;
  bool get hasValidAchToken => _hasValidAchToken;
  bool get isLoading => _isLoading;

  Future<void> fetchData({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final profile = await _apiService.getUserProfile();
      if (profile != null) {
        _lastUsedFiat = profile.lastUsedFiat ?? 'USD';
        _lastUsedCrypto = profile.lastUsedCrypto ?? 'USDC';
        _lastUsedNetwork = profile.lastUsedNetwork ?? 'BASE';
        _hasValidAchToken = profile.hasValidAchToken;
      }
    } catch (e) {
      debugPrint('❌ PaymentController Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Called from PaymentSettingsScreen when user changes preferred currency.
  Future<void> updatePreferences({String? fiat}) async {
    if (fiat != null) _lastUsedFiat = fiat;
    notifyListeners();
    try {
      await _apiService.updateAchPreferences(
        fiat: _lastUsedFiat,
        crypto: _lastUsedCrypto,
        network: _lastUsedNetwork,
      );
    } catch (e) {
      debugPrint('❌ PaymentController: failed to persist preference: $e');
    }
  }

  /// Called after a successful ACH on-ramp to persist the user's last choices.
  Future<void> updateLastUsed({
    required String fiat,
    required String crypto,
    required String network,
  }) async {
    _lastUsedFiat = fiat;
    _lastUsedCrypto = crypto;
    _lastUsedNetwork = network;
    notifyListeners();

    try {
      await _apiService.updateAchPreferences(
        fiat: fiat,
        crypto: crypto,
        network: network,
      );
    } catch (e) {
      debugPrint('❌ PaymentController: failed to persist ACH preferences: $e');
    }
  }
}
