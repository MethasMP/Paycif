abstract class IOfflineOutbox {
  Future<void> enqueueTransaction({
    required String txId,
    required double amount,
    required String recipientName,
    required String type,
  });
  Future<List<Map<String, dynamic>>> getPendingTransactions();
  Future<void> markAsSynced(String txId, String backendTxId);
  Future<void> markAsFailed(String txId, String reason);
}
