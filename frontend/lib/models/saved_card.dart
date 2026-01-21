enum CardBrand { visa, mastercard, amex, jcb, unknown }

class SavedCard {
  final String id;
  final String brand;
  final String lastDigits;
  final int expirationMonth;
  final int expirationYear;

  SavedCard({
    required this.id,
    required this.brand,
    required this.lastDigits,
    required this.expirationMonth,
    required this.expirationYear,
  });

  factory SavedCard.fromJson(Map<String, dynamic> json) {
    return SavedCard(
      id: json['id'] as String,
      brand: json['brand'] as String,
      lastDigits: json['last_digits'] as String,
      expirationMonth: json['expiration_month'] as int,
      expirationYear: json['expiration_year'] as int,
    );
  }

  String get formattedExpiry =>
      '${expirationMonth.toString().padLeft(2, '0')}/${expirationYear.toString().substring(2)}';
}
