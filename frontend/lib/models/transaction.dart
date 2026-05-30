class Transaction {
  final String id;
  final String profileId;
  final String type;
  final int amount;
  final String description;
  final DateTime createdAt;

  Transaction({
    required this.id,
    required this.profileId,
    required this.type,
    required this.amount,
    required this.description,
    required this.createdAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      profileId: json['profile_id'] ?? json['wallet_id'] ?? '',
      type: json['type'] ?? 'UNKNOWN',
      amount: json['amount'] ?? 0,
      description: json['description'] ?? '',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']).toLocal() : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profile_id': profileId,
      'type': type,
      'amount': amount,
      'description': description,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
