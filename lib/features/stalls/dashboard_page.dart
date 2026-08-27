part of '../../main.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.section,
    required this.staffRole,
    required this.access,
    required this.isFoodCourt,
    required this.businessName,
    required this.businessId,
    required this.currentRole,
    required this.selectedStallId,
    required this.stallName,
    required this.userName,
    required this.stallAccess,
    required this.onSection,
    required this.onAddStaff,
    required this.onStaff,
    required this.onSelectStall,
    required this.onLogout,
  });
  final String section, access, businessName, businessId;
  final String currentRole;
  final String? selectedStallId;
  final String? stallName, userName;
  final bool isFoodCourt;
  final List<BusinessAccess> stallAccess;
  final bool staffRole;
  final ValueChanged<String> onSection;
  final VoidCallback onAddStaff, onStaff, onLogout;
  final ValueChanged<BusinessAccess> onSelectStall;
  static const items = [
    ('Overview', Icons.grid_view_rounded),
    ('Business Profile', Icons.business_outlined),
    ('Stalls', Icons.storefront_outlined),
    ('Staff', Icons.groups_2_outlined),
    ('Menu', Icons.menu_book_outlined),
    ('Tables', Icons.table_restaurant_outlined),
    ('QR Codes', Icons.qr_code_2_rounded),
    ('Orders', Icons.receipt_long_outlined),
    ('Payments', Icons.payments_outlined),
    ('Reports', Icons.insights_outlined),
    ('Settings', Icons.settings_outlined),
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
            child: _DashboardContent(
              section: section,
              staffRole: staffRole,
              isFoodCourt: isFoodCourt,
              businessId: businessId,
              businessName: businessName,
              currentRole: currentRole,
              selectedStallId: selectedStallId,
              onSection: onSection,
              onAddStaff: onAddStaff,
              onStaff: onStaff,
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.active,
    required this.staffRole,
    required this.access,
    required this.isFoodCourt,
    required this.businessName,
    required this.stallName,
    required this.userName,
    required this.stallAccess,
    required this.onSection,
    required this.onSelectStall,
    required this.onLogout,
  });
  final String active, access, businessName;
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
        const Padding(
          padding: EdgeInsets.only(left: 10),
          child: Brand(light: true),
        ),
        const SizedBox(height: 43),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11),
          child: Text(
            businessName.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              color: Color(0xff9aa5b8),
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
        ),
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
                            child: Text(
                              '${item.stallName} · ${item.role}',
                            ),
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
        ...DashboardPage.items
            .where(
              (item) =>
                  (item.$1 != 'Stalls' || (isFoodCourt && !staffRole)) &&
                  (!staffRole ||
                      (item.$1 != 'Business Profile' && item.$1 != 'Staff')) &&
                  (item.$1 != 'Menu' ||
                      [
                        'owner',
                        'manager',
                        'kitchen',
                      ].contains(access.split(' ').first.toLowerCase())) &&
                  (item.$1 != 'Tables' ||
                      [
                        'owner',
                        'manager',
                      ].contains(access.split(' ').first.toLowerCase())) &&
                  (item.$1 != 'QR Codes' ||
                      [
                        'owner',
                        'manager',
                      ].contains(access.split(' ').first.toLowerCase())) &&
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
                    if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) {
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
            ),
        const Spacer(),
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

class _SideItem extends StatelessWidget {
  const _SideItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext c) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
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
              color: selected
                  ? const Color(0xffffc36e)
                  : const Color(0xffb8c1cf),
            ),
            const SizedBox(width: 13),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xffc1c9d5),
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
  });
  final String section;
  final bool staffRole;
  final bool isFoodCourt;
  final String businessId;
  final String businessName;
  final String currentRole;
  final String? selectedStallId;
  final ValueChanged<String> onSection;
  final VoidCallback onAddStaff, onStaff;
  @override
  Widget build(BuildContext context) {
    if (section == 'Overview') {
      return _Overview(staffRole: staffRole, onSection: onSection);
    }
    if (section == 'Business Profile' && !staffRole) {
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
      return KitchenPage(
        businessId: businessId,
        stallId: selectedStallId,
        role: currentRole,
      );
    }
    return _Restricted(title: section, staffRole: staffRole);
  }
}

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
  const _Overview({required this.staffRole, required this.onSection});
  final bool staffRole;
  final ValueChanged<String> onSection;
  @override
  Widget build(BuildContext c) => _PageShell(
    title: staffRole ? 'Good afternoon, Aarav.' : 'A clear view of service.',
    subtitle: staffRole
        ? 'Kitchen access • Chaat & Co. and South Bowl'
        : 'Sunday, 16 August  •  The Courtyard Food Hall',
    action: OutlinedButton.icon(
      onPressed: () =>
          _notice(c, "Showing today's service snapshot."),
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
