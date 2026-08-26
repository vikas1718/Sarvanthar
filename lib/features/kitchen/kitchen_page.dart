part of '../../main.dart';

class KitchenPage extends StatefulWidget {
  const KitchenPage({
    super.key,
    required this.businessId,
    required this.stallId,
    required this.role,
  });
  final String businessId, role;
  final String? stallId;

  @override
  State<KitchenPage> createState() => _KitchenPageState();
}

class _KitchenPageState extends State<KitchenPage> {
  late final KitchenService _service;
  RealtimeChannel? _channel;
  Timer? _debounce;
  List<KitchenOrder> _orders = const [];
  final _updating = <String>{};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = KitchenService(Supabase.instance.client);
    _subscribe();
    _load();
  }

  @override
  void didUpdateWidget(covariant KitchenPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.businessId != widget.businessId ||
        oldWidget.stallId != widget.stallId ||
        oldWidget.role != widget.role) {
      _unsubscribe();
      _subscribe();
      _load();
    }
  }

  void _subscribe() {
    _channel = _service.subscribe(
      businessId: widget.businessId,
      onChange: () {
        // place_order can produce closely spaced events; one graph reload is enough.
        _debounce?.cancel();
        _debounce = Timer(
          const Duration(milliseconds: 250),
          () => _load(progress: false),
        );
      },
    );
  }

  void _unsubscribe() {
    final channel = _channel;
    _channel = null;
    if (channel != null) _service.unsubscribe(channel);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _unsubscribe();
    super.dispose();
  }

  Future<void> _load({bool progress = true}) async {
    if (progress && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final values = await _service.loadActiveOrders(
        businessId: widget.businessId,
        stallId: widget.stallId,
      );
      if (mounted) setState(() => _orders = values);
    } on PostgrestException catch (error) {
      if (mounted) setState(() => _error = _kitchenError(error));
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load active orders.');
    } finally {
      if (progress && mounted) setState(() => _loading = false);
    }
  }

  Future<void> _update(KitchenOrder order, String status) async {
    setState(() => _updating.add(order.id));
    try {
      await _service.updateStatus(order.id, status);
      await _load(progress: false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order marked ${_statusLabel(status)}.')),
        );
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_kitchenError(error))));
      }
    } finally {
      if (mounted) setState(() => _updating.remove(order.id));
    }
  }

  @override
  Widget build(BuildContext context) => _PageShell(
    title: 'Kitchen orders',
    subtitle: widget.stallId == null
        ? 'Incoming orders across this workspace update live.'
        : 'Incoming orders for this stall update live.',
    action: const _KitchenLiveBadge(),
    child: _loading
        ? const Padding(
            padding: EdgeInsets.symmetric(vertical: 64),
            child: Center(child: CircularProgressIndicator()),
          )
        : _error != null
        ? _KitchenMessage(
            message: _error!,
            action: OutlinedButton(
              onPressed: _load,
              child: const Text('Retry'),
            ),
          )
        : _orders.isEmpty
        ? const _KitchenMessage(
            message: 'No active orders. New orders will appear automatically.',
            icon: Icons.room_service_outlined,
          )
        : Column(
            children: _orders
                .map(
                  (order) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _KitchenOrderCard(
                      order: order,
                      role: widget.role,
                      updating: _updating.contains(order.id),
                      onStatus: (status) => _update(order, status),
                    ),
                  ),
                )
                .toList(),
          ),
  );
}

class _KitchenOrderCard extends StatelessWidget {
  const _KitchenOrderCard({
    required this.order,
    required this.role,
    required this.updating,
    required this.onStatus,
  });
  final KitchenOrder order;
  final String role;
  final bool updating;
  final ValueChanged<String> onStatus;

  @override
  Widget build(BuildContext context) {
    final actions = _nextStatuses(order.status, role);
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '#${order.shortId}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              _KitchenStatus(order.status),
              _KitchenMeta(Icons.place_outlined, order.locationLabel),
              _KitchenMeta(
                Icons.schedule_outlined,
                _orderTime(context, order.createdAt),
              ),
            ],
          ),
          const Divider(color: _line, height: 28),
          if (order.items.isEmpty)
            const Text('Order items are unavailable.')
          else
            ...order.items.map((item) => _KitchenItem(item)),
          const Divider(color: _line, height: 28),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Total ${_money(order.currency, order.totalAmount)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (updating)
                const SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                ...actions.map(
                  (status) => status == 'cancelled'
                      ? OutlinedButton(
                          onPressed: () => onStatus(status),
                          child: const Text('Cancel order'),
                        )
                      : FilledButton(
                          onPressed: () => onStatus(status),
                          child: Text(_actionLabel(status)),
                        ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KitchenItem extends StatelessWidget {
  const _KitchenItem(this.item);
  final KitchenOrderItem item;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          padding: const EdgeInsets.symmetric(vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xfffff1df),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${item.quantity}×',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _navy,
                ),
              ),
              if (item.options.isNotEmpty)
                Text(
                  item.options
                      .map(
                        (option) => '${option.groupName}: ${option.optionName}',
                      )
                      .join(' · '),
                  style: const TextStyle(fontSize: 12),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _KitchenMeta extends StatelessWidget {
  const _KitchenMeta(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: _muted),
      const SizedBox(width: 4),
      Text(text),
    ],
  );
}

class _KitchenStatus extends StatelessWidget {
  const _KitchenStatus(this.status);
  final String status;
  @override
  Widget build(BuildContext context) {
    final ready = status == 'ready';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: ready ? const Color(0xffeaf7ef) : const Color(0xfffff1df),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: ready ? const Color(0xff39825c) : const Color(0xffa35809),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _KitchenLiveBadge extends StatelessWidget {
  const _KitchenLiveBadge();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xffeaf7ef),
      borderRadius: BorderRadius.circular(10),
    ),
    child: const Text(
      '●  LIVE',
      style: TextStyle(
        color: Color(0xff39825c),
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _KitchenMessage extends StatelessWidget {
  const _KitchenMessage({required this.message, this.icon, this.action});
  final String message;
  final IconData? icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) => _Panel(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 42, color: _amber),
              const SizedBox(height: 10),
            ],
            Text(message, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 12), action!],
          ],
        ),
      ),
    ),
  );
}

List<String> _nextStatuses(String status, String role) {
  final values = <String>[];
  if ((status == 'received' || status == 'preparing') &&
      const {'owner', 'manager', 'kitchen'}.contains(role)) {
    values.add(status == 'received' ? 'preparing' : 'ready');
  }
  if (status == 'ready' &&
      const {'owner', 'manager', 'cashier'}.contains(role)) {
    values.add('completed');
  }
  if ((status == 'received' || status == 'preparing') &&
      const {'owner', 'manager', 'cashier'}.contains(role)) {
    values.add('cancelled');
  }
  return values;
}

String _statusLabel(String status) => switch (status) {
  'received' => 'Received',
  'preparing' => 'Preparing',
  'ready' => 'Ready',
  'completed' => 'Completed',
  'cancelled' => 'Cancelled',
  _ => status,
};
String _actionLabel(String status) => switch (status) {
  'preparing' => 'Start preparing',
  'ready' => 'Mark ready',
  'completed' => 'Complete order',
  _ => _statusLabel(status),
};
String _money(String currency, double amount) {
  final symbol = switch (currency.toUpperCase()) {
    'INR' => '₹',
    'USD' => r'$',
    'EUR' => '€',
    'GBP' => '£',
    _ => '${currency.toUpperCase()} ',
  };
  return '$symbol${amount.toStringAsFixed(2)}';
}

String _orderTime(BuildContext context, DateTime value) {
  final local = value.toLocal();
  final now = DateTime.now();
  final time = MaterialLocalizations.of(context)
      .formatTimeOfDay(TimeOfDay.fromDateTime(local));
  return now.year == local.year &&
          now.month == local.month &&
          now.day == local.day
      ? 'Today, $time'
      : '${local.day}/${local.month}/${local.year}, $time';
}

String _kitchenError(PostgrestException error) {
  if (error.message.contains('Transition from')) return error.message;
  if (error.message == 'Order status update is not permitted') {
    return 'You do not have permission to update this order.';
  }
  if (error.message == 'Order not found') return 'That order no longer exists.';
  return 'Could not update orders. Please try again.';
}
