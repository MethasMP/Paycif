class UserProfile {
  final String? lastUsedFiat;
  final String? lastUsedCrypto;
  final String? lastUsedNetwork;
  final String? achUserToken;
  final DateTime? achTokenExpiresAt;

  UserProfile({
    this.lastUsedFiat,
    this.lastUsedCrypto,
    this.lastUsedNetwork,
    this.achUserToken,
    this.achTokenExpiresAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        lastUsedFiat: json['last_used_fiat'] as String?,
        lastUsedCrypto: json['last_used_crypto'] as String?,
        lastUsedNetwork: json['last_used_network'] as String?,
        achUserToken: json['ach_user_token'] as String?,
        achTokenExpiresAt: json['ach_token_expires_at'] != null
            ? DateTime.parse(json['ach_token_expires_at'] as String)
            : null,
      );

  bool get hasValidAchToken =>
      achUserToken != null &&
      achTokenExpiresAt != null &&
      achTokenExpiresAt!.isAfter(DateTime.now());
}
