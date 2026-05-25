class Transaction {
  final String id;
  final String walletId;
  final String type;
  final int amount;
  final String description;
  final DateTime createdAt;

  Transaction({
    required this.id,
    required this.walletId,
    required this.type,
    required this.amount,
    required this.description,
    required this.createdAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      walletId: json['wallet_id'],
      type: json['type'],
      amount: json['amount'],
      // Handle potential null description from backend (though SQL usually returns empty string if not null)
      description: json['description'] ?? '',
      createdAt: DateTime.parse(json['created_at']).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'wallet_id': walletId,
      'type': type,
      'amount': amount,
      'description': description,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
