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

  /// Creates a PayoutIntent on the backend and returns the AlchemyPay checkout
  /// URL plus the intent ID for status polling.
  Future<({String webUrl, String intentId})> createOnRampIntent({
    required int amountSatang,
    required String sqrilTxId,
    required String promptPayId,
    required String recipientName,
    required String fiatCurrency,
    required String idempotencyKey,
    String? billerId,
    String? reference1,
    String? reference2,
    String? email,
    double? lat,
    double? lng,
  });

  /// Polls backend for the current status of a PayoutIntent.
  /// Returns status string: PENDING | COMPLETED | FAILED | ACH_FAILED | PAYMENT_SUCCESS_PAYOUT_PENDING
  Future<String> getIntentStatus(String intentId);

  /// Subscribes to real-time database changes for a specific PayoutIntent and emits status updates.
  Stream<String> watchIntentStatus(String intentId);
}
