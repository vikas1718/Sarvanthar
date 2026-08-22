part of '../../main.dart';

class MenuManagementPage extends StatefulWidget {
  const MenuManagementPage({
    super.key,
    required this.businessId,
    required this.stallId,
    required this.isFoodCourt,
    required this.role,
  });
  final String businessId, role;
  final String? stallId;
  final bool isFoodCourt;
  @override
  State<MenuManagementPage> createState() => _MenuManagementPageState();
}

class _MenuManagementPageState extends State<MenuManagementPage> {
  List<MenuCategory> cats = const [];
  List<MenuItem> items = const [];
  List<Stall> stalls = const [];
  String? scope;
  bool loading = true;
  String? error;
  bool get edit => widget.role == 'owner' || widget.role == 'manager';
  bool get toggle => edit || widget.role == 'kitchen';
  MenuService get service => MenuService(Supabase.instance.client);
  @override
  void initState() {
    super.initState();
    scope = widget.stallId;
    setup();
  }

  Future<void> setup() async {
    if (widget.isFoodCourt && scope == null) {
      stalls = await StallService(Supabase.instance.client)
          .loadForBusiness(widget.businessId);
      scope = stalls.where((s) => s.isActive).firstOrNull?.id;
    }
    await load();
  }

  Future<void> load() async {
    if (widget.isFoodCourt && scope == null) {
      setState(() => loading = false);
      return;
    }
    setState(() => loading = true);
    try {
      final v = await Future.wait([
        service.categories(widget.businessId, scope),
        service.items(widget.businessId, scope),
      ]);
      if (mounted) {
        setState(() {
          cats = v[0] as List<MenuCategory>;
          items = v[1] as List<MenuItem>;
          loading = false;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'Menu data is unavailable until the approved migration is applied.';
        });
      }
    }
  }

  Future<String?> textDialog(String title, [String initial = '']) async {
    final c = TextEditingController(text: initial);
    final r = await showDialog<String>(
      context: context,
      builder: (x) => AlertDialog(
        title: Text(title),
        content: TextField(controller: c, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(x),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(x, c.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    c.dispose();
    return r;
  }

  Future<void> addCategory() async {
    final n = await textDialog('Category name');
    if (n == null || n.isEmpty) return;
    await service.createCategory(widget.businessId, scope, n);
    await load();
  }

  Future<void> itemDialog([MenuItem? item]) async {
    if (cats.isEmpty) {
      _notice(context, 'Create a category first.');
      return;
    }
    final name = TextEditingController(text: item?.name),
        desc = TextEditingController(text: item?.description),
        price = TextEditingController(text: item?.price.toString());
    String category = item?.categoryId ?? cats.first.id;
    XFile? image;
    final ok = await showDialog<bool>(
      context: context,
      builder: (x) => StatefulBuilder(
        builder: (x, set) => AlertDialog(
          title: Text(item == null ? 'Add menu item' : 'Edit menu item'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: desc,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: price,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Price'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  items: cats
                      .map(
                        (c) =>
                            DropdownMenuItem(value: c.id, child: Text(c.name)),
                      )
                      .toList(),
                  onChanged: (v) => category = v!,
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    image = await ImagePicker().pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 1600,
                      imageQuality: 85,
                    );
                    set(() {});
                  },
                  icon: const Icon(Icons.image_outlined),
                  label: Text(image?.name ?? 'Choose image'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(x, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(x, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok == true &&
        name.text.trim().isNotEmpty &&
        double.tryParse(price.text) != null) {
      String? path = item?.imagePath;
      if (image != null) {
        final bytes = await image!.readAsBytes();
        path = await service.upload(
          widget.businessId,
          scope,
          image!.name.split('.').last.toLowerCase(),
          bytes,
        );
      }
      await service.saveItem(
        item: item,
        b: widget.businessId,
        s: scope,
        category: category,
        name: name.text.trim(),
        description: desc.text.trim(),
        price: double.parse(price.text),
        image: path,
      );
      await load();
    }
    name.dispose();
    desc.dispose();
    price.dispose();
  }

  Future<void> options(MenuItem item) async {
    var groups = await service.groups(item.id);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (x) => StatefulBuilder(
        builder: (x, set) => AlertDialog(
          title: Text('${item.name} options'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...groups.map(
                  (g) => ListTile(
                    title: Text(g.name),
                    subtitle: Text(g.type),
                    onTap: () async {
                      final n = await textDialog('Option name');
                      if (n != null && n.isNotEmpty) {
                        await service.createOption(g.id, n, 0);
                        if (!mounted) return;
                        _notice(context, 'Option added.');
                      }
                    },
                    trailing: IconButton(
                      onPressed: () async {
                        await service.archiveGroup(g.id);
                        groups = await service.groups(item.id);
                        set(() {});
                      },
                      icon: const Icon(Icons.archive_outlined),
                    ),
                  ),
                ),
                OutlinedButton(
                  onPressed: () async {
                    final n = await textDialog('Group name');
                    if (n != null && n.isNotEmpty) {
                      await service.createGroup(item.id, n, 'add_on');
                      groups = await service.groups(item.id);
                      set(() {});
                    }
                  },
                  child: const Text('Add variant/add-on group'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(x),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext c) => _PageShell(
    title: 'Menu',
    subtitle: widget.isFoodCourt
        ? 'Menu for the selected stall.'
        : 'Restaurant menu.',
    action: edit
        ? FilledButton.icon(
            onPressed: () => itemDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Add item'),
          )
        : null,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.isFoodCourt && widget.stallId == null)
          DropdownButtonFormField<String>(
            initialValue: scope,
            decoration: const InputDecoration(labelText: 'Food court stall'),
            items: stalls
                .where((s) => s.isActive)
                .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                .toList(),
            onChanged: (v) {
              scope = v;
              load();
            },
          ),
        if (widget.isFoodCourt && widget.stallId == null)
          const SizedBox(height: 18),
        if (edit)
          Wrap(
            spacing: 8,
            children: [
              ...cats.map(
                (x) => InputChip(
                  label: Text(x.name),
                  onPressed: () async {
                    final n = await textDialog('Edit category', x.name);
                    if (n != null && n.isNotEmpty) {
                      await service.editCategory(x, n, x.sortOrder);
                      await load();
                    }
                  },
                  onDeleted: () async {
                    await service.archiveCategory(x.id);
                    await load();
                  },
                ),
              ),
              ActionChip(
                avatar: const Icon(Icons.add, size: 16),
                label: const Text('Category'),
                onPressed: addCategory,
              ),
            ],
          ),
        const SizedBox(height: 16),
        if (loading)
          const Center(child: CircularProgressIndicator())
        else if (error != null)
          _Panel(child: Text(error!))
        else if (items.isEmpty)
          _Panel(child: const Text('No menu items yet.'))
        else
          ...items.map(
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _Panel(
                child: ListTile(
                  title: Text(i.name),
                  subtitle: Text(
                    '₹${i.price.toStringAsFixed(2)}\n${i.description ?? ''}',
                  ),
                  isThreeLine: true,
                  leading: i.imagePath == null
                      ? const Icon(Icons.restaurant_menu)
                      : Image.network(
                          Supabase.instance.client.storage
                              .from('menu-images')
                              .getPublicUrl(i.imagePath!),
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                        ),
                  trailing: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Switch(
                        value: i.available,
                        onChanged: toggle
                            ? (v) async {
                                await service.availability(i.id, v);
                                await load();
                              }
                            : null,
                      ),
                      if (edit)
                        PopupMenuButton<String>(
                          onSelected: (v) async {
                            if (v == 'edit') await itemDialog(i);
                            if (v == 'options') await options(i);
                            if (v == 'archive') {
                              await service.archiveItem(i.id);
                              await load();
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(
                              value: 'options',
                              child: Text('Variants & add-ons'),
                            ),
                            PopupMenuItem(
                              value: 'archive',
                              child: Text('Archive'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
