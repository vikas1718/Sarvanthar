part of '../../main.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.section,
    required this.staffRole,
    required this.access,
    required this.isFoodCourt,
    required this.businessName,
    required this.businessLogoUrl,
    required this.businessId,
    required this.currentRole,
    required this.selectedStallId,
    required this.stallName,
    required this.userName,
    required this.userEmail,
    required this.stallAccess,
    required this.onSection,
    required this.onAddStaff,
    required this.onStaff,
    required this.onSelectStall,
    required this.onLogout,
  });
  final String section, access, businessName, businessId;
  final String? businessLogoUrl;
  final String currentRole;
  final String? selectedStallId;
  final String? stallName, userName, userEmail;
  final bool isFoodCourt;
  final List<BusinessAccess> stallAccess;
  final bool staffRole;
  final ValueChanged<String> onSection;
  final VoidCallback onAddStaff, onStaff, onLogout;
  final ValueChanged<BusinessAccess> onSelectStall;
  static const items = [
    ('Overview', Icons.grid_view_rounded),
    ('Business Settings', Icons.business_outlined),
    ('Stalls', Icons.storefront_outlined),
    ('Staff', Icons.groups_2_outlined),
    ('Menu', Icons.menu_book_outlined),
    ('Tables', Icons.table_restaurant_outlined),
    ('QR Codes', Icons.qr_code_2_rounded),
    ('Orders', Icons.receipt_long_outlined),
    ('Payments', Icons.payments_outlined),
    ('Reports', Icons.insights_outlined),
    ('Upgrade Plans', Icons.settings_outlined),
    ('Account Settings', Icons.manage_accounts_outlined),
  ];
  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 920;
    final side = _Sidebar(
      active: section,
      staffRole: staffRole,
      access: access,
      isFoodCourt: isFoodCourt,
      businessName: businessName,
      businessLogoUrl: businessLogoUrl,
      stallName: stallName,
      userName: userName,
      stallAccess: stallAccess,
      onSection: onSection,
      onSelectStall: onSelectStall,
      onLogout: onLogout,
    );
    return Scaffold(
      drawer: desktop ? null : Drawer(child: side),
      appBar: desktop
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              title: const Brand(),
              actions: [
                IconButton(
                  onPressed: () => _notice(context, 'No new notifications.'),
                  icon: const Icon(Icons.notifications_none_rounded),
                ),
              ],
            ),
      body: Row(
        children: [
          if (desktop) SizedBox(width: 252, child: side),
          Expanded(
            child: _SubscriptionGate(
              businessId: businessId,
              onUpgrade: () => onSection('Upgrade Plans'),
              allowWhenExpired: section == 'Upgrade Plans',
              child: _DashboardContent(
                section: section,
                staffRole: staffRole,
                isFoodCourt: isFoodCourt,
                businessId: businessId,
                businessName: businessName,
                currentRole: currentRole,
                selectedStallId: selectedStallId,
                userName: userName,
                userEmail: userEmail,
                onSection: onSection,
                onAddStaff: onAddStaff,
                onStaff: onStaff,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionGate extends StatelessWidget {
  const _SubscriptionGate({
    required this.businessId,
    required this.onUpgrade,
    required this.allowWhenExpired,
    required this.child,
  });
  final String businessId;
  final VoidCallback onUpgrade;
  final bool allowWhenExpired;
  final Widget child;
  @override
  Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(
    future: Supabase.instance.client.rpc<List<dynamic>>(
      'business_access_status',
      params: {'p_business_id': businessId},
    ),
    builder: (context, snapshot) {
      if (!snapshot.hasData)
        return const Center(child: CircularProgressIndicator());
      final status = Map<String, dynamic>.from(snapshot.data!.first as Map);
      if (status['is_active'] == true) {
        final plan = status['plan'] as String;
        final expiry = DateTime.parse(
          (plan == 'pro'
                  ? status['subscription_expires_at']
                  : status['trial_expires_at'])
              as String,
        );
        final days = expiry.difference(DateTime.now()).inDays + 1;
        return Column(
          children: [
            Container(
              width: double.infinity,
              color: const Color(0xffffedd5),
              padding: const EdgeInsets.all(10),
              child: Text(
                plan == 'pro'
                    ? 'Pro plan active until ${expiry.toLocal().toString().split(' ').first}'
                    : 'Free trial: $days day${days == 1 ? '' : 's'} remaining • ends ${expiry.toLocal().toString().split(' ').first}',
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(child: child),
          ],
        );
      }
      if (allowWhenExpired) return child;
      return _PageShell(
        title: 'Your free trial has expired',
        subtitle: 'Your restaurant features are locked. Upgrade to Pro to restore full access.',
        child: FilledButton(
          onPressed: onUpgrade,
          style: _primaryStyle(),
          child: const Text('Upgrade to Pro'),
        ),
      );
    },
  );
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.active,
    required this.staffRole,
    required this.access,
    required this.isFoodCourt,
    required this.businessName,
    required this.businessLogoUrl,
    required this.stallName,
    required this.userName,
    required this.stallAccess,
    required this.onSection,
    required this.onSelectStall,
    required this.onLogout,
  });
  final String active, access, businessName;
  final String? businessLogoUrl;
  final String? stallName, userName;
  final bool staffRole;
  final bool isFoodCourt;
  final List<BusinessAccess> stallAccess;
  final ValueChanged<String> onSection;
  final ValueChanged<BusinessAccess> onSelectStall;
  final VoidCallback onLogout;
  @override
  Widget build(BuildContext context) => Container(
    color: _navy,
    padding: const EdgeInsets.fromLTRB(16, 30, 16, 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SidebarBrandLogo(logoUrl: businessLogoUrl),
              SizedBox(width: 10),
              Text(
                businessName,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -.8,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 43),
        if (stallName != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(11, 0, 11, 12),
            child: stallAccess.length > 1
                ? PopupMenuButton<BusinessAccess>(
                    onSelected: onSelectStall,
                    itemBuilder: (context) => stallAccess
                        .map(
                          (item) => PopupMenuItem(
                            value: item,
                            child: Text('${item.stallName} · ${item.role}'),
                          ),
                        )
                        .toList(),
                    child: Row(
                      children: [
                        Text(
                          stallName!,
                          style: const TextStyle(
                            color: Color(0xffffc36e),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Icon(
                          Icons.expand_more_rounded,
                          color: Color(0xffffc36e),
                        ),
                      ],
                    ),
                  )
                : Text(
                    stallName!,
                    style: const TextStyle(
                      color: Color(0xffffc36e),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        const SizedBox(height: 11),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              ...DashboardPage.items
                  .where(
                    (item) =>
                        (item.$1 != 'Stalls' || (isFoodCourt && !staffRole)) &&
                        (!staffRole ||
                            (item.$1 != 'Business Settings' &&
                                item.$1 != 'Staff')) &&
                        (item.$1 != 'Menu' ||
                            ['owner', 'manager', 'kitchen'].contains(
                              access.split(' ').first.toLowerCase(),
                            )) &&
                        (item.$1 != 'Tables' ||
                            ['owner', 'manager'].contains(
                              access.split(' ').first.toLowerCase(),
                            )) &&
                        (item.$1 != 'QR Codes' ||
                            ['owner', 'manager'].contains(
                              access.split(' ').first.toLowerCase(),
                            )) &&
                        (item.$1 != 'Orders' ||
                            [
                              'owner',
                              'manager',
                              'kitchen',
                              'cashier',
                            ].contains(access.split(' ').first.toLowerCase())),
                  )
                  .map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: _SideItem(
                        label: e.$1,
                        icon: e.$2,
                        selected: active == e.$1,
                        onTap: () {
                          onSection(e.$1);
                          if (Scaffold.maybeOf(context)?.isDrawerOpen ??
                              false) {
                            Navigator.pop(context);
                          }
                        },
                      ),
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
                child: Text(
                  'AP',
                  style: TextStyle(
                    color: _navy,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (userName?.trim().isNotEmpty ?? false)
                          ? userName!.trim()
                          : 'Your account',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      access,
                      style: const TextStyle(
                        color: Color(0xffb8c1cf),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onLogout,
                tooltip: 'Log out',
                icon: const Icon(
                  Icons.logout_rounded,
                  size: 19,
                  color: Color(0xffffc36e),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SidebarBrandLogo extends StatelessWidget {
  const _SidebarBrandLogo({required this.logoUrl});

  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    final url = logoUrl?.trim();
    if (url == null || url.isEmpty) {
      return _BrandFallbackIcon();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        url,
        width: 34,
        height: 34,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _BrandFallbackIcon(),
      ),
    );
  }
}

class _BrandFallbackIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 34,
    height: 34,
    decoration: BoxDecoration(
      color: _amber,
      borderRadius: BorderRadius.circular(10),
    ),
    child: const Icon(Icons.restaurant_rounded, color: Colors.white, size: 20),
  );
}

class _SideItem extends StatelessWidget {
  const _SideItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.disabled = false,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final bool disabled;
  @override
  Widget build(BuildContext c) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xff35425a) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: disabled
                  ? const Color(0xff718099)
                  : selected
                  ? const Color(0xffffc36e)
                  : const Color(0xffb8c1cf),
            ),
            const SizedBox(width: 13),
            Text(
              label,
              style: TextStyle(
                color: disabled
                    ? const Color(0xff718099)
                    : selected
                    ? Colors.white
                    : const Color(0xffc1c9d5),
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.section,
    required this.staffRole,
    required this.isFoodCourt,
    required this.businessId,
    required this.businessName,
    required this.currentRole,
    required this.selectedStallId,
    required this.onSection,
    required this.onAddStaff,
    required this.onStaff,
    required this.userName,
    required this.userEmail,
  });
  final String section;
  final bool staffRole;
  final bool isFoodCourt;
  final String businessId;
  final String businessName;
  final String? userName;
  final String? userEmail;
  final String currentRole;
  final String? selectedStallId;
  final ValueChanged<String> onSection;
  final VoidCallback onAddStaff, onStaff;
  @override
  Widget build(BuildContext context) {
    if (section == 'Overview') {
      return _Overview(
        staffRole: staffRole,
        onSection: onSection,
        userName: userName,
      );
    }
    if (section == 'Business Settings' && !staffRole) {
      return BusinessProfilePage(businessId: businessId);
    }
    if (section == 'Stalls' && isFoodCourt && !staffRole) {
      return StallManagementPage(businessId: businessId);
    }
    if (section == 'Staff' && !staffRole) {
      return StaffManagementPage(
        businessId: businessId,
        isFoodCourt: isFoodCourt,
      );
    }
    if (section == 'Menu' &&
        ['owner', 'manager', 'kitchen'].contains(currentRole)) {
      return MenuManagementPage(
        businessId: businessId,
        stallId: selectedStallId,
        isFoodCourt: isFoodCourt,
        role: currentRole,
      );
    }
    if (section == 'Tables' && ['owner', 'manager'].contains(currentRole)) {
      return TableManagementPage(businessId: businessId);
    }
    if (section == 'Upgrade Plans') {
      return _UpgradePlansPage(businessId: businessId);
    }
    if (section == 'Account Settings') {
      return _AccountSettingsPage(userName: userName, userEmail: userEmail);
    }
    if (section == 'QR Codes' && ['owner', 'manager'].contains(currentRole)) {
      return QrManagementPage(
        businessId: businessId,
        businessName: businessName,
        isFoodCourt: isFoodCourt,
        role: currentRole,
        stallId: selectedStallId,
      );
    }
    if (section == 'Orders' &&
        ['owner', 'manager', 'kitchen', 'cashier'].contains(currentRole)) {
      return const _NewOrderPage();
    }
    return _Restricted(title: section, staffRole: staffRole);
  }
}

class _UpgradePlansPage extends StatefulWidget {
  const _UpgradePlansPage({required this.businessId});

  final String businessId;

  // Keep pricing in one place until subscription billing is implemented.
  static const _basicMonthlyPrice = '₹200';

  @override
  State<_UpgradePlansPage> createState() => _UpgradePlansPageState();
}

class _UpgradePlansPageState extends State<_UpgradePlansPage> {
  bool _isCreatingSubscription = false;
  late final RazorpayCheckout _checkout;

  @override
  void initState() {
    super.initState();
    _checkout = createRazorpayCheckout(
      onSuccess: _handlePaymentSuccess,
      onError: _handlePaymentError,
      onExternalWallet: _handleExternalWallet,
      onDismiss: _handleCheckoutDismissed,
    );
  }

  @override
  void dispose() {
    _checkout.dispose();
    super.dispose();
  }

  void _handlePaymentSuccess(String? paymentId) {
    debugPrint('Razorpay Checkout success: $paymentId');
    _notice(
      context,
      'Test payment completed. Subscription confirmation is pending.',
    );
  }

  void _handlePaymentError(String? message) {
    debugPrint('Razorpay Checkout failed: $message');
    _notice(context, 'Checkout was closed or the test payment failed.');
  }

  void _handleExternalWallet(String? walletName) {
    debugPrint('Razorpay external wallet selected: $walletName');
    _notice(
      context,
      'External wallet selected: ${walletName ?? 'unknown'}.',
    );
  }

  void _handleCheckoutDismissed() {
    _notice(context, 'Checkout was closed or the test payment failed.');
  }

  Future<void> _openCheckout({
    required String subscriptionId,
    required String keyId,
  }) {
    return _checkout.open(
      subscriptionId: subscriptionId,
      keyId: keyId,
      email: Supabase.instance.client.auth.currentUser?.email,
      windowsCheckoutPageUrl: AppConfig.razorpayCheckoutPageUrl,
    );
  }

  Future<void> _subscribe() async {
    if (_isCreatingSubscription) return;
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      _notice(context, 'Please sign in again before subscribing.');
      return;
    }
    setState(() => _isCreatingSubscription = true);
    try {
      final result = await Supabase.instance.client.functions.invoke(
        'create-razorpay-subscription',
        body: {'business_id': widget.businessId},
      );
      final data = result.data;
      final subscriptionId = data is Map ? data['subscription_id'] : null;
      if (subscriptionId is! String || subscriptionId.isEmpty) {
        throw StateError(
          'The subscription response did not include subscription_id.',
        );
      }
      final keyId = data is Map ? data['key_id'] : null;
      if (keyId is! String || keyId.isEmpty) {
        throw StateError('The subscription response did not include key_id.');
      }
      debugPrint('Razorpay test subscription created: $subscriptionId');
      await _openCheckout(subscriptionId: subscriptionId, keyId: keyId);
    } on FunctionException catch (error) {
      debugPrint('Razorpay subscription creation failed: $error');
      if (mounted) _notice(context, _subscriptionErrorMessage(error));
    } on StateError catch (error) {
      debugPrint('Razorpay Checkout could not open: $error');
      if (mounted) _notice(context, error.message.toString());
    } catch (error) {
      debugPrint('Razorpay subscription creation failed: $error');
      if (mounted) {
        _notice(context, 'Could not create the subscription. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isCreatingSubscription = false);
    }
  }

  String _subscriptionErrorMessage(FunctionException error) {
    final details = error.details;
    if (details is Map && details['error'] is String) {
      return details['error'] as String;
    }
    if (error.status == 0) {
      return 'Could not reach the subscription service. Check your connection and try again.';
    }
    return 'Could not create the subscription. Please try again.';
  }

  @override
  Widget build(BuildContext context) => _PageShell(
    title: 'Upgrade plan',
    subtitle: 'Choose the plan that fits your business.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _TrialMessage(),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, box) {
            final columns = box.maxWidth >= 920
                ? 4
                : box.maxWidth >= 600
                ? 2
                : 1;
            final cards = [
              _PlanCard(
                name: 'FREE TRIAL',
                description: 'All features included',
                price: '₹0',
                features: const [
                  ('All Basic plan features', true),
                ],
              ),
              _PlanCard(
                name: 'BASIC',
                description: 'For restaurants',
                price: '₹1,499',
                features: const [
                  ('Dashboard and daily sales overview', true),
                  ('Menu and item management', true),
                  ('Order management', true),
                  ('Table management', true),
                  ('QR code menus', true),
                  ('Staff management', true),
                  ('After trial', true),
                ],
                onSubscribe: _subscribe,
              ),
              _PlanCard(
                name: 'ADVANCED',
                description: 'For growing businesses',
                price: '₹4,999',
                features: const [('Placeholder features', true)],
              ),
              const _PlanCard(
                name: 'ENTERPRISE',
                description: 'For large businesses and food courts',
                price: 'Custom pricing',
                features: [],
              ),
            ];
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: cards
                  .map(
                    (card) => SizedBox(
                      width: (box.maxWidth - (16 * (columns - 1))) / columns,
                      child: card,
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    ),
  );
}

class _TrialMessage extends StatelessWidget {
  const _TrialMessage();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xffffedd5),
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Text(
      'Your 7-day free trial includes all features. Subscribe from Day 8 to continue using ServeFlow.',
      style: TextStyle(color: _navy, fontWeight: FontWeight.w700),
    ),
  );
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.name,
    required this.description,
    required this.price,
    required this.features,
    this.onSubscribe,
  });

  final String name;
  final String description;
  final String price;
  final List<(String, bool)> features;
  final VoidCallback? onSubscribe;

  @override
  Widget build(BuildContext context) {
    final isTrial = name == 'FREE TRIAL';
    final isBasic = name == 'BASIC';
    final displayPrice = isTrial
        ? '7 Days Free'
        : isBasic
        ? _UpgradePlansPage._basicMonthlyPrice
        : name == 'ADVANCED'
        ? 'Coming soon'
        : price;

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _navy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(description, style: const TextStyle(color: _muted)),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                displayPrice,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              if (isBasic) ...[
                const SizedBox(width: 6),
                const Padding(
                  padding: EdgeInsets.only(bottom: 5),
                  child: Text('/month', style: TextStyle(color: _muted)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),
          ...features.map(
            (feature) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(
                    feature.$2 ? Icons.check_rounded : Icons.close_rounded,
                    size: 18,
                    color: feature.$2
                        ? const Color(0xff39825c)
                        : const Color(0xffb85b4f),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      feature.$1,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!isTrial) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: isBasic
                    ? onSubscribe
                    : () => _notice(
                        context,
                        'Upgrade actions are UI-only for now.',
                      ),
                style: _primaryStyle(full: true),
                child: Text(name == 'ENTERPRISE' ? 'Contact Us' : 'Subscribe'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AccountSettingsPage extends StatefulWidget {
  const _AccountSettingsPage({required this.userName, required this.userEmail});

  final String? userName;
  final String? userEmail;

  @override
  State<_AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<_AccountSettingsPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _savingProfile = false;
  bool _updatingPassword = false;
  bool _deletingAccount = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.userName?.trim().isNotEmpty == true
          ? widget.userName!.trim()
          : 'Aparna Patel',
    );
    _emailController = TextEditingController(
      text: widget.userEmail?.trim().isNotEmpty == true
          ? widget.userEmail!.trim()
          : 'aparna@example.com',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile(BuildContext context) async {
    final newName = _nameController.text.trim();
    final newEmail = _emailController.text.trim();
    if (newName.isEmpty) {
      _notice(context, 'Full name cannot be empty.');
      return;
    }
    setState(() => _savingProfile = true);
    try {
      final client = Supabase.instance.client;
      final uid = client.auth.currentUser!.id;
      await client.from('profiles').update({'full_name': newName}).eq('id', uid);
      final currentEmail = client.auth.currentUser?.email;
      if (newEmail.isNotEmpty && newEmail != currentEmail) {
        await client.auth.updateUser(UserAttributes(email: newEmail));
        if (context.mounted) {
          _notice(context, 'Profile saved. Check your inbox to confirm the new email.');
        }
      } else if (context.mounted) {
        _notice(context, 'Profile saved.');
      }
    } catch (e) {
      if (context.mounted) _notice(context, 'Could not save profile: $e');
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _updatePassword(BuildContext context) async {
    final current = _currentPasswordController.text;
    final next = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;
    if (current.isEmpty || next.isEmpty || confirm.isEmpty) {
      _notice(context, 'Fill in all three password fields.');
      return;
    }
    if (next != confirm) {
      _notice(context, 'New password and confirmation do not match.');
      return;
    }
    if (next.length < 8) {
      _notice(context, 'New password must be at least 8 characters.');
      return;
    }
    setState(() => _updatingPassword = true);
    try {
      final client = Supabase.instance.client;
      final email = client.auth.currentUser?.email;
      if (email == null) throw Exception('No signed-in user.');
      await client.auth.signInWithPassword(email: email, password: current);
      await client.auth.updateUser(UserAttributes(password: next));
      if (context.mounted) {
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        _notice(context, 'Password updated.');
      }
    } catch (e) {
      if (context.mounted) _notice(context, 'Could not update password: $e');
    } finally {
      if (mounted) setState(() => _updatingPassword = false);
    }
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This permanently removes your access, profile, and sign-in for this user. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xffb85b4f)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _deletingAccount = true);
    try {
      await Supabase.instance.client.rpc('delete_own_account');
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      if (context.mounted) {
        _notice(context, 'Could not delete account: $e');
        setState(() => _deletingAccount = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => _PageShell(
    title: 'Account settings',
    subtitle: 'Update your personal details and security preferences.',
    action: FilledButton.icon(
      onPressed: _savingProfile ? null : () => _saveProfile(context),
      style: _primaryStyle(),
      icon: _savingProfile
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.save_outlined),
      label: Text(_savingProfile ? 'Saving...' : 'Save changes'),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final twoColumn = constraints.maxWidth >= 920;
        final profileCard = _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Personal details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text('Edit how your profile appears across the dashboard.'),
              const SizedBox(height: 20),
              _AccountField(
                label: 'Full name',
                controller: _nameController,
                hintText: 'Enter your full name',
                prefixIcon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: 16),
              _AccountField(
                label: 'Email address',
                controller: _emailController,
                hintText: 'Enter your email address',
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icons.mail_outline_rounded,
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xfffbfaf8),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _line),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: _amber, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Changes on this page are visual only until backend actions are connected.',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

        final securityCard = _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Password',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text('Create a stronger password for your account access.'),
              const SizedBox(height: 20),
              _AccountField(
                label: 'Current password',
                controller: _currentPasswordController,
                hintText: 'Enter current password',
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: true,
              ),
              const SizedBox(height: 16),
              _AccountField(
                label: 'New password',
                controller: _newPasswordController,
                hintText: 'Enter new password',
                prefixIcon: Icons.key_outlined,
                obscureText: true,
              ),
              const SizedBox(height: 16),
              _AccountField(
                label: 'Confirm new password',
                controller: _confirmPasswordController,
                hintText: 'Re-enter new password',
                prefixIcon: Icons.verified_user_outlined,
                obscureText: true,
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _updatingPassword ? null : () => _updatePassword(context),
                  icon: _updatingPassword
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.lock_reset_rounded),
                  label: Text(_updatingPassword ? 'Updating...' : 'Update password'),
                ),
              ),
            ],
          ),
        );

        final deleteCard = _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.delete_outline_rounded, color: Color(0xffb85b4f)),
                  SizedBox(width: 10),
                  Text(
                    'Delete account',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'This section is for permanent account removal. Keep it behind a confirmation flow when backend support is added.',
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xfffff5f3),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xffffd6d0)),
                ),
                child: const Text(
                  'Deleting your account will remove access to your workspace, profile preferences, and future sign-ins for this user.',
                  style: TextStyle(
                    color: Color(0xff8f3d33),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.tonalIcon(
                onPressed: _deletingAccount ? null : () => _deleteAccount(context),
                icon: _deletingAccount
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.warning_amber_rounded),
                label: Text(_deletingAccount ? 'Deleting...' : 'Delete account'),
                style: FilledButton.styleFrom(
                  foregroundColor: const Color(0xff8f3d33),
                  backgroundColor: const Color(0xffffe4df),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        );

        if (twoColumn) {
          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 6, child: profileCard),
                  const SizedBox(width: 18),
                  Expanded(flex: 5, child: securityCard),
                ],
              ),
              const SizedBox(height: 18),
              deleteCard,
            ],
          );
        }

        return Column(
          children: [
            profileCard,
            const SizedBox(height: 18),
            securityCard,
            const SizedBox(height: 18),
            deleteCard,
          ],
        );
      },
    ),
  );
}

class _AccountField extends StatelessWidget {
  const _AccountField({
    required this.label,
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    this.obscureText = false,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: _navy,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: Icon(prefixIcon, size: 20),
        ),
      ),
    ],
  );
}

class _NewOrderPage extends StatefulWidget {
  const _NewOrderPage();

  @override
  State<_NewOrderPage> createState() => _NewOrderPageState();
}

class _NewOrderPageState extends State<_NewOrderPage> {
  String _orderType = 'Dine-in';
  String? _selectedTable = 'Table 1';
  final _categories = const ['Starters', 'Mains', 'Beverages', 'Desserts'];
  late final List<_MockMenuItem> _items = const [
    _MockMenuItem(
      category: 'Starters',
      name: 'Crispy Paneer Bites',
      price: 220,
      options: ['Spicy', 'Mild'],
    ),
    _MockMenuItem(
      category: 'Mains',
      name: 'Veg Thali',
      price: 340,
      options: ['Extra rice', 'No onions'],
    ),
    _MockMenuItem(
      category: 'Beverages',
      name: 'Masala Chai',
      price: 60,
      options: ['Less sugar', 'No sugar'],
    ),
    _MockMenuItem(
      category: 'Desserts',
      name: 'Gulab Jamun',
      price: 90,
      options: ['2 pcs', '4 pcs'],
    ),
  ];
  final Map<String, int> _cart = {};

  double get _subtotal {
    double total = 0;
    for (final entry in _cart.entries) {
      final item = _items.firstWhere((e) => e.name == entry.key);
      total += item.price * entry.value;
    }
    return total;
  }

  double get _tax => _subtotal * 0.05;
  double get _total => _subtotal + _tax;

  @override
  Widget build(BuildContext context) => _PageShell(
    title: 'New Order',
    subtitle: 'Create a manual order for dine-in or takeaway.',
    child: LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 980;
        final menuColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Panel(
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ChoiceChip(
                    label: const Text('Dine-in'),
                    selected: _orderType == 'Dine-in',
                    onSelected: (_) => setState(() {
                      _orderType = 'Dine-in';
                      _selectedTable ??= 'Table 1';
                    }),
                  ),
                  ChoiceChip(
                    label: const Text('Takeaway'),
                    selected: _orderType == 'Takeaway',
                    onSelected: (_) => setState(() {
                      _orderType = 'Takeaway';
                      _selectedTable = null;
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_orderType == 'Dine-in')
              _Panel(
                child: DropdownButtonFormField<String>(
                  value: _selectedTable,
                  decoration: const InputDecoration(
                    labelText: 'Table selector',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Table 1', child: Text('Table 1')),
                    DropdownMenuItem(value: 'Table 2', child: Text('Table 2')),
                    DropdownMenuItem(value: 'Table 3', child: Text('Table 3')),
                  ],
                  onChanged: (value) => setState(() => _selectedTable = value),
                ),
              ),
            const SizedBox(height: 16),
            _Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Menu categories',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categories
                        .map(
                          (category) => FilterChip(
                            label: Text(category),
                            selected: true,
                            onSelected: (_) {},
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ..._categories.map(
              (category) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._items
                          .where((item) => item.category == category)
                          .map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _MenuItemCard(
                                item: item,
                                quantity: _cart[item.name] ?? 0,
                                onAdd: () => setState(
                                  () => _cart[item.name] =
                                      (_cart[item.name] ?? 0) + 1,
                                ),
                                onRemove: () => setState(() {
                                  final next = (_cart[item.name] ?? 0) - 1;
                                  if (next <= 0) {
                                    _cart.remove(item.name);
                                  } else {
                                    _cart[item.name] = next;
                                  }
                                }),
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );

        final cartColumn = _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Selected items',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 12),
              if (_cart.isEmpty)
                const Text('No items selected yet.')
              else
                ..._cart.entries.map((entry) {
                  final item = _items.firstWhere((e) => e.name == entry.key);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Expanded(child: Text(item.name)),
                        Text('${entry.value} x ${_moneyAmount(item.price)}'),
                      ],
                    ),
                  );
                }),
              const Divider(height: 28),
              _SummaryRow(label: 'Subtotal', value: _moneyAmount(_subtotal)),
              const SizedBox(height: 8),
              _SummaryRow(label: 'Tax', value: _moneyAmount(_tax)),
              const SizedBox(height: 8),
              _SummaryRow(
                label: 'Total',
                value: _moneyAmount(_total),
                bold: true,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() {
                        _cart.clear();
                        _orderType = 'Dine-in';
                        _selectedTable = 'Table 1';
                      }),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () =>
                          _notice(context, 'Place Order is UI-only for now.'),
                      style: _primaryStyle(full: true),
                      child: const Text('Place Order'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 6, child: menuColumn),
              const SizedBox(width: 18),
              SizedBox(width: 360, child: cartColumn),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [menuColumn, const SizedBox(height: 18), cartColumn],
        );
      },
    ),
  );
}

class _MenuItemCard extends StatelessWidget {
  const _MenuItemCard({
    required this.item,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
  });

  final _MockMenuItem item;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xfffbfaf8),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _line),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xffffedd5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.restaurant_menu_rounded, color: _amber),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                _moneyAmount(item.price),
                style: const TextStyle(color: _muted),
              ),
              if (item.options.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: item.options
                      .map(
                        (option) => Chip(
                          label: Text(option),
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          children: [
            IconButton(
              onPressed: quantity > 0 ? onRemove : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text(
              '$quantity',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            IconButton(
              onPressed: onAdd,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ],
    ),
  );
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: _navy,
          ),
        ),
      ),
      Text(
        value,
        style: TextStyle(
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          color: _navy,
        ),
      ),
    ],
  );
}

class _MockMenuItem {
  const _MockMenuItem({
    required this.category,
    required this.name,
    required this.price,
    required this.options,
  });

  final String category;
  final String name;
  final double price;
  final List<String> options;
}

String _moneyAmount(double amount) => '₹${amount.toStringAsFixed(0)}';

class _PageShell extends StatelessWidget {
  const _PageShell({
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
  });
  final String title, subtitle;
  final Widget child;
  final Widget? action;
  @override
  Widget build(BuildContext c) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(26, 28, 26, 42),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final titleBlock = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(c).textTheme.headlineMedium
                            ?.copyWith(fontSize: 31),
                      ),
                      const SizedBox(height: 4),
                      Text(subtitle),
                    ],
                  );
                  if (constraints.maxWidth < 600) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        titleBlock,
                        if (action != null) ...[
                          const SizedBox(height: 16),
                          SizedBox(width: double.infinity, child: action!),
                        ],
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: titleBlock),
                      ...?(action == null ? null : [action!]),
                    ],
                  );
                },
              ),
              const SizedBox(height: 28),
              child,
            ],
          ),
        ),
      ),
    ),
  );
}

class _Overview extends StatelessWidget {
  const _Overview({
    required this.staffRole,
    required this.onSection,
    required this.userName,
  });
  final bool staffRole;
  final ValueChanged<String> onSection;
  final String? userName;
  @override
  Widget build(BuildContext c) => _PageShell(
    title: userName?.trim().isNotEmpty == true
        ? 'Welcome back, ${userName!.trim()}.'
        : 'Welcome back.',
    subtitle: staffRole
        ? 'Kitchen access • Chaat & Co. and South Bowl'
        : 'Sunday, 16 August  •  The Courtyard Food Hall',
    action: OutlinedButton.icon(
      onPressed: () => _notice(c, "Showing today's service snapshot."),
      icon: const Icon(Icons.calendar_today_outlined, size: 17),
      label: const Text('Today'),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (_, box) {
            final two = box.maxWidth > 690;
            final cards = [
              _Metric(
                '₹18,460',
                "Today's sales",
                '+12.4%',
                Icons.account_balance_wallet_outlined,
              ),
              _Metric(
                '86',
                'Orders received',
                '18 in progress',
                Icons.receipt_long_outlined,
              ),
              _Metric(
                '4.6 min',
                'Average prep time',
                'On target',
                Icons.timer_outlined,
              ),
            ];
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: cards
                  .map(
                    (x) => SizedBox(
                      width: two ? (box.maxWidth - 28) / 3 : box.maxWidth,
                      child: x,
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 26),
        LayoutBuilder(
          builder: (_, b) => b.maxWidth > 760
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(flex: 6, child: _ServicePulse()),
                    const SizedBox(width: 18),
                    Expanded(
                      flex: 4,
                      child: _ActionPanel(onTap: () => onSection('Stalls')),
                    ),
                  ],
                )
              : Column(
                  children: [
                    const _ServicePulse(),
                    const SizedBox(height: 18),
                    _ActionPanel(onTap: () => onSection('Stalls')),
                  ],
                ),
        ),
        const SizedBox(height: 22),
        _RecentOrders(onTap: () => onSection('Orders')),
      ],
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric(this.value, this.label, this.delta, this.icon);
  final String value, label, delta;
  final IconData icon;
  @override
  Widget build(BuildContext c) => _Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _muted,
                  fontSize: 13,
                ),
              ),
            ),
            Icon(icon, color: _amber),
          ],
        ),
        const SizedBox(height: 17),
        Text(
          value,
          style: Theme.of(c).textTheme.headlineMedium?.copyWith(fontSize: 27),
        ),
        const SizedBox(height: 6),
        Text(
          delta,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xff39825c),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _ServicePulse extends StatelessWidget {
  const _ServicePulse();
  @override
  Widget build(BuildContext c) => _Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Service pulse',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xffeaf7ef),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'LIVE',
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0xff39825c),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 26),
        const Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _Bar(h: 45),
            _Bar(h: 72),
            _Bar(h: 55),
            _Bar(h: 106, hot: true),
            _Bar(h: 84),
            _Bar(h: 126, hot: true),
            _Bar(h: 94),
            _Bar(h: 61),
          ],
        ),
        const SizedBox(height: 14),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text('11 AM'), Text('1 PM'), Text('3 PM'), Text('5 PM')],
        ),
      ],
    ),
  );
}

class _Bar extends StatelessWidget {
  const _Bar({required this.h, this.hot = false});
  final double h;
  final bool hot;
  @override
  Widget build(BuildContext c) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Container(
        height: h,
        decoration: BoxDecoration(
          color: hot ? _amber : const Color(0xffffddb1),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        ),
      ),
    ),
  );
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext c) => _Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Keep the floor moving',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 11),
        const Text(
          'Lunch rush begins in 42 minutes. Check your stall readiness.',
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.storefront_outlined, size: 18),
          label: const Text('Review stalls'),
          style: _primaryStyle(),
        ),
      ],
    ),
  );
}

class _RecentOrders extends StatelessWidget {
  const _RecentOrders({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext c) => _Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Recent orders',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            TextButton(onPressed: onTap, child: const Text('View all')),
          ],
        ),
        const Divider(color: _line),
        ...[
          ('#TC-1048', 'South Bowl', '₹420', 'Preparing'),
          ('#TC-1047', 'Chaat & Co.', '₹265', 'Ready'),
          ('#TC-1046', 'Melt House', '₹510', 'New'),
        ].map(
          (r) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xfffff1df),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.receipt_outlined,
                    color: _amber,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.$1,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _navy,
                        ),
                      ),
                      Text(
                        r.$2,
                        style: const TextStyle(fontSize: 12, color: _muted),
                      ),
                    ],
                  ),
                ),
                Text(
                  r.$3,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _navy,
                  ),
                ),
                const SizedBox(width: 14),
                _Status(r.$4),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _Status extends StatelessWidget {
  const _Status(this.text);
  final String text;
  @override
  Widget build(BuildContext c) {
    final ready = text == 'Ready' || text == 'Active' || text == 'Open';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ready ? const Color(0xffeaf7ef) : const Color(0xfffff1df),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: ready ? const Color(0xff39825c) : const Color(0xffa35809),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext c) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _line),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0a172033),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: child,
  );
}

// TODO: Remove this legacy visual placeholder after the dashboard redesign.
// ignore: unused_element
class _Orders extends StatelessWidget {
  const _Orders();
  @override
  Widget build(BuildContext c) => _PageShell(
    title: 'Orders',
    subtitle: 'Track every order across your floor.',
    child: _Panel(
      child: Column(
        children: [
          const Icon(Icons.receipt_long_outlined, size: 42, color: _amber),
          const SizedBox(height: 10),
          const Text(
            'Order board is ready for service',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          const SizedBox(height: 4),
          const Text(
            'Live order routing will appear here once your QR menus are connected.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 15),
          OutlinedButton(
            onPressed: () => _notice(
              c,
              "We'll let you know when the order board is available.",
            ),
            child: const Text('Coming soon'),
          ),
        ],
      ),
    ),
  );
}

class _Restricted extends StatelessWidget {
  const _Restricted({required this.title, required this.staffRole});
  final String title;
  final bool staffRole;
  @override
  Widget build(BuildContext c) => _PageShell(
    title: title,
    subtitle: 'Workspace tools for The Courtyard Food Hall',
    child: Center(
      child: _Panel(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                staffRole
                    ? Icons.lock_outline_rounded
                    : Icons.rocket_launch_outlined,
                size: 42,
                color: _amber,
              ),
              const SizedBox(height: 14),
              Text(
                staffRole ? 'This area is restricted' : '$title is on its way',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _navy,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                staffRole
                    ? 'Your current role does not include this workspace. Ask the owner if you need more access.'
                    : "We're shaping this part of ServeFlow next. Your current workspace stays exactly as it is.",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 15),
              OutlinedButton(
                onPressed: () => _notice(
                  c,
                  staffRole
                      ? 'Access request recorded for the workspace owner.'
                      : "You'll be notified when this workspace is ready.",
                ),
                child: Text(staffRole ? 'Request access' : 'Notify me'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
