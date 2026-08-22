part of '../../main.dart';

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
  String? profileName;
  List<BusinessAccess> availableAccess = const [];
  BusinessAccess? selectedAccess;
  String? pendingInvitationToken;
  StreamSubscription<AuthState>? _authSubscription;

  SupabaseClient get _supabase => Supabase.instance.client;
  AuthService get _authService => AuthService(_supabase);

  @override
  void initState() {
    super.initState();
    if (widget.initializationError == null) {
      _authSubscription = _supabase.auth.onAuthStateChange.listen((state) {
        if (!mounted) return;
        if (state.event == AuthChangeEvent.signedOut) {
          setState(() {
            page = AppPage.welcome;
            selectedAccess = null;
            availableAccess = const [];
          });
        } else if (state.session != null &&
            state.event != AuthChangeEvent.tokenRefreshed) {
          _loadAccess();
        }
      });
      if (_supabase.auth.currentSession != null) _loadAccess();
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void go(AppPage value) => setState(() => page = value);

  Future<void> _signIn(String email, String password) async {
    setState(() {
      loadingAccess = true;
      authError = null;
    });
    try {
      await _authService.signIn(email, password);
      await _loadAccess();
    } on AuthException catch (_) {
      if (mounted) {
        setState(
          () => authError = 'We could not sign you in. Check your email and password, then try again.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => authError = 'Connection problem. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => loadingAccess = false);
      }
    }
  }

  Future<void> _createAccount(String email, String password) async {
    setState(() {
      loadingAccess = true;
      authError = null;
    });
    try {
      final response = await _authService.createAccount(email, password);
      if (response.session != null) {
        await _loadAccess();
      } else if (mounted) {
        setState(() {
          page = AppPage.login;
          authError = 'Account created. Confirm your email, then sign in.';
        });
      }
    } on AuthException catch (_) {
      if (mounted) {
        setState(
          () => authError = 'We could not create your account. Try a different email or password.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => authError = 'Connection problem. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => loadingAccess = false);
      }
    }
  }

  Future<void> _createBusiness(
    String name,
    bool isFoodCourt,
    String businessCode,
  ) async {
    setState(() {
      loadingAccess = true;
      authError = null;
    });
    try {
      await _supabase.rpc(
        'create_business',
        params: {
          'p_name': name,
          'p_type': isFoodCourt ? 'food_court' : 'restaurant',
          'p_business_code': businessCode,
        },
      );
      await _loadAccess();
    } on PostgrestException catch (_) {
      if (mounted) {
        setState(
          () => authError = 'We could not create that workspace. The business code may already be in use.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => authError = 'Connection problem. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => loadingAccess = false);
      }
    }
  }

  Future<void> _loadAccess() async {
    if (widget.initializationError != null ||
        _supabase.auth.currentSession == null) {
      return;
    }
    if (mounted) {
      setState(() {
        loadingAccess = true;
        authError = null;
      });
    }
    try {
      final profile = await _supabase
          .from('profiles')
          .select('full_name')
          .maybeSingle();
      final values = await AccessRepository(_supabase).loadAccess();
      if (!mounted) {
        return;
      }
      setState(() {
        availableAccess = values;
        profileName = profile?['full_name'] as String?;
        loadingAccess = false;
        if (pendingInvitationToken != null) {
          page = AppPage.acceptInvitation;
        } else if (values.isEmpty) {
          page = AppPage.createBusiness;
        } else if (_distinctBusinesses(values).length > 1) {
          page = AppPage.businessSelect;
        } else {
          _selectAccess(values.first);
        }
      });
    } on PostgrestException catch (_) {
      if (mounted) {
        setState(() {
          loadingAccess = false;
          authError = 'We could not load your workspace. Please try again.';
          page = AppPage.login;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          loadingAccess = false;
          authError = 'Connection problem. Please try again.';
          page = AppPage.login;
        });
      }
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
    try {
      await _authService.signOut();
      if (mounted) {
        setState(() {
          page = AppPage.welcome;
          selectedAccess = null;
          availableAccess = const [];
        });
      }
    } catch (_) {
      if (mounted) {
        _notice(context, 'We could not sign you out. Please try again.');
      }
    }
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
                    onInvitation: () => go(AppPage.acceptInvitation),
                  );
                case AppPage.login:
                  return LoginPage(
                    onBack: () => go(AppPage.access),
                    onSignIn: _signIn,
                    onCreateAccount: () => go(AppPage.createAccount),
                    loading: loadingAccess,
                    error: authError,
                  );
                case AppPage.createAccount:
                  return CreateAccountPage(
                    onBack: () => go(AppPage.login),
                    onCreateAccount: _createAccount,
                    loading: loadingAccess,
                    error: authError,
                  );
                case AppPage.createBusiness:
                  return CreateBusinessPage(
                    onBack: () => go(AppPage.login),
                    onCreate: _createBusiness,
                    loading: loadingAccess,
                    error: authError,
                  );
                case AppPage.success:
                  return SuccessPage(onOpen: () => go(AppPage.dashboard));
                case AppPage.businessSelect:
                  return BusinessSelectPage(
                    access: _distinctBusinesses(availableAccess),
                    onSelect: (business) {
                      final first = availableAccess.firstWhere(
                        (value) => value.businessId == business.businessId,
                      );
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
                    businessName: selectedAccess?.businessName ?? '',
                    businessId: selectedAccess?.businessId ?? '',
                    currentRole: selectedAccess?.role ?? '',
                    selectedStallId: selectedAccess?.stallId,
                    stallName: selectedAccess?.stallName,
                    userName: profileName,
                    stallAccess: availableAccess
                        .where(
                          (item) =>
                              item.businessId == selectedAccess?.businessId &&
                              item.stallId != null,
                        )
                        .toList(),
                    onSection: (s) => setState(() => section = s),
                    onAddStaff: () => go(AppPage.addStaff),
                    onStaff: () => go(AppPage.staffDetails),
                    onSelectStall: (value) =>
                        setState(() => _selectAccess(value)),
                    onLogout: _signOut,
                  );
                case AppPage.addStaff:
                  return AddStaffPage(
                    isFoodCourt: isFoodCourt,
                    onBack: () => go(AppPage.dashboard),
                    onSend: () => go(AppPage.staffDetails),
                  );
                case AppPage.staffDetails:
                  return StaffDetailsPage(
                    isFoodCourt: isFoodCourt,
                    onBack: () => go(AppPage.dashboard),
                  );
                case AppPage.acceptInvitation:
                  return AcceptInvitationPage(
                    initialToken: pendingInvitationToken,
                    authenticated: _supabase.auth.currentSession != null,
                    onRequireLogin: (token) => setState(() {
                      pendingInvitationToken = token;
                      page = AppPage.login;
                    }),
                    onAccepted: () {
                      pendingInvitationToken = null;
                      _loadAccess();
                    },
                  );
              }
            },
          ),
  );
}

enum AppPage {
  welcome,
  access,
  login,
  createAccount,
  createBusiness,
  success,
  businessSelect,
  dashboard,
  addStaff,
  staffDetails,
  acceptInvitation,
}
