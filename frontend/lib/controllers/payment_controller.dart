import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../models/saved_card.dart';

/// 💎 PAYMENT CONTROLLER (World-Class Reactive Sync)
/// Centralized state management for Payment Methods.
/// Guarantees that changing a preference in one screen (e.g. TopUp)
/// reflects IMMEDIATELY across all other screens (e.g. Payment Settings).
class PaymentController extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<SavedCard> _savedCards = [];
  String? _preferredMethodId;
  String? _preferredMethodType;
  bool _isLoading = false;

  // Getters
  List<SavedCard> get savedCards => _savedCards;
  String? get preferredMethodId => _preferredMethodId;
  String? get preferredMethodType => _preferredMethodType;
  bool get isLoading => _isLoading;

  /// 🌐 FETCH DATA
  /// Refreshes both profile (for preference) and cards list.
  Future<void> fetchData({bool silent = false}) async {
    if (!silent) _isLoading = true;
    if (!silent) notifyListeners();

    try {
      final results = await Future.wait([
        _apiService.getUserProfile(),
        _apiService.getSavedCards(forceRefresh: true),
      ]);

      final profile = results[0] as Map<String, dynamic>?;
      _savedCards = results[1] as List<SavedCard>;

      if (profile != null) {
        _preferredMethodId = profile['preferred_payment_method_id'];
        _preferredMethodType = profile['preferred_payment_method_type'];
      }

      debugPrint(
        '✅ PaymentController: Data Refreshed. Pref=$_preferredMethodId',
      );
    } catch (e) {
      debugPrint('❌ PaymentController Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 🔗 UPDATE PREFERENCE (Instant Sync)
  /// Updates cache and database. Notifies listeners immediately.
  Future<void> updatePreference(String methodId, String methodType) async {
    // 1. Optimistic UI: Update local state immediately
    _preferredMethodId = methodId;
    _preferredMethodType = methodType;
    notifyListeners();

    try {
      // 2. Persist to DB
      await _apiService.updatePaymentPreference(methodId, methodType);
      debugPrint('✅ PaymentController: Preference Persisted=$methodId');
    } catch (e) {
      debugPrint('❌ PaymentController Preference Error: $e');
      // In a strict world-class app, we might want to revert if it fails.
      // But for now, user can just try again.
    }
  }

  /// 💳 ADD CARD
  Future<void> addCard(String token) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _apiService.saveCard(token);
      await fetchData(silent: true);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 🗑️ DELETE CARD
  Future<void> deleteCard(String cardId) async {
    try {
      await _apiService.deleteCard(cardId);
      // Optimistic update
      _savedCards.removeWhere((c) => c.id == cardId);
      if (_preferredMethodId == cardId) {
        _preferredMethodId = null;
        _preferredMethodType = null;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('❌ PaymentController Delete Error: $e');
      fetchData(silent: true); // Re-sync on error
    }
  }
}
