import '../../domain/repositories/payment_repository.dart';
import '../../../../services/api_service.dart';

class PaymentRepositoryImpl implements IPaymentRepository {
  final ApiService _apiService;

  PaymentRepositoryImpl({required ApiService apiService}) : _apiService = apiService;

  @override
  Future<String> payToPromptPay({
    required int amountInSatang,
    required String recipientName,
    String? promptPayId,
    String? billerId,
    String? reference1,
    String? reference2,
    required String idempotencyKey,
    Map<String, String>? headers,
  }) async {
    final response = await _apiService.payToPromptPay(
      amountInSatang: amountInSatang,
      recipientName: recipientName,
      promptPayId: promptPayId,
      billerId: billerId,
      reference1: reference1,
      reference2: reference2,
      idempotencyKey: idempotencyKey,
      headers: headers,
    );
    return response['transaction_id'] ?? response['id'] ?? idempotencyKey;
  }
}
