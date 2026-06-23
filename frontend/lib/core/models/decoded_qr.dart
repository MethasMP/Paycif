class DecodedQr {
  final String txId;
  final double amount;
  final String recipientName;
  final String type;
  final bool isBusiness;

  DecodedQr({
    required this.txId,
    required this.amount,
    required this.recipientName,
    required this.type,
    required this.isBusiness,
  });

  factory DecodedQr.fromJson(Map<String, dynamic> json) {
    return DecodedQr(
      txId: (json['tx_id'] ?? json['id'] ?? '').toString(),
      amount: (json['amount'] as num? ?? 0.0).toDouble(),
      recipientName: (json['recipient_name'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      isBusiness: json['is_business'] as bool? ?? (json['type'] == 'business'),
    );
  }
}
