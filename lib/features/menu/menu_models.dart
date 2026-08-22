class MenuCategory {
  const MenuCategory({
    required this.id,
    required this.name,
    required this.sortOrder,
  });
  factory MenuCategory.fromJson(Map<String, dynamic> j) => MenuCategory(
    id: j['id'] as String,
    name: j['name'] as String,
    sortOrder: j['sort_order'] as int,
  );
  final String id, name;
  final int sortOrder;
}

class MenuItem {
  const MenuItem({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.price,
    required this.available,
    this.description,
    this.imagePath,
  });
  factory MenuItem.fromJson(Map<String, dynamic> j) => MenuItem(
    id: j['id'] as String,
    categoryId: j['category_id'] as String,
    name: j['name'] as String,
    description: j['description'] as String?,
    price: (j['price'] as num).toDouble(),
    imagePath: j['image_path'] as String?,
    available: j['is_available'] as bool,
  );
  final String id, categoryId, name;
  final String? description, imagePath;
  final double price;
  final bool available;
}

class MenuOptionGroup {
  const MenuOptionGroup({
    required this.id,
    required this.name,
    required this.type,
  });
  factory MenuOptionGroup.fromJson(Map<String, dynamic> j) => MenuOptionGroup(
    id: j['id'] as String,
    name: j['name'] as String,
    type: j['type'] as String,
  );
  final String id, name, type;
}
