import 'package:flutter/foundation.dart';
import 'package:frontend/features/payment/domain/repositories/payment_ports.dart';
import 'package:frontend/features/payment/domain/repositories/payment_repository.dart';

/// 🔄 BACKGROUND SYNC RECONCILIATION WORKER
/// Coordinates offline state reconciliation following the Local-First Outbox Pattern.
/// Ensures all offline transactions are synced deterministically using server-side idempotency.
class SyncReconciliationWorker {
  final IOfflineOutbox _outbox;
  final IPaymentRepository _paymentRepository;

  SyncReconciliationWorker({
    required IOfflineOutbox outbox,
    required IPaymentRepository paymentRepository,
  })  : _outbox = outbox,
        _paymentRepository = paymentRepository;

  /// Triggered automatically on network reconnection or via WorkManager scheduler.
  Future<void> reconcilePendingTransactions() async {
    try {
      final pendingList = await _outbox.getPendingTransactions();
      if (pendingList.isEmpty) {
        debugPrint('🔄 [SyncWorker] No pending offline transactions to reconcile.');
        return;
      }

      debugPrint('🔄 [SyncWorker] Reconciling ${pendingList.length} transaction(s)...');

      for (final tx in pendingList) {
        final String txId = tx['tx_id'];
        final double amount = tx['amount'];
        final String recipientName = tx['recipient_name'];

        final amountSatang = (amount * 100).toInt();

        try {
          // Send to SQRIL / PayToPromptPay via Port with the SAME Idempotency Key (txId)
          // To ensure server-side deduplication (Anti-Double Spending)
          final backendTxId = await _paymentRepository.payToPromptPay(
            amountInSatang: amountSatang,
            recipientName: recipientName,
            idempotencyKey: txId, // Re-use local transaction ID as idempotency key
            sqrilTxId: txId,
          );

          await _outbox.markAsSynced(txId, backendTxId);
          debugPrint('✅ [SyncWorker] Successfully synced offline transaction: $txId');
        } catch (e) {
          debugPrint('⚠️ [SyncWorker] Error syncing transaction $txId: $e');
          
          // Determine if error is terminal (e.g. invalid balance, bad QR) or transient (network timeout)
          final isTerminalError = e.toString().contains('PERSONAL_QR_NOT_SUPPORTED') || 
                                  e.toString().contains('Invalid') ||
                                  e.toString().contains('insufficient');
          
          if (isTerminalError) {
            await _outbox.markAsFailed(txId, e.toString());
          }
          // If transient, we do not mark as failed; it will retry on the next reconciliation cycle.
        }
      }
    } catch (e) {
      debugPrint('❌ [SyncWorker] Reconciliation cycle failed: $e');
    }
  }
}
