class BusinessProfile {
  const BusinessProfile({
    required this.id,
    required this.name,
    required this.type,
    this.logoUrl,
    this.phone,
    this.email,
    this.address,
    this.currency,
    this.taxPercentage,
  });

  factory BusinessProfile.fromJson(Map<String, dynamic> json) {
    final tax = json['tax_percentage'];
    return BusinessProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      logoUrl: json['logo_url'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      currency: json['currency'] as String?,
      taxPercentage: tax == null ? null : (tax as num).toDouble(),
    );
  }

  final String id;
  final String name;
  final String type;
  final String? logoUrl;
  final String? phone;
  final String? email;
  final String? address;
  final String? currency;
  final double? taxPercentage;
}
