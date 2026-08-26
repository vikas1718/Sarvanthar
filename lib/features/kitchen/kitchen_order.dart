class KitchenOrder {
  const KitchenOrder({
    required this.id,
    required this.businessId,
    required this.scope,
    required this.status,
    required this.currency,
    required this.totalAmount,
    required this.createdAt,
    required this.updatedAt,
    required this.items,
    this.stallId,
    this.diningTableId,
    this.tableNumber,
    this.stallName,
  });

  factory KitchenOrder.fromJson(Map<String, dynamic> json) => KitchenOrder(
    id: json['id'] as String,
    businessId: json['business_id'] as String,
    stallId: json['stall_id'] as String?,
    diningTableId: json['dining_table_id'] as String?,
    scope: json['scope'] as String,
    status: json['status'] as String,
    tableNumber: json['table_number'] as String?,
    stallName: json['stall_name'] as String?,
    currency: json['currency'] as String? ?? 'INR',
    totalAmount: (json['total_amount'] as num).toDouble(),
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
    items: _maps(json['order_items']).map(KitchenOrderItem.fromJson).toList(),
  );

  final String id, businessId, scope, status, currency;
  final String? stallId, diningTableId, tableNumber, stallName;
  final double totalAmount;
  final DateTime createdAt, updatedAt;
  final List<KitchenOrderItem> items;

  String get shortId => id.substring(0, 8).toUpperCase();
  String get locationLabel {
    if (tableNumber?.trim().isNotEmpty ?? false) {
      return 'Table ${tableNumber!.trim()}';
    }
    if (stallName?.trim().isNotEmpty ?? false) return stallName!.trim();
    return scope == 'business' ? 'Counter / takeaway' : 'Walk-up order';
  }
}

class KitchenOrderItem {
  const KitchenOrderItem({
    required this.id,
    required this.menuItemId,
    required this.name,
    required this.unitPrice,
    required this.optionsTotal,
    required this.quantity,
    required this.lineTotal,
    required this.createdAt,
    required this.options,
  });

  factory KitchenOrderItem.fromJson(Map<String, dynamic> json) =>
      KitchenOrderItem(
        id: json['id'] as String,
        menuItemId: json['menu_item_id'] as String,
        name: json['item_name'] as String,
        unitPrice: (json['unit_price'] as num).toDouble(),
        optionsTotal: (json['options_total'] as num).toDouble(),
        quantity: json['quantity'] as int,
        lineTotal: (json['line_total'] as num).toDouble(),
        createdAt: DateTime.parse(json['created_at'] as String),
        options: _maps(json['order_item_options'])
            .map(KitchenOrderItemOption.fromJson)
            .toList(),
      );

  final String id, menuItemId, name;
  final double unitPrice, optionsTotal, lineTotal;
  final int quantity;
  final DateTime createdAt;
  final List<KitchenOrderItemOption> options;
}

class KitchenOrderItemOption {
  const KitchenOrderItemOption({
    required this.id,
    required this.menuOptionId,
    required this.optionGroupId,
    required this.groupName,
    required this.optionName,
    required this.priceDelta,
  });

  factory KitchenOrderItemOption.fromJson(Map<String, dynamic> json) =>
      KitchenOrderItemOption(
        id: json['id'] as String,
        menuOptionId: json['menu_option_id'] as String,
        optionGroupId: json['option_group_id'] as String,
        groupName: json['group_name'] as String,
        optionName: json['option_name'] as String,
        priceDelta: (json['price_delta'] as num).toDouble(),
      );

  final String id, menuOptionId, optionGroupId, groupName, optionName;
  final double priceDelta;
}

List<Map<String, dynamic>> _maps(Object? value) => value is List
    ? value.map((row) => Map<String, dynamic>.from(row as Map)).toList()
    : const [];
