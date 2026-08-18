import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'access_models.dart';
import 'access_repository.dart';
import 'app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? initializationError;
  if (AppConfig.isConfigured) {
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabasePublishableKey,
      );
    } catch (_) {
      initializationError = 'We could not connect to ServeFlow. Please try again later.';
    }
  } else {
    initializationError = 'Supabase configuration is missing. Start the app with SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY.';
  }
  runApp(ServeFlowApp(initializationError: initializationError));
}

const _navy = Color(0xff172033);
const _amber = Color(0xffe78b20);
const _cream = Color(0xfffff9f2);
const _line = Color(0xffe9e1d5);
const _muted = Color(0xff6f7682);

class ServeFlowApp extends StatefulWidget {
  const ServeFlowApp({super.key, this.initializationError});
  final String? initializationError;
  @override
  State<ServeFlowApp> createState() => _ServeFlowAppState();
}

class _ServeFlowAppState extends State<ServeFlowApp> {
  AppPage page = AppPage.welcome;
  String section = 'Overview';
  bool staffRole = false;
  String access = 'Owner access';
  bool isFoodCourt = true;
  bool loadingAccess = false;
  String? authError;
  String? pendingPhone;
  List<BusinessAccess> availableAccess = const [];
  BusinessAccess? selectedAccess;
  StreamSubscription<AuthState>? _authSubscription;

  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    if (widget.initializationError == null) {
      _authSubscription = _supabase.auth.onAuthStateChange.listen((state) {
        if (!mounted) return;
        if (state.event == AuthChangeEvent.signedOut) {
          setState(() { page = AppPage.welcome; selectedAccess = null; availableAccess = const []; });
        } else if (state.session != null && state.event != AuthChangeEvent.tokenRefreshed) {
          _loadAccess();
        }
      });
      if (_supabase.auth.currentSession != null) _loadAccess();
    }
  }

  @override
  void dispose() { _authSubscription?.cancel(); super.dispose(); }

  void go(AppPage value) => setState(() => page = value);

  Future<void> _sendOtp(String phone) async {
    setState(() { loadingAccess = true; authError = null; });
    try {
      await _supabase.auth.signInWithOtp(phone: phone);
      if (mounted) setState(() { pendingPhone = phone; page = AppPage.otp; });
    } on AuthException catch (_) {
      if (mounted) setState(() => authError = 'We could not send a verification code. Check your phone number and try again.');
    } catch (_) {
      if (mounted) setState(() => authError = 'Connection problem. Please try again.');
    } finally { if (mounted) setState(() => loadingAccess = false); }
  }

  Future<void> _verifyOtp(String token) async {
    if (pendingPhone == null) return;
    setState(() { loadingAccess = true; authError = null; });
    try {
      final response = await _supabase.auth.verifyOTP(phone: pendingPhone!, token: token, type: OtpType.sms);
      if (response.session == null) throw const AuthException('No session');
      await _loadAccess();
    } on AuthException catch (_) {
      if (mounted) setState(() => authError = 'That code is invalid or expired. Request a new code and try again.');
    } catch (_) {
      if (mounted) setState(() => authError = 'We could not verify the code. Please try again.');
    } finally { if (mounted) setState(() => loadingAccess = false); }
  }

  Future<void> _loadAccess() async {
    if (widget.initializationError != null || _supabase.auth.currentSession == null) return;
    if (mounted) setState(() { loadingAccess = true; authError = null; });
    try {
      await _supabase.from('profiles').select().single();
      final values = await AccessRepository(_supabase).loadAccess();
      if (!mounted) return;
      setState(() {
        availableAccess = values;
        loadingAccess = false;
        if (values.isEmpty) page = AppPage.createBusiness;
        else if (_distinctBusinesses(values).length > 1) page = AppPage.businessSelect;
        else _selectAccess(values.first);
      });
    } on PostgrestException catch (_) {
      if (mounted) setState(() { loadingAccess = false; authError = 'We could not load your workspace. Please try again.'; page = AppPage.login; });
    } catch (_) {
      if (mounted) setState(() { loadingAccess = false; authError = 'Connection problem. Please try again.'; page = AppPage.login; });
    }
  }

  List<BusinessAccess> _distinctBusinesses(List<BusinessAccess> values) {
    final seen = <String>{};
    return values.where((value) => seen.add(value.businessId)).toList();
  }

  void _selectAccess(BusinessAccess value) {
    selectedAccess = value;
    isFoodCourt = value.isFoodCourt;
    staffRole = !value.isOwner;
    access = '${value.role[0].toUpperCase()}${value.role.substring(1)} access';
    section = 'Overview';
    page = AppPage.dashboard;
  }

  Future<void> _signOut() async {
    try { await _supabase.auth.signOut(); } catch (_) { if (mounted) _notice(context, 'We could not sign you out. Please try again.'); }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'ServeFlow',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: _cream,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _amber,
        surface: Colors.white,
        onSurface: _navy,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontWeight: FontWeight.w800,
          color: _navy,
          letterSpacing: -1.4,
        ),
        headlineMedium: TextStyle(
          fontWeight: FontWeight.w800,
          color: _navy,
          letterSpacing: -.8,
        ),
        titleLarge: TextStyle(fontWeight: FontWeight.w800, color: _navy),
        titleMedium: TextStyle(fontWeight: FontWeight.w700, color: _navy),
        bodyMedium: TextStyle(color: _muted, height: 1.45),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xfffbfaf8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _line),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    ),
    home: widget.initializationError != null
        ? ConfigurationErrorPage(message: widget.initializationError!)
        : Builder(
      builder: (context) {
        switch (page) {
          case AppPage.welcome:
            return WelcomePage(onStart: () => go(AppPage.access));
          case AppPage.access:
            return AccessPage(
              onBack: () => go(AppPage.welcome),
              onLogin: () => go(AppPage.login),
            );
          case AppPage.login:
            return LoginPage(
              onBack: () => go(AppPage.access),
              onContinue: _sendOtp,
              loading: loadingAccess,
              error: authError,
            );
          case AppPage.otp:
            return OtpPage(
              onBack: () => go(AppPage.login),
              onVerified: _verifyOtp,
              onResend: pendingPhone == null ? null : () => _sendOtp(pendingPhone!),
              loading: loadingAccess,
              error: authError,
            );
          case AppPage.createBusiness:
            return CreateBusinessPage(
              onBack: () => go(AppPage.otp),
              onCreate: (foodCourt) {
                setState(() => isFoodCourt = foodCourt);
                go(AppPage.success);
              },
            );
          case AppPage.success:
            return SuccessPage(onOpen: () => go(AppPage.dashboard));
          case AppPage.businessSelect:
            return BusinessSelectPage(
              access: _distinctBusinesses(availableAccess),
              onSelect: (business) {
                final first = availableAccess.firstWhere((value) => value.businessId == business.businessId);
                setState(() => _selectAccess(first));
              },
              onLogout: _signOut,
            );
          case AppPage.dashboard:
            return DashboardPage(
              section: section,
              staffRole: staffRole,
              access: access,
              isFoodCourt: isFoodCourt,
              onSection: (s) => setState(() => section = s),
              onAddStaff: () => go(AppPage.addStaff),
              onStaff: () => go(AppPage.staffDetails),
              onSwitch: () => setState(() {
                if (selectedAccess != null && !selectedAccess!.isOwner) {
                  final assignments = availableAccess.where((item) => item.businessId == selectedAccess!.businessId && item.stallId != null).toList();
                  if (assignments.length > 1) _selectAccess(assignments[(assignments.indexWhere((item) => item.stallId == selectedAccess!.stallId) + 1) % assignments.length]);
                }
              }),
              onLogout: _signOut,
            );
          case AppPage.addStaff:
            return AddStaffPage(
              isFoodCourt: isFoodCourt,
              onBack: () => go(AppPage.dashboard),
              onSend: () => go(AppPage.staffDetails),
            );
          case AppPage.staffDetails:
            return StaffDetailsPage(isFoodCourt: isFoodCourt, onBack: () => go(AppPage.dashboard));
        }
      },
    ),
  );
}

enum AppPage {
  welcome,
  access,
  login,
  otp,
  createBusiness,
  success,
  businessSelect,
  dashboard,
  addStaff,
  staffDetails,
}

class Brand extends StatelessWidget {
  const Brand({super.key, this.light = false});
  final bool light;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: _amber,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.restaurant_rounded,
          color: Colors.white,
          size: 20,
        ),
      ),
      const SizedBox(width: 10),
      Text(
        'serveflow',
        style: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w800,
          color: light ? Colors.white : _navy,
          letterSpacing: -.8,
        ),
      ),
    ],
  );
}

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key, required this.onStart});
  final VoidCallback onStart;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, c) {
          final narrow = c.maxWidth < 760;
          return Stack(
            children: [
              Positioned(
                right: -90,
                top: -60,
                child: Container(
                  width: 390,
                  height: 390,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xffffe1b9).withValues(alpha: .38),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: narrow ? 24 : 72,
                  vertical: 28,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Brand(),
                    const Spacer(),
                    if (!narrow) const _FoodCourtIllustration(),
                    SizedBox(
                      width: narrow ? double.infinity : 610,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _Eyebrow(label: 'THE TABLE IS READY'),
                          const SizedBox(height: 18),
                          Text(
                            'Food court operations,\nwithout the scramble.',
                            style: Theme.of(context).textTheme.headlineLarge
                                ?.copyWith(
                                  fontSize: narrow ? 43 : 62,
                                  height: .98,
                                ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'A calm command centre for every order, stall and shift. Built for the rush, designed for people.',
                          ),
                          const SizedBox(height: 30),
                          FilledButton.icon(
                            onPressed: onStart,
                            icon: const Icon(Icons.arrow_forward_rounded),
                            label: const Text('Set up your business'),
                            style: _primaryStyle(),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    const Row(
                      children: [
                        Icon(Icons.qr_code_2_rounded, size: 18, color: _amber),
                        SizedBox(width: 8),
                        Text(
                          'QR ordering for modern food courts',
                          style: TextStyle(
                            color: _muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _FoodCourtIllustration extends StatelessWidget {
  const _FoodCourtIllustration();
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: Transform.rotate(
      angle: -.06,
      child: Container(
        width: 330,
        height: 180,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _navy,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22172033),
              blurRadius: 30,
              offset: Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'LIVE FLOOR',
              style: TextStyle(
                color: Color(0xffffc36e),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const Spacer(),
            Row(
              children: [
                const Text(
                  '24',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 9),
                const Text(
                  'orders\nin progress',
                  style: TextStyle(color: Color(0xffb7bfcd), height: 1.1),
                ),
                const Spacer(),
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: _amber,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.child,
  });
  final String title, subtitle;
  final VoidCallback onBack;
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 470),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const Spacer(),
                    const Brand(),
                  ],
                ),
                const SizedBox(height: 58),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(fontSize: 38),
                ),
                const SizedBox(height: 10),
                Text(subtitle),
                const SizedBox(height: 30),
                child,
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class AccessPage extends StatelessWidget {
  const AccessPage({super.key, required this.onBack, required this.onLogin});
  final VoidCallback onBack, onLogin;
  @override
  Widget build(BuildContext context) => AuthShell(
    title: 'How do you use ServeFlow?',
    subtitle: 'Choose the access that fits your day-to-day work.',
    onBack: onBack,
    child: Column(
      children: [
        _AccessChoice(
          icon: Icons.storefront_rounded,
          title: 'I run the business',
          detail: 'Manage stalls, staff, orders and business settings.',
          button: 'Continue as owner',
          onTap: onLogin,
        ),
        const SizedBox(height: 14),
        _AccessChoice(
          icon: Icons.badge_outlined,
          title: 'I’m joining a team',
          detail: 'Use the invitation from your restaurant manager.',
          button: 'Use staff invitation',
          onTap: onLogin,
        ),
      ],
    ),
  );
}

class _AccessChoice extends StatelessWidget {
  const _AccessChoice({
    required this.icon,
    required this.title,
    required this.detail,
    required this.button,
    required this.onTap,
  });
  final IconData icon;
  final String title, detail, button;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xfffff1df),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: _amber),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    style: const TextStyle(color: _muted, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, color: _amber),
          ],
        ),
      ),
    ),
  );
}

class LoginPage extends StatelessWidget {
  const LoginPage({super.key, required this.onBack, required this.onContinue});
  final VoidCallback onBack, onContinue;
  @override
  Widget build(BuildContext context) => AuthShell(
    title: 'Welcome back.',
    subtitle: 'Enter your phone number and we’ll send a secure code.',
    onBack: onBack,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _FormLabel('Mobile number'),
        const SizedBox(height: 8),
        const TextField(
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            prefixText: '+91   ',
            hintText: '98765 43210',
          ),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: onContinue,
          style: _primaryStyle(full: true),
          child: const Text('Send verification code'),
        ),
        const SizedBox(height: 16),
        const Text(
          'We’ll only use this to keep your workspace secure.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: _muted),
        ),
      ],
    ),
  );
}

class OtpPage extends StatelessWidget {
  const OtpPage({super.key, required this.onBack, required this.onVerified});
  final VoidCallback onBack, onVerified;
  @override
  Widget build(BuildContext context) => AuthShell(
    title: 'Check your phone.',
    subtitle: 'We sent a six-digit code to +91 98765 43210.',
    onBack: onBack,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            6,
            (i) => SizedBox(
              width: 44,
              child: TextField(
                autofocus: i == 0,
                textAlign: TextAlign.center,
                maxLength: 1,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(counterText: ''),
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        FilledButton(
          onPressed: onVerified,
          style: _primaryStyle(full: true),
          child: const Text('Verify & continue'),
        ),
        TextButton(
          onPressed: () =>
              _notice(context, 'A new verification code has been sent.'),
          child: const Text('Resend code in 00:27'),
        ),
      ],
    ),
  );
}

class CreateBusinessPage extends StatefulWidget {
  const CreateBusinessPage({
    super.key,
    required this.onBack,
    required this.onCreate,
  });
  final VoidCallback onBack;
  final ValueChanged<bool> onCreate;
  @override
  State<CreateBusinessPage> createState() => _CreateBusinessPageState();
}

class _CreateBusinessPageState extends State<CreateBusinessPage> {
  bool isFoodCourt = false;
  @override
  Widget build(BuildContext context) => AuthShell(
    title: 'Tell us about your place.',
    subtitle: 'A few details and your workspace is ready.',
    onBack: widget.onBack,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _FormLabel('Business name'),
        const SizedBox(height: 7),
        const TextField(
          decoration: InputDecoration(hintText: 'e.g. The Courtyard Food Hall'),
        ),
        const SizedBox(height: 16),
        const _FormLabel('City'),
        const SizedBox(height: 7),
        const TextField(
          decoration: InputDecoration(hintText: 'e.g. Bengaluru'),
        ),
        const SizedBox(height: 16),
        const _FormLabel('Business type'),
        const SizedBox(height: 7),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, icon: Icon(Icons.restaurant_rounded), label: Text('Restaurant')),
            ButtonSegment(value: true, icon: Icon(Icons.storefront_rounded), label: Text('Food Court')),
          ],
          selected: {isFoodCourt},
          onSelectionChanged: (value) => setState(() => isFoodCourt = value.first),
        ),
        const SizedBox(height: 10),
        Text(isFoodCourt ? 'Food courts can manage stalls and assign staff to stalls.' : 'Restaurants manage staff directly. No stalls are required.'),
        const SizedBox(height: 16),
        if (isFoodCourt) const _FormLabel('Number of stalls'),
        if (isFoodCourt) const SizedBox(height: 7),
        if (isFoodCourt) DropdownButtonFormField<String>(
          initialValue: '3–5 stalls',
          items: const [
            DropdownMenuItem(value: '1–2 stalls', child: Text('1–2 stalls')),
            DropdownMenuItem(value: '3–5 stalls', child: Text('3–5 stalls')),
            DropdownMenuItem(value: '6+ stalls', child: Text('6+ stalls')),
          ],
          onChanged: (_) {},
        ),
        const SizedBox(height: 22),
        FilledButton(
          onPressed: () => widget.onCreate(isFoodCourt),
          style: _primaryStyle(full: true),
          child: const Text('Create my workspace'),
        ),
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

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.section,
    required this.staffRole,
    required this.access,
    required this.isFoodCourt,
    required this.onSection,
    required this.onAddStaff,
    required this.onStaff,
    required this.onSwitch,
    required this.onLogout,
  });
  final String section, access;
  final bool isFoodCourt;
  final bool staffRole;
  final ValueChanged<String> onSection;
  final VoidCallback onAddStaff, onStaff, onSwitch, onLogout;
  static const items = [
    ('Overview', Icons.grid_view_rounded),
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
      onSection: onSection,
      onSwitch: onSwitch,
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
    required this.onSection,
    required this.onSwitch,
    required this.onLogout,
  });
  final String active, access;
  final bool staffRole;
  final bool isFoodCourt;
  final ValueChanged<String> onSection;
  final VoidCallback onSwitch;
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
            isFoodCourt ? 'CENTRAL FOOD COURT' : 'ABC RESTAURANT',
            style: TextStyle(
              fontSize: 10,
              color: Color(0xff9aa5b8),
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 11),
        ...(isFoodCourt ? DashboardPage.items : DashboardPage.items.where((e) => e.$1 != 'Stalls')).map(
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
                    const Text(
                      'Aarav Patel',
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
    required this.onSection,
    required this.onAddStaff,
    required this.onStaff,
  });
  final String section;
  final bool staffRole;
  final bool isFoodCourt;
  final ValueChanged<String> onSection;
  final VoidCallback onAddStaff, onStaff;
  @override
  Widget build(BuildContext context) {
    if (section == 'Overview') {
      return _Overview(staffRole: staffRole, onSection: onSection);
    }
    if (section == 'Stalls') {
      return const _Stalls();
    }
    if (section == 'Staff') {
      return _Staff(isFoodCourt: isFoodCourt, onAdd: onAddStaff, onStaff: onStaff);
    }
    if (section == 'Orders') {
      return const _Orders();
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
      onPressed: () => _notice(c, 'Showing today’s service snapshot.'),
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
                'Today’s sales',
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

class _Stalls extends StatelessWidget {
  const _Stalls();
  @override
  Widget build(BuildContext c) => _PageShell(
    title: 'Stalls',
    subtitle: 'Three food concepts, one smooth service.',
    action: FilledButton.icon(
      onPressed: () => _notice(c, 'Adding stalls is coming soon.'),
      icon: const Icon(Icons.add_rounded),
      label: const Text('Add stall'),
      style: _primaryStyle(),
    ),
    child: const Column(
      children: [
        _StallRow(
          'South Bowl',
          'Healthy bowls & salads',
          'Open',
          '12 min',
          'Arjun, 3 staff',
          Colors.teal,
        ),
        SizedBox(height: 12),
        _StallRow(
          'Chaat & Co.',
          'Street food favourites',
          'Open',
          '5 min',
          'Nisha, 4 staff',
          _amber,
        ),
        SizedBox(height: 12),
        _StallRow(
          'Melt House',
          'Grilled sandwiches',
          'Paused',
          '—',
          'No manager assigned',
          Colors.blueGrey,
        ),
      ],
    ),
  );
}

class _StallRow extends StatelessWidget {
  const _StallRow(
    this.name,
    this.desc,
    this.status,
    this.time,
    this.team,
    this.color,
  );
  final String name, desc, status, time, team;
  final Color color;
  @override
  Widget build(BuildContext c) => _Panel(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final identity = Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .13),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.restaurant_menu_rounded, color: color),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    desc,
                    style: const TextStyle(fontSize: 13, color: _muted),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    team,
                    style: const TextStyle(fontSize: 12, color: _muted),
                  ),
                ],
              ),
            ),
          ],
        );
        final metadata = Wrap(
          spacing: 10,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _Status(status),
            Text(
              'Prep $time',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _navy,
              ),
            ),
          ],
        );
        if (constraints.maxWidth < 430) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: identity),
                  IconButton(
                    onPressed: () =>
                        _notice(c, '$name options are coming soon'),
                    icon: const Icon(Icons.more_horiz_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              metadata,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: identity),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _Status(status),
                const SizedBox(height: 8),
                Text(
                  'Prep $time',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _navy,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 5),
            IconButton(
              onPressed: () => _notice(c, '$name options are coming soon'),
              icon: const Icon(Icons.more_horiz_rounded),
            ),
          ],
        );
      },
    ),
  );
}

class _Staff extends StatelessWidget {
  const _Staff({required this.isFoodCourt, required this.onAdd, required this.onStaff});
  final bool isFoodCourt;
  final VoidCallback onAdd, onStaff;
  @override
  Widget build(BuildContext c) => _PageShell(
    title: 'Your team',
    subtitle: isFoodCourt ? 'People and permissions across Central Food Court.' : 'Roles and permissions for ABC Restaurant.',
    action: FilledButton.icon(
      onPressed: onAdd,
      icon: const Icon(Icons.person_add_alt_1_rounded),
      label: const Text('Invite staff'),
      style: _primaryStyle(),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _TeamStats(),
        const SizedBox(height: 24),
        _Panel(
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Team members',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () =>
                        _notice(c, 'Team filters are coming soon.'),
                    icon: const Icon(Icons.filter_list_rounded),
                  ),
                ],
              ),
              const Divider(color: _line),
              _Member('Vicky', 'Owner', isFoodCourt ? 'All stalls' : 'ABC Restaurant', true, onStaff),
              const Divider(color: _line),
              _Member('Rahul', 'Manager', isFoodCourt ? 'Pizza Stall, Burger Stall' : 'ABC Restaurant', true, onStaff),
              const Divider(color: _line),
              _Member(
                'Ajay',
                'Kitchen',
                isFoodCourt ? 'Pizza Stall' : 'ABC Restaurant',
                true,
                onStaff,
              ),
              const Divider(color: _line),
              _Member('Kumar', isFoodCourt ? 'Manager' : 'Cashier', isFoodCourt ? 'Burger Stall' : 'ABC Restaurant', false, onStaff),
            ],
          ),
        ),
      ],
    ),
  );
}

class _TeamStats extends StatelessWidget {
  const _TeamStats();
  @override
  Widget build(BuildContext c) => Wrap(
    spacing: 12,
    runSpacing: 12,
    children: const [
      _ChipStat('8', 'Active teammates', Icons.groups_2_outlined),
      _ChipStat('2', 'Invitations pending', Icons.mail_outline_rounded),
      _ChipStat('3', 'Stalls covered', Icons.storefront_outlined),
    ],
  );
}

class _ChipStat extends StatelessWidget {
  const _ChipStat(this.n, this.t, this.i);
  final String n, t;
  final IconData i;
  @override
  Widget build(BuildContext c) => Container(
    width: 190,
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _line),
    ),
    child: Row(
      children: [
        Icon(i, color: _amber),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              n,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
            ),
            Text(t, style: const TextStyle(fontSize: 11, color: _muted)),
          ],
        ),
      ],
    ),
  );
}

class _Member extends StatelessWidget {
  const _Member(this.name, this.role, this.scope, this.online, this.onTap);
  final String name, role, scope;
  final bool online;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext c) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: const Color(0xffffe4c1),
                child: Text(
                  name.split(' ').map((s) => s[0]).join(),
                  style: const TextStyle(
                    color: _navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (online)
                const Positioned(
                  right: 0,
                  bottom: 0,
                  child: CircleAvatar(
                    radius: 5,
                    backgroundColor: Color(0xff4ca66e),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _navy,
                  ),
                ),
                Text(
                  '$role  •  $scope',
                  style: const TextStyle(fontSize: 12, color: _muted),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: _muted),
        ],
      ),
    ),
  );
}

class AddStaffPage extends StatelessWidget {
  const AddStaffPage({super.key, required this.isFoodCourt, required this.onBack, required this.onSend});
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
              const Text('They’ll receive a secure invitation by SMS.'),
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
                  DropdownMenuItem(
                    value: 'Manager',
                    child: Text('Manager'),
                  ),
                  DropdownMenuItem(value: 'Cashier', child: Text('Cashier')),
                  DropdownMenuItem(
                    value: 'Kitchen',
                    child: Text('Kitchen'),
                  ),
                ],
                onChanged: null,
              ),
              if (isFoodCourt) const SizedBox(height: 18),
              if (isFoodCourt) const Text(
                'Assigned stalls',
                style: TextStyle(fontWeight: FontWeight.w700, color: _navy),
              ),
              if (isFoodCourt) const SizedBox(height: 8),
              if (isFoodCourt) const _AccessCheck(label: 'Pizza Stall', checked: true),
              if (isFoodCourt) const _AccessCheck(label: 'Burger Stall', checked: true),
              if (isFoodCourt) const _AccessCheck(label: 'Juice Stall', checked: false),
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
  Widget build(BuildContext c) => CheckboxListTile(
    value: checked,
    onChanged: (v) => setState(() => checked = v ?? false),
    title: Text(
      widget.label,
      style: const TextStyle(fontWeight: FontWeight.w600),
    ),
    contentPadding: EdgeInsets.zero,
    controlAffinity: ListTileControlAffinity.leading,
  );
}

class StaffDetailsPage extends StatelessWidget {
  const StaffDetailsPage({super.key, required this.isFoodCourt, required this.onBack});
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
              Text(isFoodCourt ? 'Rahul can switch only between the assigned stalls below.' : 'Rahul is assigned to ABC Restaurant as Manager.'),
              const SizedBox(height: 14),
              if (isFoodCourt) const _RoleAccess(
                stall: 'Pizza Stall',
                role: 'Manager',
                details: 'Orders, preparation board, menu availability',
              ),
              if (isFoodCourt) const SizedBox(height: 11),
              if (isFoodCourt) const _RoleAccess(
                stall: 'Burger Stall',
                role: 'Staff',
                details: 'Orders, preparation board, menu availability',
              ),
              if (!isFoodCourt) const _RoleAccess(stall: 'ABC Restaurant', role: 'Manager', details: 'Restaurant operations, menu and orders'),
              if (isFoodCourt) const Padding(padding: EdgeInsets.only(top: 14), child: Text('Juice Stall is not assigned to Rahul and will not appear in his stall selector.', style: TextStyle(color: _muted))),
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
              'We’ll let you know when the order board is available.',
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
                    : 'We’re shaping this part of ServeFlow next. Your current workspace stays exactly as it is.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 15),
              OutlinedButton(
                onPressed: () => _notice(
                  c,
                  staffRole
                      ? 'Access request recorded for the workspace owner.'
                      : 'You’ll be notified when this workspace is ready.',
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

class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.label});
  final String label;
  @override
  Widget build(BuildContext c) => Text(
    label,
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.3,
      color: _amber,
    ),
  );
}

ButtonStyle _primaryStyle({bool full = false}) => FilledButton.styleFrom(
  backgroundColor: _amber,
  foregroundColor: Colors.white,
  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
  minimumSize: full ? const Size(double.infinity, 52) : null,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  textStyle: const TextStyle(fontWeight: FontWeight.w800),
);

void _notice(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
}
