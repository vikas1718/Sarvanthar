class Stall {
  const Stall({
    required this.id,
    required this.businessId,
    required this.name,
    required this.status,
    this.slug,
  });

  factory Stall.fromJson(Map<String, dynamic> json) => Stall(
    id: json['id'] as String,
    businessId: json['business_id'] as String,
    name: json['name'] as String,
    slug: json['slug'] as String?,
    status: json['status'] as String,
  );

  final String id;
  final String businessId;
  final String name;
  final String? slug;
  final String status;

  bool get isActive => status == 'active';
}
