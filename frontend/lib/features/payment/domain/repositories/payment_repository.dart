abstract class IPaymentRepository {
  Future<Map<String, dynamic>> decodeQR(String qrString);
  Future<Map<String, dynamic>> getQuotation(String txId, int amountSatang);

  Future<String> payToPromptPay({
    required int amountInSatang,
    required String recipientName,
    String? promptPayId,
    String? billerId,
    String? reference1,
    String? reference2,
    required String idempotencyKey,
    String? sqrilTxId,
    Map<String, String>? headers,
  });
}
