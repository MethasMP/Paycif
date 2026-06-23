import 'package:frontend/core/models/decoded_qr.dart';
import 'package:frontend/core/models/quotation_model.dart';

abstract class IPaymentRepository {
  Future<DecodedQr> decodeQR(String qrString);
  Future<QuotationModel> getQuotation(String txId, int amountSatang);

  Future<String> payToPromptPay({
    required int amountInSatang,
    required String recipientName,
    String? promptPayId,
    String? billerId,
    String? reference1,
    String? reference2,
    required String idempotencyKey,
    String? sqrilTxId,
  });
}
