import 'package:frontend/features/payment/domain/repositories/payment_repository.dart';
import 'package:frontend/core/network/api_service.dart';
import 'package:frontend/core/models/decoded_qr.dart';
import 'package:frontend/core/models/quotation_model.dart';
import 'package:frontend/features/security/domain/repositories/security_repository.dart';

class PaymentRepositoryImpl implements IPaymentRepository {
  final ApiService _apiService;
  final SecurityRepository _securityRepository;

  PaymentRepositoryImpl({
    required ApiService apiService,
    required SecurityRepository securityRepository,
  })  : _apiService = apiService,
        _securityRepository = securityRepository;

  @override
  Future<DecodedQr> decodeQR(String qrString) async {
    return await _apiService.decodeQR(qrString);
  }

  @override
  Future<QuotationModel> getQuotation(String txId, int amountSatang) async {
    return await _apiService.getQuotation(txId, amountSatang);
  }

  @override
  Future<String> payToPromptPay({
    required int amountInSatang,
    required String recipientName,
    String? promptPayId,
    String? billerId,
    String? reference1,
    String? reference2,
    required String idempotencyKey,
    String? sqrilTxId,
  }) async {
    // Deterministic Request Signing in the Adapter layer (Secure by Default)
    final headers = await _securityRepository.generateSignatureHeaders(idempotencyKey);

    final response = await _apiService.payToPromptPay(
      amountInSatang: amountInSatang,
      recipientName: recipientName,
      promptPayId: promptPayId,
      billerId: billerId,
      reference1: reference1,
      reference2: reference2,
      idempotencyKey: idempotencyKey,
      sqrilTxId: sqrilTxId,
      headers: headers,
    );
    return response['transaction_id'] ?? response['id'] ?? idempotencyKey;
  }
}
