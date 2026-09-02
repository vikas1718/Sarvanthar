part of '../../main.dart';

class CreateBusinessPage extends StatefulWidget {
  const CreateBusinessPage({
    super.key,
    required this.onBack,
    required this.onCreate,
    required this.loading,
    this.error,
  });
  final VoidCallback onBack;
  final void Function(String name, bool isFoodCourt, String phone, String email, String ownerName, String address, String logoUrl) onCreate;
  final bool loading;
  final String? error;
  @override
  State<CreateBusinessPage> createState() => _CreateBusinessPageState();
}

class _CreateBusinessPageState extends State<CreateBusinessPage> {
  bool isFoodCourt = false;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _ownerController = TextEditingController();
  final _addressController = TextEditingController();
  final _logoController = TextEditingController();
  String? _validationError;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose(); _emailController.dispose(); _ownerController.dispose(); _addressController.dispose(); _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AuthShell(
    title: 'Create your restaurant.',
    subtitle: 'Start with a free 7-day trial. No payment is required today.',
    onBack: widget.onBack,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _FormLabel('Business name'),
        const SizedBox(height: 7),
        TextField(
          controller: _nameController,
          decoration: InputDecoration(hintText: 'e.g. The Courtyard Food Hall'),
        ),
        const SizedBox(height: 16),
        const _FormLabel('Owner/admin name'),
        const SizedBox(height: 7),
        TextField(
          controller: _ownerController,
          decoration: const InputDecoration(hintText: 'Your name'),
        ),
        const SizedBox(height: 7),
        const Text(
          'This person will manage the restaurant account.', style: TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 16),
        const _FormLabel('Mobile number'), const SizedBox(height: 7),
        TextField(controller: _phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(hintText: 'Mobile number')),
        const SizedBox(height: 16),
        const _FormLabel('Email (optional)'), const SizedBox(height: 7),
        TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(hintText: 'restaurant@example.com')),
        const SizedBox(height: 16),
        const _FormLabel('Address'), const SizedBox(height: 7),
        TextField(controller: _addressController, maxLines: 2, decoration: const InputDecoration(hintText: 'Restaurant address')),
        const SizedBox(height: 16),
        const _FormLabel('Restaurant logo URL (optional)'), const SizedBox(height: 7),
        TextField(controller: _logoController, keyboardType: TextInputType.url, decoration: const InputDecoration(hintText: 'https://...')),
        const SizedBox(height: 16),
        const _FormLabel('Business type'),
        const SizedBox(height: 7),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
              value: false,
              icon: Icon(Icons.restaurant_rounded),
              label: Text('Restaurant'),
            ),
            ButtonSegment(
              value: true,
              icon: Icon(Icons.storefront_rounded),
              label: Text('Food Court'),
            ),
          ],
          selected: {isFoodCourt},
          onSelectionChanged: (value) =>
              setState(() => isFoodCourt = value.first),
        ),
        const SizedBox(height: 10),
        Text(
          isFoodCourt
              ? 'Food courts can manage stalls and assign staff to stalls.'
              : 'Restaurants manage staff directly. No stalls are required.',
        ),
        const SizedBox(height: 16),
        if (isFoodCourt) const _FormLabel('Number of stalls'),
        if (isFoodCourt) const SizedBox(height: 7),
        if (isFoodCourt)
          DropdownButtonFormField<String>(
            initialValue: '3-5 stalls',
            items: const [
              DropdownMenuItem(
                value: '1-2 stalls',
                child: Text('1-2 stalls'),
              ),
              DropdownMenuItem(
                value: '3-5 stalls',
                child: Text('3-5 stalls'),
              ),
              DropdownMenuItem(value: '6+ stalls', child: Text('6+ stalls')),
            ],
            onChanged: (_) {},
          ),
        const SizedBox(height: 22),
        FilledButton(
          onPressed: widget.loading
              ? null
              : () {
                  final name = _nameController.text.trim();
                  if (name.isEmpty || _ownerController.text.trim().isEmpty || _phoneController.text.trim().isEmpty) {
                    setState(
                      () => _validationError = 'Enter the restaurant name, owner name, and mobile number.',
                    );
                    return;
                  }
                  setState(() => _validationError = null);
                  widget.onCreate(name, isFoodCourt, _phoneController.text.trim(), _emailController.text.trim(), _ownerController.text.trim(), _addressController.text.trim(), _logoController.text.trim());
                },
          style: _primaryStyle(full: true),
          child: Text(
            widget.loading ? 'Creating workspace...' : 'Create my workspace',
          ),
        ),
        if (_validationError != null) ...[
          const SizedBox(height: 12),
          _AuthError(message: _validationError!),
        ],
        if (widget.error != null) ...[
          const SizedBox(height: 12),
          _AuthError(message: widget.error!),
        ],
      ],
    ),
  );
}

class _FormLabel extends StatelessWidget {
  const _FormLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext c) => Text(
    label,
    style: const TextStyle(fontWeight: FontWeight.w700, color: _navy),
  );
}

class NoOrganizationPage extends StatelessWidget {
  const NoOrganizationPage({
    super.key,
    required this.userName,
    required this.onCreateOrganization,
    required this.onLogout,
    this.allowOrganizationCreation = true,
  });

  final String? userName;
  final VoidCallback onCreateOrganization, onLogout;
  final bool allowOrganizationCreation;

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 760;
    final sidebar = Container(
      color: _navy,
      padding: const EdgeInsets.fromLTRB(16, 30, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 10),
            child: Brand(light: true),
          ),
          const SizedBox(height: 48),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                if (allowOrganizationCreation)
                  _SideItem(
                    label: 'Create organization',
                    icon: Icons.add_business_outlined,
                    selected: true,
                    onTap: onCreateOrganization,
                  ),
                const SizedBox(height: 12),
                ...DashboardPage.items.map(
                  (item) => _SideItem(
                    label: item.$1,
                    icon: item.$2,
                    selected: false,
                    disabled: true,
                    onTap: () {},
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xff253147),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(0xffffc36e),
                  child: Icon(Icons.person_outline_rounded, color: _navy, size: 18),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    (userName?.trim().isNotEmpty ?? false) ? userName!.trim() : 'Your account',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: onLogout,
                  icon: const Icon(Icons.logout_rounded, color: Colors.white),
                  tooltip: 'Log out',
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return Scaffold(
      appBar: desktop ? null : AppBar(backgroundColor: Colors.white, title: const Brand()),
      drawer: desktop ? null : Drawer(child: sidebar),
      body: Row(
        children: [
          if (desktop) SizedBox(width: 252, child: sidebar),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: _Panel(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: const Color(0xffffedd5),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.business_outlined, color: _amber),
                        ),
                        const SizedBox(height: 24),
                        Text('Your dashboard is ready', style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 10),
                        Text(allowOrganizationCreation ? 'All dashboard sections are visible in the sidebar. Create an organization to unlock orders, staff, menus, tables, reports, and every other feature.' : 'You have a pending restaurant invitation. Accept it to unlock your assigned role and restaurant access.'),
                        if (allowOrganizationCreation) ...[
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: onCreateOrganization,
                            icon: const Icon(Icons.add_business_outlined),
                            label: const Text('Create organization'),
                            style: _primaryStyle(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SuccessPage extends StatelessWidget {
  const SuccessPage({super.key, required this.onOpen});
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: const BoxDecoration(
                  color: Color(0xffffedd5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, size: 46, color: _amber),
              ),
              const SizedBox(height: 26),
              Text(
                'Your workspace is ready.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              const Text(
                'The Courtyard Food Hall now has a home for every busy service.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: onOpen,
                style: _primaryStyle(),
                child: const Text('Open my dashboard'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class ChoosePlanPage extends StatelessWidget {
  const ChoosePlanPage({super.key, required this.onSelect});

  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) => AuthShell(
    title: 'Choose your plan',
    subtitle: 'Pick how you would like to get started with ServeFlow.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PlanChoice(
          title: '7-Day Free Trial',
          detail: 'All features included',
          action: 'Start Free Trial',
          onPressed: onSelect,
        ),
        const SizedBox(height: 12),
        _PlanChoice(
          title: 'Basic',
          detail: '₹200/month',
          action: 'Choose Basic',
          onPressed: onSelect,
        ),
        const SizedBox(height: 12),
        const _PlanChoice(
          title: 'Advanced',
          detail: 'Coming soon',
          action: 'Coming Soon',
        ),
        const SizedBox(height: 12),
        _PlanChoice(
          title: 'Enterprise',
          detail: 'Custom pricing',
          action: 'Contact Us',
          onPressed: onSelect,
        ),
      ],
    ),
  );
}

class _PlanChoice extends StatelessWidget {
  const _PlanChoice({
    required this.title,
    required this.detail,
    required this.action,
    this.onPressed,
  });

  final String title, detail, action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => _Panel(
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _navy)),
              const SizedBox(height: 4),
              Text(detail, style: const TextStyle(color: _muted)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        FilledButton(
          onPressed: onPressed,
          style: _primaryStyle(),
          child: Text(action),
        ),
      ],
    ),
  );
}

class AdminPortalPage extends StatefulWidget {
  const AdminPortalPage({super.key, required this.onLogout});
  final VoidCallback onLogout;

  @override
  State<AdminPortalPage> createState() => _AdminPortalPageState();
}

class _AdminPortalPageState extends State<AdminPortalPage> {
  bool loading = false;
  List<Map<String, dynamic>> restaurants = const [];
  Map<String, dynamic> overview = const {};
  String search = '', filter = 'All';

  @override
  void initState() { super.initState(); createCode(); }

  Future<void> createCode() async {
    setState(() => loading = true);
    try {
      final values = await Supabase.instance.client
          .rpc<List<dynamic>>('list_platform_restaurants');
      Map<String, dynamic> nextOverview = const {};
      try {
        final rows = await Supabase.instance.client
            .rpc<List<dynamic>>('platform_admin_overview');
        if (rows.isNotEmpty) {
          nextOverview = Map<String, dynamic>.from(rows.first as Map);
        }
      } catch (_) {
        // The existing restaurant list remains available until the optional
        // reporting migration has been applied to this Supabase project.
      }
      if (mounted) {
        setState(() {
          restaurants = values
              .map((row) => Map<String, dynamic>.from(row as Map))
              .toList();
          overview = nextOverview;
        });
      }
    } on PostgrestException catch (e) {
      if (mounted) _notice(context, e.message);
    } catch (_) {
      if (mounted) _notice(context, 'Could not load restaurants.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: _Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Brand(),
                  const SizedBox(height: 42),
                  Text('Platform admin', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 10),
                  Text('${restaurants.length} restaurants registered • ${restaurants.where((r) => r['is_active'] == true).length} active • ${restaurants.where((r) => r['plan'] == 'trial').length} trial • ${restaurants.where((r) => r['plan'] == 'pro').length} Pro • ${restaurants.where((r) => r['is_active'] != true).length} locked'),
                  const SizedBox(height: 22),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ('Total', 'total_restaurants'), ('Active', 'active_restaurants'),
                      ('Trial', 'trial_restaurants'), ('Pro', 'pro_restaurants'),
                      ('Expired', 'expired_restaurants'), ('Locked', 'locked_restaurants'),
                      ('Tables', 'total_tables'), ('QR Codes', 'total_qr_codes'), ('Orders', 'total_orders'),
                    ].map((item) => SizedBox(width: 145, child: _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.$1, style: const TextStyle(fontSize: 12)), const SizedBox(height: 6), Text('${overview[item.$2] ?? 0}', style: Theme.of(context).textTheme.headlineMedium)])))).toList(),
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: loading ? null : createCode,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(loading ? 'Refreshing...' : 'Refresh restaurants'),
                    style: _primaryStyle(),
                  ),
                  if (restaurants.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text('Registered restaurants', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    TextField(
                      onChanged: (value) => setState(() => search = value.toLowerCase()),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search restaurant, owner, phone or email',
                      ),
                    ),
                    DropdownButton<String>(
                      value: filter,
                      items: const ['All', 'trial', 'pro', 'expired']
                          .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                          .toList(),
                      onChanged: (value) => setState(() => filter = value!),
                    ),
                    ...restaurants.where((r) =>
                      (filter == 'All' || r['plan'] == filter) &&
                      '${r['name']} ${r['owner_name']} ${r['phone']} ${r['email']}'.toLowerCase().contains(search)
                    ).map((r) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(r['name'] as String),
                      subtitle: Text('${r['owner_name'] ?? 'Owner'} • ${r['phone'] ?? ''} • ${r['plan']}'),
                      trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () async {
                        await Supabase.instance.client.rpc('delete_platform_restaurant', params: {'p_business_id': r['id']});
                        createCode();
                      }),
                    )),
                  ],
                  const SizedBox(height: 22),
                  TextButton(onPressed: widget.onLogout, child: const Text('Log out')),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
