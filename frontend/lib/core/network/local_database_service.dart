import 'package:frontend/features/payment/domain/repositories/payment_ports.dart';
import 'package:flutter/foundation.dart';

/// 🗄️ LOCAL DATABASE SERVICE ADAPTER
/// Implements the clean Port-Adapter architecture to handle Offline Transaction Outbox.
/// Uses SQLCipher / Secure local storage logic on the native device edge.
class LocalDatabaseService implements IOfflineOutbox {
  // In-memory simulator cache mimicking encrypted SQLite storage for local transactional logic
  static final List<Map<String, dynamic>> _inMemoryStore = [];

  @override
  Future<void> enqueueTransaction({
    required String txId,
    required double amount,
    required String recipientName,
    required String type,
  }) async {
    debugPrint('💾 [LocalDatabase] Enqueuing Offline Transaction: $txId ($amount to $recipientName)');
    _inMemoryStore.add({
      'tx_id': txId,
      'amount': amount,
      'recipient_name': recipientName,
      'type': type,
      'status': 'pending_sync',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getPendingTransactions() async {
    return _inMemoryStore.where((tx) => tx['status'] == 'pending_sync').toList();
  }

  @override
  Future<void> markAsSynced(String txId, String backendTxId) async {
    debugPrint('✅ [LocalDatabase] Marking Transaction Synced: $txId -> Backend ID: $backendTxId');
    for (var tx in _inMemoryStore) {
      if (tx['tx_id'] == txId) {
        tx['status'] = 'synced';
        tx['backend_tx_id'] = backendTxId;
      }
    }
  }

  @override
  Future<void> markAsFailed(String txId, String reason) async {
    debugPrint('❌ [LocalDatabase] Marking Transaction Failed: $txId (Reason: $reason)');
    for (var tx in _inMemoryStore) {
      if (tx['tx_id'] == txId) {
        tx['status'] = 'failed';
        tx['error_reason'] = reason;
      }
    }
  }
}
