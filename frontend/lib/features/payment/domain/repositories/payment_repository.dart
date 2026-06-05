abstract class IPaymentRepository {
  Future<String> payToPromptPay({
    required int amountInSatang,
    required String recipientName,
    String? promptPayId,
    String? billerId,
    String? reference1,
    String? reference2,
    required String idempotencyKey,
    Map<String, String>? headers,
  });
}
