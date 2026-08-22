part of '../../main.dart';

class TableManagementPage extends StatefulWidget {
  const TableManagementPage({super.key, required this.businessId});

  final String businessId;

  @override
  State<TableManagementPage> createState() => _TableManagementPageState();
}

class _TableManagementPageState extends State<TableManagementPage> {
  late final TableService _service;
  List<DiningTable> _tables = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = TableService(Supabase.instance.client);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = await _service.load(widget.businessId);
      if (mounted) setState(() => _tables = values);
    } on PostgrestException catch (error) {
      if (mounted) setState(() => _error = _tableError(error));
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load tables.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm([DiningTable? table]) async {
    final draft = await showDialog<_TableDraft>(
      context: context,
      builder: (_) => _TableFormDialog(table: table),
    );
    if (draft == null) return;
    setState(() => _loading = true);
    try {
      await _service.save(
        table: table,
        businessId: widget.businessId,
        number: draft.number,
        capacity: draft.capacity,
        type: draft.type,
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(table == null ? 'Table created.' : 'Table updated.'),
          ),
        );
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        setState(() => _loading = false);
        _showError(_tableError(error));
      }
    }
  }

  Future<void> _setStatus(DiningTable table, bool active) async {
    try {
      await _service.setStatus(
        businessId: widget.businessId,
        table: table,
        active: active,
      );
      await _load();
    } on PostgrestException catch (error) {
      if (mounted) _showError(_tableError(error));
    }
  }

  Future<void> _archive(DiningTable table) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive table?'),
        content: Text(
          'Table ${table.number} will disappear from active table management. '
          'Its record will remain available for future order history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.archive(businessId: widget.businessId, tableId: table.id);
      await _load();
    } on PostgrestException catch (error) {
      if (mounted) _showError(_tableError(error));
    }
  }

  void _showError(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) => _PageShell(
    title: 'Tables',
    subtitle: 'Manage the shared tables available across this business.',
    action: FilledButton.icon(
      onPressed: _loading ? null : () => _openForm(),
      icon: const Icon(Icons.add_rounded),
      label: const Text('Add table'),
    ),
    child: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(
            child: Column(
              children: [
                Text(_error!),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          )
        : _tables.isEmpty
        ? const _EmptyTables()
        : LayoutBuilder(
            builder: (_, constraints) => Wrap(
              spacing: 14,
              runSpacing: 14,
              children: _tables
                  .map(
                    (table) => SizedBox(
                      width: constraints.maxWidth >= 720
                          ? (constraints.maxWidth - 14) / 2
                          : constraints.maxWidth,
                      child: _TableCard(
                        table: table,
                        onEdit: () => _openForm(table),
                        onStatus: (value) => _setStatus(table, value),
                        onArchive: () => _archive(table),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
  );
}

class _TableCard extends StatelessWidget {
  const _TableCard({
    required this.table,
    required this.onEdit,
    required this.onStatus,
    required this.onArchive,
  });

  final DiningTable table;
  final VoidCallback onEdit, onArchive;
  final ValueChanged<bool> onStatus;

  @override
  Widget build(BuildContext context) => _Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xfffff1db),
              child: Icon(
                table.type == 'outdoor'
                    ? Icons.deck_outlined
                    : Icons.table_restaurant_outlined,
                color: _amber,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Table ${table.number}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '${table.capacity} seats · ${table.type == 'outdoor' ? 'Outdoor' : 'Indoor'}',
                  ),
                ],
              ),
            ),
            Switch(value: table.isActive, onChanged: onStatus),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _StatusPill(active: table.isActive),
            const Spacer(),
            TextButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit'),
            ),
            IconButton(
              onPressed: onArchive,
              tooltip: 'Archive',
              icon: const Icon(Icons.archive_outlined),
            ),
          ],
        ),
      ],
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.active});
  final bool active;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: active ? const Color(0xffeaf7ef) : const Color(0xfff1f2f4),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      active ? 'Active' : 'Inactive',
      style: TextStyle(
        color: active ? const Color(0xff39825c) : _muted,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _EmptyTables extends StatelessWidget {
  const _EmptyTables();
  @override
  Widget build(BuildContext context) => const _Panel(
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: 42),
      child: Center(child: Text('No tables yet. Add the first shared table.')),
    ),
  );
}

class _TableFormDialog extends StatefulWidget {
  const _TableFormDialog({this.table});
  final DiningTable? table;
  @override
  State<_TableFormDialog> createState() => _TableFormDialogState();
}

class _TableFormDialogState extends State<_TableFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _number;
  late final TextEditingController _capacity;
  late String _type;

  @override
  void initState() {
    super.initState();
    _number = TextEditingController(text: widget.table?.number);
    _capacity = TextEditingController(
      text: widget.table?.capacity.toString() ?? '2',
    );
    _type = widget.table?.type ?? 'indoor';
  }

  @override
  void dispose() {
    _number.dispose();
    _capacity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.table == null ? 'Add table' : 'Edit table'),
    content: SizedBox(
      width: 420,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _number,
              decoration: const InputDecoration(
                labelText: 'Table number or name',
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a table number or name.'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _capacity,
              decoration: const InputDecoration(labelText: 'Capacity'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                final capacity = int.tryParse(value ?? '');
                return capacity == null || capacity < 1 || capacity > 100
                    ? 'Capacity must be between 1 and 100.'
                    : null;
              },
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: const [
                DropdownMenuItem(value: 'indoor', child: Text('Indoor')),
                DropdownMenuItem(value: 'outdoor', child: Text('Outdoor')),
              ],
              onChanged: (value) => setState(() => _type = value ?? 'indoor'),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(
            context,
            _TableDraft(
              number: _number.text.trim(),
              capacity: int.parse(_capacity.text),
              type: _type,
            ),
          );
        },
        child: const Text('Save'),
      ),
    ],
  );
}

class _TableDraft {
  const _TableDraft({
    required this.number,
    required this.capacity,
    required this.type,
  });
  final String number;
  final int capacity;
  final String type;
}

String _tableError(PostgrestException error) {
  const safe = {
    'Table management requires owner or manager access',
    'Table not found or archived',
    'Table not found or already archived',
  };
  if (safe.contains(error.message)) return error.message;
  if (error.code == '23505') return 'That table number or name already exists.';
  if (error.code == '23514') return 'Check the table number and capacity.';
  return 'Could not update the table. Please try again.';
}
