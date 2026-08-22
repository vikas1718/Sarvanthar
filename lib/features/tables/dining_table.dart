class DiningTable {
  const DiningTable({
    required this.id,
    required this.businessId,
    required this.number,
    required this.capacity,
    required this.status,
    required this.type,
  });

  factory DiningTable.fromJson(Map<String, dynamic> json) => DiningTable(
    id: json['id'] as String,
    businessId: json['business_id'] as String,
    number: json['table_number'] as String,
    capacity: json['capacity'] as int,
    status: json['status'] as String,
    type: json['type'] as String,
  );

  final String id;
  final String businessId;
  final String number;
  final int capacity;
  final String status;
  final String type;

  bool get isActive => status == 'active';
}
