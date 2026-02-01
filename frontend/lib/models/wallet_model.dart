import 'exchange_rate_model.dart';

class Wallet {
  final String id;
  final int
  balance; // Stored in minor units as per DB (BigInt -> int in Dart is usually fine for 64-bit, but safely handled as int)
  final String currency;
  final String accountType;

  Wallet({
    required this.id,
    required this.balance,
    required this.currency,
    required this.accountType,
  });

  Wallet copyWith({
    String? id,
    int? balance,
    String? currency,
    String? accountType,
  }) {
    return Wallet(
      id: id ?? this.id,
      balance: balance ?? this.balance,
      currency: currency ?? this.currency,
      accountType: accountType ?? this.accountType,
    );
  }

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      id: json['id'] as String,
      balance: json['balance'] as int,
      currency: json['currency'] as String,
      accountType: json['account_type'] ?? 'VIRTUAL',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'balance': balance,
      'currency': currency,
      'account_type': accountType,
    };
  }

  /// Calculates the equivalent value in the home currency (e.g., THB).
  /// Rate should be FROM this.currency TO homeCurrency.
  double getEstimatedHomeValue(ExchangeRate rate) {
    if (rate.fromCurrency != currency) {
      // In a real app, handle error or cross-calculation better
      return 0.0;
    }
    // Balance is minor units (e.g. cents).
    // We usually want to display major units in UI, but this method returns "Value" which is relative.
    // If we keep it in minor units:
    return balance * (rate.providerRate ?? 0.0);
  }
}
