class BusinessAccess {
  const BusinessAccess({
    required this.businessId,
    required this.businessName,
    required this.businessType,
    this.businessLogoUrl,
    required this.role,
    this.stallId,
    this.stallName,
  });

  final String businessId;
  final String businessName;
  final String businessType;
  final String? businessLogoUrl;
  final String role;
  final String? stallId;
  final String? stallName;

  bool get isOwner => role == 'owner';
  bool get isFoodCourt => businessType == 'food_court';
}
