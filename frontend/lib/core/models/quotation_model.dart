class QuotationModel {
  final String quoteId;
  final double exchangeRate;
  final double fee;
  final double amountUsd;

  QuotationModel({
    required this.quoteId,
    required this.exchangeRate,
    required this.fee,
    required this.amountUsd,
  });

  factory QuotationModel.fromJson(Map<String, dynamic> json) {
    return QuotationModel(
      quoteId: (json['quote_id'] ?? json['id'] ?? '').toString(),
      exchangeRate: (json['exchange_rate'] as num? ?? 1.0).toDouble(),
      fee: (json['fee'] as num? ?? 0.0).toDouble(),
      amountUsd: (json['amount_usd'] as num? ?? 0.0).toDouble(),
    );
  }
}
