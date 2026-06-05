class PaymentBreakdown {
  final double amountTHB;
  final double exchangeRate;
  final double convenienceFeePercentage;

  const PaymentBreakdown({
    required this.amountTHB,
    this.exchangeRate = 36.45,
    this.convenienceFeePercentage = 0.035,
  });

  double get amountUSD => amountTHB / exchangeRate;
  double get feeUSD => amountUSD * convenienceFeePercentage;
  double get totalUSD => amountUSD + feeUSD;
}
