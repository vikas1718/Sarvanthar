part of '../../main.dart';

class AddStaffPage extends StatelessWidget {
  const AddStaffPage({
    super.key,
    required this.isFoodCourt,
    required this.onBack,
    required this.onSend,
  });
  final bool isFoodCourt;
  final VoidCallback onBack, onSend;
  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(
      backgroundColor: Colors.white,
      leading: IconButton(
        onPressed: onBack,
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: const Text('Invite a teammate'),
    ),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 570),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Eyebrow(label: 'TEAM ACCESS'),
              const SizedBox(height: 12),
              Text(
                'Bring the right people in.',
                style: Theme.of(c).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text("They'll receive a secure invitation by email."),
              const SizedBox(height: 30),
              const _FormLabel('Full name'),
              const SizedBox(height: 7),
              const TextField(
                decoration: InputDecoration(hintText: 'e.g. Neha Kapoor'),
              ),
              const SizedBox(height: 17),
              const _FormLabel('Mobile number'),
              const SizedBox(height: 7),
              const TextField(
                decoration: InputDecoration(
                  prefixText: '+91   ',
                  hintText: '98765 43210',
                ),
              ),
              const SizedBox(height: 17),
              const _FormLabel('Role'),
              const SizedBox(height: 7),
              DropdownButtonFormField<String>(
                initialValue: 'Manager',
                items: const [
                  DropdownMenuItem(value: 'Manager', child: Text('Manager')),
                  DropdownMenuItem(value: 'Cashier', child: Text('Cashier')),
                  DropdownMenuItem(value: 'Kitchen', child: Text('Kitchen')),
                ],
                onChanged: null,
              ),
              if (isFoodCourt) const SizedBox(height: 18),
              if (isFoodCourt)
                const Text(
                  'Assigned stalls',
                  style: TextStyle(fontWeight: FontWeight.w700, color: _navy),
                ),
              if (isFoodCourt) const SizedBox(height: 8),
              if (isFoodCourt)
                const _AccessCheck(label: 'Pizza Stall', checked: true),
              if (isFoodCourt)
                const _AccessCheck(label: 'Burger Stall', checked: true),
              if (isFoodCourt)
                const _AccessCheck(label: 'Juice Stall', checked: false),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: onSend,
                icon: const Icon(Icons.send_rounded),
                label: const Text('Send invitation'),
                style: _primaryStyle(full: true),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _AccessCheck extends StatefulWidget {
  const _AccessCheck({required this.label, required this.checked});
  final String label;
  final bool checked;
  @override
  State<_AccessCheck> createState() => _AccessCheckState();
}

class _AccessCheckState extends State<_AccessCheck> {
  late bool checked = widget.checked;
  @override
  Widget build(BuildContext c) => Material(
    type: MaterialType.transparency,
    child: CheckboxListTile(
      value: checked,
      onChanged: (v) => setState(() => checked = v ?? false),
      title: Text(
        widget.label,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
    ),
  );
}

class StaffDetailsPage extends StatelessWidget {
  const StaffDetailsPage({
    super.key,
    required this.isFoodCourt,
    required this.onBack,
  });
  final bool isFoodCourt;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(
      backgroundColor: Colors.white,
      leading: IconButton(
        onPressed: onBack,
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: const Text('Team member'),
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(26),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Panel(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final avatar = const CircleAvatar(
                      radius: 31,
                      backgroundColor: Color(0xffffe4c1),
                      child: Text(
                        'AR',
                        style: TextStyle(
                          color: _navy,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                    );
                    final identity = const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rahul',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 21,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'rahul@example.com',
                          style: TextStyle(color: _muted),
                        ),
                        SizedBox(height: 6),
                        _Status('Active'),
                      ],
                    );
                    final edit = OutlinedButton.icon(
                      onPressed: () =>
                          _notice(c, 'Editing staff details is coming soon'),
                      icon: const Icon(Icons.edit_outlined, size: 17),
                      label: const Text('Edit'),
                    );
                    if (constraints.maxWidth < 430) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              avatar,
                              const SizedBox(width: 16),
                              Expanded(child: identity),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(width: double.infinity, child: edit),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        const CircleAvatar(
                          radius: 31,
                          backgroundColor: Color(0xffffe4c1),
                          child: Text(
                            'AR',
                            style: TextStyle(
                              color: _navy,
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Rahul',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 21,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'rahul@example.com',
                                style: TextStyle(color: _muted),
                              ),
                              SizedBox(height: 6),
                              _Status('Active'),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _notice(
                            c,
                            'Editing staff details is coming soon',
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 17),
                          label: const Text('Edit'),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 22),
              Text('Roles & access', style: Theme.of(c).textTheme.titleLarge),
              const SizedBox(height: 5),
              Text(
                isFoodCourt
                    ? 'Rahul can switch only between the assigned stalls below.'
                    : 'Rahul is assigned to ABC Restaurant as Manager.',
              ),
              const SizedBox(height: 14),
              if (isFoodCourt)
                const _RoleAccess(
                  stall: 'Pizza Stall',
                  role: 'Manager',
                  details: 'Orders, preparation board, menu availability',
                ),
              if (isFoodCourt) const SizedBox(height: 11),
              if (isFoodCourt)
                const _RoleAccess(
                  stall: 'Burger Stall',
                  role: 'Staff',
                  details: 'Orders, preparation board, menu availability',
                ),
              if (!isFoodCourt)
                const _RoleAccess(
                  stall: 'ABC Restaurant',
                  role: 'Manager',
                  details: 'Restaurant operations, menu and orders',
                ),
              if (isFoodCourt)
                const Padding(
                  padding: EdgeInsets.only(top: 14),
                  child: Text(
                    'Juice Stall is not assigned to Rahul and will not appear in his stall selector.',
                    style: TextStyle(color: _muted),
                  ),
                ),
              const SizedBox(height: 22),
              Text('Recent activity', style: Theme.of(c).textTheme.titleLarge),
              const SizedBox(height: 12),
              _Panel(
                child: const Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.login_rounded, color: _amber),
                      title: Text('Signed in to South Bowl'),
                      subtitle: Text('Today, 12:42 PM'),
                    ),
                    Divider(color: _line),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.check_circle_outline_rounded,
                        color: _amber,
                      ),
                      title: Text('Marked order #TC-1048 as preparing'),
                      subtitle: Text('Today, 12:38 PM'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _RoleAccess extends StatelessWidget {
  const _RoleAccess({
    required this.stall,
    required this.role,
    required this.details,
  });
  final String stall, role, details;
  @override
  Widget build(BuildContext c) => _Panel(
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xfffff1df),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.storefront_outlined, color: _amber),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(stall, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(
                role,
                style: const TextStyle(
                  color: _navy,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                details,
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => _notice(c, '$stall options are coming soon'),
          icon: const Icon(Icons.more_horiz_rounded),
        ),
      ],
    ),
  );
}
