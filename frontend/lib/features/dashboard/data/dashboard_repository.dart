import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:frontend/features/transactions/domain/transaction.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';

class DashboardRepository {
  final SupabaseClient _client;

  DashboardRepository(this._client);

  static const _kTransactionsCachePrefix = 'cached_transactions_';

  // Repository-level channel state — persists across stream lifecycle
  RealtimeChannel? _channel;
  String? _activeProfileId;

  Stream<AuthState> get authStream => _client.auth.onAuthStateChange;

  /// Fetches transactions using Supabase Realtime postgres_changes.
  /// Falls back to a one-time query on channel error so the stream never goes silent.
  Stream<List<Transaction>> fetchTransactions(String profileId) {
    final controller = StreamController<List<Transaction>>.broadcast();

    Future<void> fetchAndEmit() async {
      if (controller.isClosed) return;
      try {
        final data = await _client
            .from('transactions')
            .select()
            .eq('profile_id', profileId)
            .order('created_at', ascending: false);
        if (!controller.isClosed) {
          final txs = (data as List<dynamic>)
              .map((json) => Transaction.fromJson(json as Map<String, dynamic>))
              .toList();
          controller.add(txs);

          // Cache the transaction list
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('$_kTransactionsCachePrefix$profileId', jsonEncode(data));
        }
      } catch (e) {
        debugPrint('❌ [DashboardRepository] fetchAndEmit error: $e');
      }
    }

    Future<void> loadCacheAndEmit() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final cachedJson = prefs.getString('$_kTransactionsCachePrefix$profileId');
        if (cachedJson != null && !controller.isClosed) {
          final decoded = jsonDecode(cachedJson) as List<dynamic>;
          final txs = decoded
              .map((json) => Transaction.fromJson(json as Map<String, dynamic>))
              .toList();
          controller.add(txs);
        }
      } catch (e) {
        debugPrint('⚠️ [DashboardRepository] loadCacheAndEmit error: $e');
      }
    }

    Future<void> subscribe() async {
      // Load from local cache first for instant rendering
      await loadCacheAndEmit();

      // Guard: skip if already subscribed to the same profileId
      if (_activeProfileId == profileId && _channel != null) {
        debugPrint('📡 [DashboardRepository] Already subscribed to profile $profileId — skipping.');
        await fetchAndEmit();
        return;
      }

      // Await previous channel cleanup before creating a new one
      if (_channel != null) {
        try {
          await _channel!.unsubscribe();
          // Small delay to allow server-side channel cleanup to complete
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (e) {
          debugPrint('⚠️ [DashboardRepository] Error unsubscribing previous channel: $e');
        }
        _channel = null;
        _activeProfileId = null;
      }

      _activeProfileId = profileId;

      _channel = _client
          .channel('transactions_profile_$profileId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'transactions',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'profile_id',
              value: profileId,
            ),
            callback: (_) => fetchAndEmit(),
          )
          .subscribe((status, [error]) {
            if (kDebugMode) {
              debugPrint('📡 [DashboardRepository] Realtime status: $status');
            }
            if (status == RealtimeSubscribeStatus.subscribed) {
              // Initial load on successful subscription
              fetchAndEmit();
            } else if (status == RealtimeSubscribeStatus.channelError ||
                status == RealtimeSubscribeStatus.timedOut) {
              debugPrint(
                  '⚠️ [DashboardRepository] Channel error ($status): $error. Falling back to one-time query.');
              fetchAndEmit();
            } else if (status == RealtimeSubscribeStatus.closed) {
              // 'closed' is expected when unsubscribing/switching screens — no action needed
            }
          });
    }

    // Lazy initialization: subscribe only when there is a listener
    controller.onListen = () {
      subscribe();
    };

    // Clean up when the stream is no longer listened to
    controller.onCancel = () async {
      try {
        await _channel?.unsubscribe();
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        debugPrint('⚠️ [DashboardRepository] Error during onCancel unsubscribe: $e');
      } finally {
        _channel = null;
        _activeProfileId = null;
        if (!controller.isClosed) controller.close();
      }
    };

    return controller.stream;
  }

  Future<List<Transaction>> getTransactionsOnce(String profileId) async {
    try {
      final response = await _client
          .from('transactions')
          .select()
          .eq('profile_id', profileId)
          .order('created_at', ascending: false);
      final txs = (response as List<dynamic>)
          .map((json) => Transaction.fromJson(json as Map<String, dynamic>))
          .toList();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_kTransactionsCachePrefix$profileId', jsonEncode(response));

      return txs;
    } catch (e) {
      debugPrint('❌ Failed to fetch transactions once: $e');
      try {
        final prefs = await SharedPreferences.getInstance();
        final cachedJson = prefs.getString('$_kTransactionsCachePrefix$profileId');
        if (cachedJson != null) {
          final decoded = jsonDecode(cachedJson) as List<dynamic>;
          return decoded
              .map((json) => Transaction.fromJson(json as Map<String, dynamic>))
              .toList();
        }
      } catch (_) {}
      return [];
    }
  }
}
