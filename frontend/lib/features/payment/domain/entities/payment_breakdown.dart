class PaymentBreakdown {
  final double amountTHB;
  final double exchangeRate;
  final double convenienceFeePercentage;

  // exchangeRate is required: a breakdown must never be computed from an
  // invented rate — callers pass a live quote or a fetched indicative rate.
  const PaymentBreakdown({
    required this.amountTHB,
    required this.exchangeRate,
    this.convenienceFeePercentage = 0.035,
  });

  double get amountUSD => amountTHB / exchangeRate;
  double get feeUSD => amountUSD * convenienceFeePercentage;
  double get totalUSD => amountUSD + feeUSD;
}
