part of '../../main.dart';

class StallManagementPage extends StatefulWidget {
  const StallManagementPage({super.key, required this.businessId});

  final String businessId;

  @override
  State<StallManagementPage> createState() => _StallManagementPageState();
}

class _StallManagementPageState extends State<StallManagementPage> {
  List<Stall> _stalls = const [];
  bool _loading = true;
  String? _error;
  String? _busyStallId;

  StallService get _service => StallService(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant StallManagementPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.businessId != widget.businessId) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stalls = await _service.loadForBusiness(widget.businessId);
      if (!mounted) return;
      setState(() {
        _stalls = stalls;
        _loading = false;
      });
    } on PostgrestException catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = _stallError(error);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Connection problem. Please try again.';
        });
      }
    }
  }

  Future<void> _openForm([Stall? stall]) async {
    final result = await showDialog<_StallDraft>(
      context: context,
      builder: (context) => _StallFormDialog(stall: stall),
    );
    if (result == null || !mounted) return;
    setState(() => _busyStallId = stall?.id ?? 'creating');
    try {
      final saved = stall == null
          ? await _service.create(
              businessId: widget.businessId,
              name: result.name,
              slug: result.slug,
            )
          : await _service.update(
              businessId: widget.businessId,
              stallId: stall.id,
              name: result.name,
              slug: result.slug,
            );
      if (!mounted) return;
      setState(() {
        if (stall == null) {
          _stalls = [..._stalls, saved];
        } else {
          _stalls = _stalls
              .map((item) => item.id == saved.id ? saved : item)
              .toList();
        }
        _busyStallId = null;
      });
      _notice(context, stall == null ? 'Stall created.' : 'Stall updated.');
    } on PostgrestException catch (error) {
      if (mounted) {
        setState(() => _busyStallId = null);
        _notice(context, _stallError(error));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _busyStallId = null);
        _notice(context, 'Connection problem. Please try again.');
      }
    }
  }

  Future<void> _setStatus(Stall stall, bool active) async {
    if (_busyStallId != null) return;
    setState(() => _busyStallId = stall.id);
    try {
      final updated = await _service.setStatus(
        businessId: widget.businessId,
        stallId: stall.id,
        active: active,
      );
      if (!mounted) return;
      setState(() {
        _stalls = _stalls
            .map((item) => item.id == updated.id ? updated : item)
            .toList();
        _busyStallId = null;
      });
      _notice(context, active ? 'Stall activated.' : 'Stall deactivated.');
    } on PostgrestException catch (error) {
      if (mounted) {
        setState(() => _busyStallId = null);
        _notice(context, _stallError(error));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _busyStallId = null);
        _notice(context, 'Connection problem. Please try again.');
      }
    }
  }

  Future<void> _archive(Stall stall) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive stall?'),
        content: Text(
          'Archiving ${stall.name} hides it from this list and disables '
          'staff access and pending invitations assigned to this stall. '
          'This cannot currently be undone in the app.',
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
    if (confirmed != true || !mounted || _busyStallId != null) return;
    setState(() => _busyStallId = stall.id);
    try {
      await _service.archive(businessId: widget.businessId, stallId: stall.id);
      if (!mounted) return;
      setState(() {
        _stalls = _stalls.where((item) => item.id != stall.id).toList();
        _busyStallId = null;
      });
      _notice(context, 'Stall archived and staff access disabled.');
    } on PostgrestException catch (error) {
      if (mounted) {
        setState(() => _busyStallId = null);
        _notice(context, _stallError(error));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _busyStallId = null);
        _notice(context, 'Connection problem. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => _PageShell(
    title: 'Stalls',
    subtitle: 'Manage the food concepts operating in this food court.',
    action: FilledButton.icon(
      onPressed: _busyStallId == null ? () => _openForm() : null,
      icon: const Icon(Icons.add_rounded),
      label: const Text('Add stall'),
      style: _primaryStyle(),
    ),
    child: _body(),
  );

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _Panel(
        child: Column(
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Try again')),
          ],
        ),
      );
    }
    if (_stalls.isEmpty) {
      return _Panel(
        child: Column(
          children: [
            const Icon(Icons.storefront_outlined, size: 42, color: _amber),
            const SizedBox(height: 10),
            const Text(
              'No stalls yet',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
            const SizedBox(height: 5),
            const Text('Create the first stall for this food court.'),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => _openForm(),
              child: const Text('Add stall'),
            ),
          ],
        ),
      );
    }
    return Column(
      children: _stalls
          .map(
            (stall) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ManagedStallRow(
                stall: stall,
                busy: _busyStallId == stall.id,
                disabled: _busyStallId != null,
                onEdit: () => _openForm(stall),
                onStatus: (active) => _setStatus(stall, active),
                onArchive: () => _archive(stall),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ManagedStallRow extends StatelessWidget {
  const _ManagedStallRow({
    required this.stall,
    required this.busy,
    required this.disabled,
    required this.onEdit,
    required this.onStatus,
    required this.onArchive,
  });

  final Stall stall;
  final bool busy;
  final bool disabled;
  final VoidCallback onEdit;
  final ValueChanged<bool> onStatus;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) => _Panel(
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xfffff1df),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(Icons.restaurant_menu_rounded, color: _amber),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stall.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              if (stall.slug != null)
                Text(stall.slug!, style: const TextStyle(color: _muted)),
            ],
          ),
        ),
        if (busy)
          const Padding(
            padding: EdgeInsets.all(12),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else ...[
          _Status(stall.isActive ? 'Active' : 'Inactive'),
          Switch(value: stall.isActive, onChanged: disabled ? null : onStatus),
          PopupMenuButton<String>(
            enabled: !disabled,
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'archive') onArchive();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'archive', child: Text('Archive')),
            ],
          ),
        ],
      ],
    ),
  );
}

class _StallFormDialog extends StatefulWidget {
  const _StallFormDialog({this.stall});

  final Stall? stall;

  @override
  State<_StallFormDialog> createState() => _StallFormDialogState();
}

class _StallFormDialogState extends State<_StallFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _slugController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.stall?.name);
    _slugController = TextEditingController(text: widget.stall?.slug);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.stall == null ? 'Add stall' : 'Edit stall'),
    content: Form(
      key: _formKey,
      child: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _FormLabel('Stall name'),
            const SizedBox(height: 7),
            TextFormField(
              controller: _nameController,
              autofocus: true,
              validator: (value) => (value?.trim().isEmpty ?? true)
                  ? 'Stall name is required.'
                  : null,
            ),
            const SizedBox(height: 16),
            const _FormLabel('Slug'),
            const SizedBox(height: 7),
            TextFormField(
              controller: _slugController,
              decoration: const InputDecoration(hintText: 'Optional'),
              validator: (value) {
                final slug = value?.trim() ?? '';
                if (slug.isEmpty) return null;
                return RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(slug)
                    ? null
                    : 'Use lowercase letters, numbers and hyphens.';
              },
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
          if (!(_formKey.currentState?.validate() ?? false)) return;
          final slug = _slugController.text.trim();
          Navigator.pop(
            context,
            _StallDraft(
              name: _nameController.text.trim(),
              slug: slug.isEmpty ? null : slug,
            ),
          );
        },
        child: Text(widget.stall == null ? 'Create' : 'Save'),
      ),
    ],
  );
}

class _StallDraft {
  const _StallDraft({required this.name, required this.slug});

  final String name;
  final String? slug;
}

String _stallError(PostgrestException error) {
  const safeMessages = {
    'Only the business owner can manage stalls',
    'Stall name is required',
    'Stall status must be active or inactive',
    'Stall not found or archived',
    'Stall not found or already archived',
    'Stalls can exist only under food court businesses',
  };
  return safeMessages.contains(error.message)
      ? error.message
      : 'We could not update the stall. Check for a duplicate name or slug.';
}
