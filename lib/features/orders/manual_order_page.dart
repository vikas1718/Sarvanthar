part of '../../main.dart';

class ManualOrderPage extends StatefulWidget {
  const ManualOrderPage({
    super.key,
    required this.businessId,
    required this.stallId,
  });

  final String businessId;
  final String? stallId;

  @override
  State<ManualOrderPage> createState() => _ManualOrderPageState();
}

class _ManualOrderPageState extends State<ManualOrderPage> {
  late final TableService _tableService;
  late final MenuService _menuService;
  late final ManualOrderService _orderService;
  List<DiningTable> _tables = const [];
  List<MenuCategory> _categories = const [];
  List<MenuItem> _items = const [];
  final Map<String, int> _cart = {};
  String? _tableId;
  String? _categoryId;
  bool _loading = true;
  bool _sending = false;
  String? _error;
  String? _submissionId;

  @override
  void initState() {
    super.initState();
    final client = Supabase.instance.client;
    _tableService = TableService(client);
    _menuService = MenuService(client);
    _orderService = ManualOrderService(client);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = await Future.wait([
        _tableService.load(widget.businessId),
        _menuService.categories(widget.businessId, widget.stallId),
        _menuService.items(widget.businessId, widget.stallId),
      ]);
      if (!mounted) return;
      final categories = values[1] as List<MenuCategory>;
      setState(() {
        _tables = (values[0] as List<DiningTable>)
            .where((table) => table.isActive)
            .toList();
        _categories = categories;
        _items = (values[2] as List<MenuItem>)
            .where((item) => item.available)
            .toList();
        _categoryId = categories.isEmpty ? null : categories.first.id;
      });
    } on PostgrestException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load tables and menu.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeQuantity(MenuItem item, int amount) {
    setState(() {
      final next = (_cart[item.id] ?? 0) + amount;
      if (next <= 0)
        _cart.remove(item.id);
      else
        _cart[item.id] = next;
    });
  }

  double get _total => _cart.entries.fold(0, (total, entry) {
    final item = _items.firstWhere((value) => value.id == entry.key);
    return total + item.price * entry.value;
  });

  Future<void> _sendToKot() async {
    if (_tableId == null) {
      _notice(context, 'Select a table first.');
      return;
    }
    if (_cart.isEmpty) {
      _notice(context, 'Add at least one food item.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send to KOT?'),
        content: Text(
          '${_cart.length} item type(s) will be sent to the kitchen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Review'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send to KOT'),
          ),
        ],
      ),
    );
    if (confirmed != true || _sending) return;

    setState(() => _sending = true);
    try {
      final orderId = await _orderService.submit(
        tableId: _tableId!,
        stallId: widget.stallId,
        requestId: _submissionId ??= _requestId(),
        items: _cart.entries
            .map(
              (entry) => {'menu_item_id': entry.key, 'quantity': entry.value},
            )
            .toList(),
      );
      if (!mounted) return;
      setState(() {
        _cart.clear();
        _submissionId = null;
      });
      _notice(
        context,
        'Sent to KOT successfully (#${orderId.substring(0, 8).toUpperCase()}).',
      );
    } on PostgrestException catch (e) {
      if (mounted) _notice(context, e.message);
    } catch (_) {
      if (mounted)
        _notice(context, 'Could not send this order. Please try again.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _requestId() {
    final seed = DateTime.now().microsecondsSinceEpoch
        .toRadixString(16)
        .padLeft(12, '0');
    final random = DateTime.now().millisecondsSinceEpoch
        .toRadixString(16)
        .padLeft(12, '0');
    return '${seed.substring(0, 8)}-${seed.substring(8, 12)}-4000-8000-${random.substring(0, 12)}';
  }

  @override
  Widget build(BuildContext context) => _PageShell(
    title: 'Take order',
    subtitle: 'Select a table, add food items, then send one order to KOT.',
    child: _loading
        ? const Center(
            child: Padding(
              padding: EdgeInsets.all(64),
              child: CircularProgressIndicator(),
            ),
          )
        : _error != null
        ? _KitchenMessage(
            message: _error!,
            action: OutlinedButton(
              onPressed: _load,
              child: const Text('Retry'),
            ),
          )
        : LayoutBuilder(
            builder: (context, box) {
              final menu = _menuPane();
              final review = _reviewPane();
              return box.maxWidth >= 900
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: menu),
                        const SizedBox(width: 18),
                        SizedBox(width: 360, child: review),
                      ],
                    )
                  : Column(
                      children: [menu, const SizedBox(height: 18), review],
                    );
            },
          ),
  );

  Widget _menuPane() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _Panel(
        child: DropdownButtonFormField<String>(
          value: _tableId,
          decoration: const InputDecoration(labelText: '1. Select table'),
          items: _tables
              .map(
                (table) => DropdownMenuItem(
                  value: table.id,
                  child: Text(
                    'Table ${table.number} · ${table.capacity} seats',
                  ),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _tableId = value),
        ),
      ),
      const SizedBox(height: 16),
      _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '2. Select food',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories
                  .map(
                    (category) => ChoiceChip(
                      label: Text(category.name),
                      selected: category.id == _categoryId,
                      onSelected: (_) =>
                          setState(() => _categoryId = category.id),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      if (_items.where((item) => item.categoryId == _categoryId).isEmpty)
        const _KitchenMessage(
          message: 'No available menu items in this category.',
        )
      else
        ..._items
            .where((item) => item.categoryId == _categoryId)
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ManualMenuItem(
                  item: item,
                  quantity: _cart[item.id] ?? 0,
                  onMinus: () => _changeQuantity(item, -1),
                  onPlus: () => _changeQuantity(item, 1),
                ),
              ),
            ),
    ],
  );

  Widget _reviewPane() => _Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '3. Review order',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const SizedBox(height: 14),
        if (_cart.isEmpty)
          const Text('No items selected yet.')
        else
          ..._cart.entries.map((entry) {
            final item = _items.firstWhere((value) => value.id == entry.key);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(child: Text(item.name)),
                  Text('${entry.value} × ₹${item.price.toStringAsFixed(0)}'),
                ],
              ),
            );
          }),
        const Divider(height: 28),
        _SummaryRow(
          label: 'Total',
          value: '₹${_total.toStringAsFixed(2)}',
          bold: true,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _sending ? null : _sendToKot,
            icon: _sending
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded),
            label: Text(_sending ? 'Sending…' : 'SEND TO KOT'),
          ),
        ),
      ],
    ),
  );
}

class _ManualMenuItem extends StatelessWidget {
  const _ManualMenuItem({
    required this.item,
    required this.quantity,
    required this.onMinus,
    required this.onPlus,
  });
  final MenuItem item;
  final int quantity;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) => _Panel(
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              if (item.description?.isNotEmpty == true) Text(item.description!),
              const SizedBox(height: 4),
              Text('₹${item.price.toStringAsFixed(2)}'),
            ],
          ),
        ),
        IconButton(
          onPressed: quantity == 0 ? null : onMinus,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Text('$quantity', style: const TextStyle(fontWeight: FontWeight.w800)),
        IconButton(
          onPressed: onPlus,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    ),
  );
}
