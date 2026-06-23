class UserProfile {
  final String? preferredPaymentMethodId;
  final String? preferredPaymentMethodType;

  UserProfile({this.preferredPaymentMethodId, this.preferredPaymentMethodType});

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    preferredPaymentMethodId: json['preferred_payment_method_id'] as String?,
    preferredPaymentMethodType: json['preferred_payment_method_type'] as String?,
  );
}
