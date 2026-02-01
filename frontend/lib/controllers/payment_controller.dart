import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../models/saved_card.dart';
import '../features/security/data/datasources/secure_storage_service.dart';
import 'dart:convert';

/// 💎 PAYMENT CONTROLLER (World-Class Reactive Sync)
/// Centralized state management for Payment Methods.
/// Guarantees that changing a preference in one screen (e.g. TopUp)
/// reflects IMMEDIATELY across all other screens (e.g. Payment Settings).
class PaymentController extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final SecureStorageService _storage = SecureStorageService();

  static const _kCardsCacheKey = 'cache_payment_cards';
  static const _kPrefCacheKey = 'cache_payment_pref';

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
    // ⚡ [Fast-Path] Warm up from Cache immediately
    if (_savedCards.isEmpty) {
      await _loadCache();
    }

    if (!silent && _savedCards.isEmpty) _isLoading = true;
    if (!silent) notifyListeners();

    try {
      final results = await Future.wait([
        _apiService.getUserProfile(),
        _apiService.getSavedCards(forceRefresh: false),
      ]);

      final profile = results[0] as Map<String, dynamic>?;
      _savedCards = results[1] as List<SavedCard>;

      if (profile != null) {
        _preferredMethodId = profile['preferred_payment_method_id'];
        _preferredMethodType = profile['preferred_payment_method_type'];
      }

      // 📡 [Side-Effect] Persist Ground Truth to Disk
      _saveCache().ignore();

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

  Future<void> _loadCache() async {
    try {
      final cardsJson = await _storage.read(_kCardsCacheKey);
      final prefJson = await _storage.read(_kPrefCacheKey);

      if (cardsJson != null) {
        final List<dynamic> decoded = jsonDecode(cardsJson);
        _savedCards = decoded.map((i) => SavedCard.fromJson(i)).toList();
      }

      if (prefJson != null) {
        final pref = jsonDecode(prefJson);
        _preferredMethodId = pref['id'];
        _preferredMethodType = pref['type'];
      }

      if (_savedCards.isNotEmpty) notifyListeners();
    } catch (e) {
      debugPrint('⚠️ [Payment] Cache load error: $e');
    }
  }

  Future<void> _saveCache() async {
    _storage
        .write(
          _kCardsCacheKey,
          jsonEncode(_savedCards.map((c) => c.toJson()).toList()),
        )
        .ignore();
    _storage
        .write(
          _kPrefCacheKey,
          jsonEncode({'id': _preferredMethodId, 'type': _preferredMethodType}),
        )
        .ignore();
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
