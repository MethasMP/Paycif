class ExchangeRate {
  final String? fromCurrency;
  final String? toCurrency;
  final double? providerRate;
  final String? updatedAt;

  ExchangeRate({
    this.fromCurrency,
    this.toCurrency,
    this.providerRate,
    this.updatedAt,
  });

  factory ExchangeRate.fromJson(Map<String, dynamic> json) {
    // 1. Safe parsing for Currency Strings
    final from = json['from'] ?? json['from_currency'];
    final to = json['to'] ?? json['to_currency'];

    // 2. Safe parsing for Rate (num -> double)
    final rateVal = json['rate'] ?? json['provider_rate'];
    double? safeRate;
    if (rateVal is num) {
      safeRate = rateVal.toDouble();
    } else if (rateVal is String) {
      safeRate = double.tryParse(rateVal);
    }

    return ExchangeRate(
      fromCurrency: from?.toString(),
      toCurrency: to?.toString(),
      providerRate: safeRate ?? 0.0,
      updatedAt: json['updated_at']?.toString(), // Handle 'updated_at'
    );
  }
}
