part of '../../main.dart';

class StaffManagementPage extends StatefulWidget {
  const StaffManagementPage({
    super.key,
    required this.businessId,
    required this.isFoodCourt,
  });
  final String businessId;
  final bool isFoodCourt;
  @override
  State<StaffManagementPage> createState() => _StaffManagementPageState();
}

class _StaffManagementPageState extends State<StaffManagementPage> {
  List<StaffMember> members = const [];
  List<PendingInvitation> invitations = const [];
  List<Stall> stalls = const [];
  bool loading = true, busy = false;
  String? error;
  StaffService get service => StaffService(Supabase.instance.client);
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final values = await Future.wait([
        service.loadStaff(widget.businessId),
        service.loadInvitations(widget.businessId),
        if (widget.isFoodCourt)
          StallService(Supabase.instance.client)
              .loadForBusiness(widget.businessId),
      ]);
      if (!mounted) return;
      setState(() {
        members = values[0] as List<StaffMember>;
        invitations = values[1] as List<PendingInvitation>;
        stalls = widget.isFoodCourt ? values[2] as List<Stall> : const [];
        loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'We could not load your team. Please try again.';
        });
      }
    }
  }

  Future<void> invite() async {
    final draft = await showDialog<_InviteDraft>(
      context: context,
      builder: (_) =>
          _InviteDialog(isFoodCourt: widget.isFoodCourt, stalls: stalls),
    );
    if (draft == null || !mounted) return;
    setState(() => busy = true);
    try {
      final created = await service.invite(
        businessId: widget.businessId,
        stallId: draft.stallId,
        role: draft.role,
        email: draft.email,
        phone: draft.phone,
      );
      if (!mounted) return;
      setState(() => busy = false);
      var message = draft.email != null
          ? 'The invitation is ready for ${draft.email}. Ask them to choose “I’m joining a team”, enter their email, password, and your business code, then verify the six-digit email code.'
          : 'The invitation is ready. Staff must join with their email, password, business code, and a six-digit email code.';
      if (draft.email != null) {
        message = 'The invitation is ready for ${draft.email}. Ask them to sign up or log in with that email. They will see an invitation notification and can accept or reject it.';
      }
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Invitation created'),
          content: Text(message),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      await load();
    } on PostgrestException catch (e) {
      if (mounted) {
        setState(() => busy = false);
        _notice(context, e.message);
      }
    }
  }

  Future<void> revoke(PendingInvitation i) async {
    setState(() => busy = true);
    try {
      await service.revoke(widget.businessId, i.id);
      await load();
    } catch (_) {
      if (mounted) {
        setState(() => busy = false);
        _notice(context, 'Could not revoke invitation.');
      }
    }
  }

  Future<void> disable(StaffMember m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Disable staff access?'),
        content: Text(
          'This removes ${m.name} access to ${m.stallName ?? 'this business'}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Disable'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => busy = true);
    try {
      await service.disable(widget.businessId, m);
      await load();
    } catch (_) {
      if (mounted) {
        setState(() => busy = false);
        _notice(context, 'Could not disable staff access.');
      }
    }
  }

  @override
  Widget build(BuildContext c) => _PageShell(
    title: 'Staff',
    subtitle: 'Manage active teammates and pending invitations.',
    action: FilledButton.icon(
      onPressed: busy ? null : invite,
      icon: const Icon(Icons.person_add_alt_1_rounded),
      label: const Text('Invite staff'),
      style: _primaryStyle(),
    ),
    child: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
        ? _Panel(
            child: Column(
              children: [
                Text(error!),
                OutlinedButton(onPressed: load, child: const Text('Try again')),
              ],
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Active staff', style: Theme.of(c).textTheme.titleLarge),
              const SizedBox(height: 10),
              if (members.where((m) => m.status == 'active').isEmpty)
                _Panel(child: const Text('No active staff yet.')),
              ...members
                  .where((m) => m.status == 'active')
                  .map(
                    (m) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _Panel(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(m.name),
                          subtitle: Text(
                            '${m.role} · ${m.stallName ?? 'Business-wide'}\n${m.email ?? m.phone ?? ''}',
                          ),
                          trailing: TextButton(
                            onPressed: busy ? null : () => disable(m),
                            child: const Text('Disable'),
                          ),
                        ),
                      ),
                    ),
                  ),
              const SizedBox(height: 22),
              Text(
                'Pending invitations',
                style: Theme.of(c).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              if (invitations.isEmpty)
                _Panel(child: const Text('No pending invitations.')),
              ...invitations.map(
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _Panel(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(i.email ?? i.phone ?? 'Invitation'),
                      subtitle: Text(
                        '${i.role} · ${i.stallName ?? 'Business-wide'}',
                      ),
                      trailing: TextButton(
                        onPressed: busy ? null : () => revoke(i),
                        child: const Text('Revoke'),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
  );
}

class _InviteDialog extends StatefulWidget {
  const _InviteDialog({required this.isFoodCourt, required this.stalls});
  final bool isFoodCourt;
  final List<Stall> stalls;
  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  final key = GlobalKey<FormState>();
  final email = TextEditingController(), phone = TextEditingController();
  String role = 'staff';
  String? stallId;
  @override
  void dispose() {
    email.dispose();
    phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => AlertDialog(
    title: const Text('Invite staff'),
    content: Form(
      key: key,
      child: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: email,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (v) {
                if ((v?.trim().isEmpty ?? true) && phone.text.trim().isEmpty) {
                  return 'Enter an email or phone.';
                }
                if (v!.trim().isNotEmpty &&
                    !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim())) {
                  return 'Enter a valid email.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: phone,
              decoration: const InputDecoration(labelText: 'Phone (optional)'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: role,
              decoration: const InputDecoration(labelText: 'Role'),
              items: const [
                'manager',
                'kitchen',
                'cashier',
                'staff',
              ].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: (v) => role = v!,
            ),
            if (widget.isFoodCourt) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: stallId,
                decoration: const InputDecoration(labelText: 'Stall'),
                items: widget.stalls
                    .where((s) => s.isActive)
                    .map(
                      (s) => DropdownMenuItem(value: s.id, child: Text(s.name)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => stallId = v),
                validator: (v) => v == null ? 'Select a stall.' : null,
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(c),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!(key.currentState?.validate() ?? false)) return;
          Navigator.pop(
            c,
            _InviteDraft(
              email: _optionalText(email.text),
              phone: _optionalText(phone.text),
              role: role,
              stallId: stallId,
            ),
          );
        },
        child: const Text('Create invitation'),
      ),
    ],
  );
}

class _InviteDraft {
  const _InviteDraft({
    required this.email,
    required this.phone,
    required this.role,
    required this.stallId,
  });
  final String? email, phone, stallId;
  final String role;
}

String? _optionalText(String value) {
  final v = value.trim();
  return v.isEmpty ? null : v;
}

class AcceptInvitationPage extends StatefulWidget {
  const AcceptInvitationPage({
    super.key,
    required this.initialToken,
    required this.authenticated,
    required this.onRequireLogin,
    required this.onAccepted,
  });
  final String? initialToken;
  final bool authenticated;
  final ValueChanged<String> onRequireLogin;
  final VoidCallback onAccepted;
  @override
  State<AcceptInvitationPage> createState() => _AcceptInvitationPageState();
}

class _AcceptInvitationPageState extends State<AcceptInvitationPage> {
  late final token = TextEditingController(text: widget.initialToken);
  InvitationPreview? preview;
  bool busy = false;
  String? error;
  @override
  void dispose() {
    token.dispose();
    super.dispose();
  }

  Future<void> check() async {
    final value = _invitationToken(token.text);
    if (value.isEmpty) return;
    if (!widget.authenticated) {
      widget.onRequireLogin(value);
      return;
    }
    setState(() => busy = true);
    try {
      final p = await StaffService(Supabase.instance.client).preview(value);
      if (mounted) {
        setState(() {
          preview = p;
          busy = false;
          error = null;
        });
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = e.message;
        });
      }
    }
  }

  Future<void> accept() async {
    setState(() => busy = true);
    try {
      await StaffService(Supabase.instance.client)
          .redeem(_invitationToken(token.text));
      if (mounted) widget.onAccepted();
    } on PostgrestException catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Accept staff invitation',
                  style: Theme.of(c).textTheme.headlineMedium,
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: token,
                  decoration: const InputDecoration(
                    labelText: 'Invitation token or link',
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: busy ? null : check,
                  child: Text(
                    widget.authenticated
                        ? 'View invitation'
                        : 'Continue to sign in',
                  ),
                ),
                if (preview != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    preview!.businessName,
                    style: Theme.of(c).textTheme.titleLarge,
                  ),
                  Text(
                    '${preview!.role} - ${preview!.stallName ?? 'Business-wide'}',
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: busy ? null : accept,
                    child: const Text('Accept invitation'),
                  ),
                ],
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

String _invitationToken(String value) {
  final trimmed = value.trim();
  return Uri.tryParse(trimmed)?.queryParameters['token'] ?? trimmed;
}
