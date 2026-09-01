part of '../../main.dart';

class MenuManagementPage extends StatefulWidget {
  const MenuManagementPage({super.key, required this.businessId, required this.stallId, required this.isFoodCourt, required this.role});
  final String businessId, role;
  final String? stallId;
  final bool isFoodCourt;
  @override State<MenuManagementPage> createState() => _MenuManagementPageState();
}

class _MenuManagementPageState extends State<MenuManagementPage> {
  List<MenuCategory> categories = const [];
  List<MenuItem> items = const [];
  List<Stall> stalls = const [];
  String? scope, error;
  bool loading = true, seedAttempted = false;
  bool get canEdit => widget.role == 'owner' || widget.role == 'manager';
  bool get canToggle => canEdit || widget.role == 'kitchen';
  MenuService get service => MenuService(Supabase.instance.client);
  @override void initState() { super.initState(); scope = widget.stallId; _setup(); }

  Future<void> _setup() async {
    try {
      if (widget.isFoodCourt && scope == null) {
        stalls = await StallService(Supabase.instance.client).loadForBusiness(widget.businessId);
        scope = stalls.where((x) => x.isActive).firstOrNull?.id;
      }
      await _load();
    } catch (_) { if (mounted) setState(() { loading = false; error = 'We could not load this menu.'; }); }
  }

  Future<void> _load() async {
    if (widget.isFoodCourt && scope == null) { if (mounted) setState(() => loading = false); return; }
    if (mounted) setState(() { loading = true; error = null; });
    try {
      var data = await Future.wait([service.categories(widget.businessId, scope), service.items(widget.businessId, scope)]);
      var newCategories = data[0] as List<MenuCategory>;
      var newItems = data[1] as List<MenuItem>;
      if (canEdit && !seedAttempted && newCategories.isEmpty && newItems.isEmpty) {
        seedAttempted = true;
        await service.seedDefaultIndianMenu(widget.businessId, scope);
        data = await Future.wait([service.categories(widget.businessId, scope), service.items(widget.businessId, scope)]);
        newCategories = data[0] as List<MenuCategory>;
        newItems = data[1] as List<MenuItem>;
      }
      if (mounted) setState(() { categories = newCategories; items = newItems; loading = false; });
    } catch (_) { if (mounted) setState(() { loading = false; error = 'We could not update the menu. Check your connection and permissions.'; }); }
  }

  List<MenuCategory> _categories(String type) => categories.where((x) => x.dietaryType == type).toList();
  List<MenuItem> _items(String category) => items.where((x) => x.categoryId == category).toList();
  Future<bool> _confirm(String title, String body) async => await showDialog<bool>(context: context, builder: (d) => AlertDialog(title: Text(title), content: Text(body), actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Delete'))])) ?? false;

  Future<void> _categoryForm({MenuCategory? category, String? initialType}) async {
    final name = TextEditingController(text: category?.name);
    var type = category?.dietaryType ?? initialType ?? 'veg', saving = false;
    final saved = await showDialog<bool>(context: context, builder: (d) => StatefulBuilder(builder: (d, setDialog) => AlertDialog(title: Text(category == null ? 'Add category' : 'Edit category'), content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: name, autofocus: true, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Category name')), const SizedBox(height: 12), DropdownButtonFormField<String>(initialValue: type, decoration: const InputDecoration(labelText: 'Menu section'), items: const [DropdownMenuItem(value: 'veg', child: Text('Veg menu')), DropdownMenuItem(value: 'non_veg', child: Text('Non-Veg menu'))], onChanged: category != null && _items(category.id).isNotEmpty ? null : (v) => setDialog(() => type = v!)), if (category != null && _items(category.id).isNotEmpty) const Padding(padding: EdgeInsets.only(top: 8), child: Text('Move or archive items before changing its section.', style: TextStyle(color: _muted, fontSize: 12)))])), actions: [TextButton(onPressed: saving ? null : () => Navigator.pop(d, false), child: const Text('Cancel')), FilledButton(onPressed: saving ? null : () async { if (name.text.trim().isEmpty) { _notice(context, 'Category name is required.'); return; } setDialog(() => saving = true); try { if (category == null) { await service.createCategory(widget.businessId, scope, name.text.trim(), type); } else { await service.editCategory(category, name.text.trim(), category.sortOrder, type); } if (d.mounted) Navigator.pop(d, true); } catch (_) { setDialog(() => saving = false); if (mounted) _notice(context, 'Could not save this category.'); } }, child: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'))])));
    name.dispose(); if (saved == true) { await _load(); if (mounted) _notice(context, 'Category saved.'); }
  }

  bool _validUrl(String text) { if (text.trim().isEmpty) return true; final url = Uri.tryParse(text.trim()); return url != null && (url.scheme == 'http' || url.scheme == 'https') && url.host.isNotEmpty; }

  Future<void> _itemForm({MenuItem? item, String? initialCategory}) async {
    final name = TextEditingController(text: item?.name), description = TextEditingController(text: item?.description), price = TextEditingController(text: item?.price.toStringAsFixed(2)), image = TextEditingController(text: item?.imagePath);
    var type = item?.dietaryType ?? (initialCategory == null ? 'veg' : categories.firstWhere((x) => x.id == initialCategory).dietaryType);
    var categoryId = item?.categoryId ?? initialCategory ?? _categories(type).firstOrNull?.id, available = item?.available ?? true, saving = false;
    final saved = await showDialog<bool>(context: context, builder: (d) => StatefulBuilder(builder: (d, setDialog) {
      final filtered = _categories(type);
      if (!filtered.any((x) => x.id == categoryId)) categoryId = filtered.firstOrNull?.id;
      return AlertDialog(title: Text(item == null ? 'Add menu item' : 'Edit menu item'), content: SizedBox(width: 500, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Item name *')), const SizedBox(height: 12), TextField(controller: description, maxLines: 2, decoration: const InputDecoration(labelText: 'Description')), const SizedBox(height: 12), TextField(controller: price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Price *', prefixText: '₹ ')), const SizedBox(height: 12), DropdownButtonFormField<String>(initialValue: type, decoration: const InputDecoration(labelText: 'Dietary type *'), items: const [DropdownMenuItem(value: 'veg', child: Text('Veg')), DropdownMenuItem(value: 'non_veg', child: Text('Non-Veg'))], onChanged: (v) => setDialog(() { type = v!; categoryId = _categories(type).firstOrNull?.id; })), const SizedBox(height: 12), DropdownButtonFormField<String>(initialValue: categoryId, decoration: const InputDecoration(labelText: 'Category *'), items: filtered.map((x) => DropdownMenuItem(value: x.id, child: Text(x.name))).toList(), onChanged: (v) => setDialog(() => categoryId = v)), const SizedBox(height: 12), TextField(controller: image, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'Image URL', hintText: 'https://images.unsplash.com/...')), SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, title: const Text('Available'), value: available, onChanged: (v) => setDialog(() => available = v))]))), actions: [TextButton(onPressed: saving ? null : () => Navigator.pop(d, false), child: const Text('Cancel')), FilledButton(onPressed: saving ? null : () async { final value = double.tryParse(price.text.trim()); if (name.text.trim().isEmpty || value == null || value < 0 || categoryId == null) { _notice(context, 'Enter an item name, valid price, dietary type, and category.'); return; } if (!_validUrl(image.text)) { _notice(context, 'Enter a valid http or https image URL.'); return; } setDialog(() => saving = true); try { await service.saveItem(item: item, b: widget.businessId, s: scope, category: categoryId!, name: name.text.trim(), description: description.text.trim(), price: value, image: image.text.trim().isEmpty ? null : image.text.trim(), dietaryType: type, available: available); if (d.mounted) Navigator.pop(d, true); } catch (_) { setDialog(() => saving = false); if (mounted) _notice(context, 'Could not save this item.'); } }, child: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'))]);
    }));
    name.dispose(); description.dispose(); price.dispose(); image.dispose(); if (saved == true) { await _load(); if (mounted) _notice(context, 'Menu item saved.'); }
  }

  Future<void> _deleteCategory(MenuCategory category) async {
    final count = _items(category.id).length;
    if (count > 0) { await _confirm('Category contains items', '“${category.name}” contains $count item${count == 1 ? '' : 's'}. Move or archive them before deleting the category.'); return; }
    if (!await _confirm('Delete category', 'Delete “${category.name}”? This cannot be undone.')) return;
    try { await service.archiveCategory(category.id); await _load(); if (mounted) _notice(context, 'Category deleted.'); } catch (_) { if (mounted) _notice(context, 'Could not delete this category.'); }
  }
  Future<void> _deleteItem(MenuItem item) async { if (!await _confirm('Delete menu item', 'Delete “${item.name}”? This cannot be undone.')) return; try { await service.archiveItem(item.id); await _load(); if (mounted) _notice(context, 'Menu item deleted.'); } catch (_) { if (mounted) _notice(context, 'Could not delete this item.'); } }

  @override Widget build(BuildContext context) => _PageShell(title: 'Menu', subtitle: widget.isFoodCourt ? 'The universal menu for the selected stall.' : 'Your restaurant’s universal menu, organised by dietary preference.', action: canEdit ? FilledButton.icon(onPressed: () => _categoryForm(), icon: const Icon(Icons.add), label: const Text('Add category')) : null, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [if (widget.isFoodCourt && widget.stallId == null) ...[DropdownButtonFormField<String>(initialValue: scope, decoration: const InputDecoration(labelText: 'Food court stall'), items: stalls.where((x) => x.isActive).map((x) => DropdownMenuItem(value: x.id, child: Text(x.name))).toList(), onChanged: (v) { scope = v; seedAttempted = false; _load(); }), const SizedBox(height: 18)], if (loading) const Center(child: Padding(padding: EdgeInsets.all(36), child: CircularProgressIndicator())) else if (error != null) _Panel(child: Text(error!)) else if (categories.isEmpty) _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('No menu categories yet.'), if (canEdit) TextButton.icon(onPressed: () => _categoryForm(), icon: const Icon(Icons.add), label: const Text('Add your first category'))])) else ...[_MenuSection(title: 'VEG MENU', type: 'veg', categories: _categories('veg'), canEdit: canEdit, canToggle: canToggle, itemsFor: _items, onCategory: _categoryForm, onDeleteCategory: _deleteCategory, onItem: _itemForm, onDeleteItem: _deleteItem, onAvailability: _availability), const SizedBox(height: 16), _MenuSection(title: 'NON-VEG MENU', type: 'non_veg', categories: _categories('non_veg'), canEdit: canEdit, canToggle: canToggle, itemsFor: _items, onCategory: _categoryForm, onDeleteCategory: _deleteCategory, onItem: _itemForm, onDeleteItem: _deleteItem, onAvailability: _availability)]]));
  Future<void> _availability(MenuItem item, bool value) async { try { await service.availability(item.id, value); await _load(); } catch (_) { if (mounted) _notice(context, 'Could not update availability.'); } }
}

class _MenuSection extends StatelessWidget {
  const _MenuSection({required this.title, required this.type, required this.categories, required this.canEdit, required this.canToggle, required this.itemsFor, required this.onCategory, required this.onDeleteCategory, required this.onItem, required this.onDeleteItem, required this.onAvailability});
  final String title, type; final List<MenuCategory> categories; final bool canEdit, canToggle; final List<MenuItem> Function(String) itemsFor; final Future<void> Function({MenuCategory? category, String? initialType}) onCategory; final Future<void> Function(MenuCategory) onDeleteCategory; final Future<void> Function({MenuItem? item, String? initialCategory}) onItem; final Future<void> Function(MenuItem) onDeleteItem; final Future<void> Function(MenuItem, bool) onAvailability;
  @override Widget build(BuildContext context) => _Panel(child: ExpansionTile(initiallyExpanded: true, tilePadding: EdgeInsets.zero, leading: _MenuDietaryBadge(type: type), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${categories.length} categor${categories.length == 1 ? 'y' : 'ies'}'), trailing: canEdit ? TextButton.icon(onPressed: () => onCategory(initialType: type), icon: const Icon(Icons.add, size: 18), label: const Text('Category')) : null, children: categories.isEmpty ? [Padding(padding: const EdgeInsets.only(bottom: 12), child: Text('No ${type == 'veg' ? 'Veg' : 'Non-Veg'} categories yet.', style: const TextStyle(color: _muted)))] : categories.map((category) => _MenuCategoryCard(category: category, items: itemsFor(category.id), canEdit: canEdit, canToggle: canToggle, onEdit: () => onCategory(category: category), onDelete: () => onDeleteCategory(category), onAddItem: () => onItem(initialCategory: category.id), onItem: onItem, onDeleteItem: onDeleteItem, onAvailability: onAvailability)).toList()));
}

class _MenuCategoryCard extends StatelessWidget {
  const _MenuCategoryCard({required this.category, required this.items, required this.canEdit, required this.canToggle, required this.onEdit, required this.onDelete, required this.onAddItem, required this.onItem, required this.onDeleteItem, required this.onAvailability});
  final MenuCategory category; final List<MenuItem> items; final bool canEdit, canToggle; final VoidCallback onEdit, onDelete, onAddItem; final Future<void> Function({MenuItem? item, String? initialCategory}) onItem; final Future<void> Function(MenuItem) onDeleteItem; final Future<void> Function(MenuItem, bool) onAvailability;
  @override Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(top: 10), padding: const EdgeInsets.all(14), decoration: BoxDecoration(border: Border.all(color: _line), borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(category.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)), Text('${items.length} item${items.length == 1 ? '' : 's'}', style: const TextStyle(color: _muted, fontSize: 12))])), if (canEdit) IconButton(tooltip: 'Edit category', onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 20)), if (canEdit) IconButton(tooltip: 'Delete category', onPressed: onDelete, icon: const Icon(Icons.delete_outline, size: 20)), if (canEdit) OutlinedButton.icon(onPressed: onAddItem, icon: const Icon(Icons.add, size: 18), label: const Text('Item'))]), if (items.isEmpty) const Padding(padding: EdgeInsets.only(top: 10), child: Text('No items in this category.', style: TextStyle(color: _muted))) else ...items.map((item) => _MenuManagementItemCard(item: item, canEdit: canEdit, canToggle: canToggle, onEdit: () => onItem(item: item), onDelete: () => onDeleteItem(item), onAvailability: (v) => onAvailability(item, v))) ]));
}

class _MenuManagementItemCard extends StatelessWidget {
  const _MenuManagementItemCard({required this.item, required this.canEdit, required this.canToggle, required this.onEdit, required this.onDelete, required this.onAvailability}); final MenuItem item; final bool canEdit, canToggle; final VoidCallback onEdit, onDelete; final ValueChanged<bool> onAvailability;
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(top: 12), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [_MenuImage(url: item.imagePath), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700))), _MenuDietaryBadge(type: item.dietaryType, compact: true)]), if ((item.description ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text(item.description!, style: const TextStyle(color: _muted, fontSize: 13))), Padding(padding: const EdgeInsets.only(top: 5), child: Text('₹${item.price.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800, color: _navy)))])), Column(children: [Switch(value: item.available, onChanged: canToggle ? onAvailability : null), if (canEdit) Row(mainAxisSize: MainAxisSize.min, children: [IconButton(tooltip: 'Edit item', onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 19)), IconButton(tooltip: 'Delete item', onPressed: onDelete, icon: const Icon(Icons.delete_outline, size: 19))])]) ]));
}

class _MenuDietaryBadge extends StatelessWidget { const _MenuDietaryBadge({required this.type, this.compact = false}); final String type; final bool compact; @override Widget build(BuildContext context) { final veg = type == 'veg'; final color = veg ? const Color(0xff278343) : const Color(0xffb33a35); return Semantics(label: veg ? 'Vegetarian' : 'Non-vegetarian', child: Container(padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: 4), decoration: BoxDecoration(color: color.withValues(alpha: .1), borderRadius: BorderRadius.circular(8)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(veg ? Icons.eco_outlined : Icons.restaurant, size: compact ? 14 : 18, color: color), const SizedBox(width: 4), Text(veg ? 'Veg' : 'Non-Veg', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: compact ? 11 : 12))]))); } }
class _MenuImage extends StatelessWidget { const _MenuImage({this.url}); final String? url; @override Widget build(BuildContext context) => ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(width: 64, height: 64, child: url == null || url!.isEmpty ? _placeholder() : Image.network(url!, fit: BoxFit.cover, errorBuilder: (_, _, _) => _placeholder(), loadingBuilder: (_, child, progress) => progress == null ? child : const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))))); Widget _placeholder() => Container(color: _cream, child: const Icon(Icons.restaurant_menu_outlined, color: _muted)); }
