part of '../../main.dart';

class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.onBack,
  });
  final String title, subtitle;
  final VoidCallback? onBack;
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
                    if (onBack != null)
                      IconButton(
                        onPressed: onBack,
                        icon: const Icon(Icons.arrow_back_rounded),
                      )
                    else
                      const SizedBox(width: 48),
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
  const AccessPage({
    super.key,
    required this.onBack,
    required this.onLogin,
    required this.onInvitation,
  });
  final VoidCallback onBack, onLogin, onInvitation;
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
          title: "I'm joining a team",
          detail: 'Use the invitation from your restaurant manager.',
          button: 'Use staff invitation',
          onTap: onInvitation,
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

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.onSignIn,
    required this.onCreateAccount,
    required this.loading,
    this.error,
  });
  final void Function(String email, String password) onSignIn;
  final VoidCallback onCreateAccount;
  final bool loading;
  final String? error;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _hidePassword = true;
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AuthShell(
    title: 'Welcome back.',
    subtitle: 'Sign in to continue to your workspace.',
    onBack: null,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _FormLabel('Email address'),
        const SizedBox(height: 8),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.email_outlined),
            hintText: 'you@example.com',
          ),
        ),
        const SizedBox(height: 16),
        const _FormLabel('Password'),
        const SizedBox(height: 8),
        TextField(
          controller: _passwordController,
          obscureText: _hidePassword,
          enableSuggestions: false,
          autocorrect: false,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            hintText: 'Your password',
            suffixIcon: IconButton(
              onPressed: () => setState(() => _hidePassword = !_hidePassword),
              icon: Icon(
                _hidePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: widget.loading
              ? null
              : () {
                  final email = _emailController.text.trim().toLowerCase();
                  final password = _passwordController.text;
                  if (email.contains('@') &&
                      email.contains('.') &&
                      password.isNotEmpty) {
                    widget.onSignIn(email, password);
                  }
                },
          style: _primaryStyle(full: true),
          child: Text(widget.loading ? 'Signing in...' : 'Sign in'),
        ),
        if (widget.error != null) ...[
          const SizedBox(height: 12),
          _AuthError(message: widget.error!),
        ],
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: widget.loading ? null : widget.onCreateAccount,
            child: const Text("Don't have an account? Create an account"),
          ),
        ),
      ],
    ),
  );
}

class CreateAccountPage extends StatefulWidget {
  const CreateAccountPage({
    super.key,
    required this.onBack,
    required this.onCreateAccount,
    required this.loading,
    this.error,
  });
  final VoidCallback onBack;
  final void Function(String fullName, String email, String password)
      onCreateAccount;
  final bool loading;
  final String? error;
  @override
  State<CreateAccountPage> createState() => _CreateAccountPageState();
}

class _CreateAccountPageState extends State<CreateAccountPage> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _validationError;
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AuthShell(
    title: 'Create your account.',
    subtitle: 'Use your email and a secure password to get started.',
    onBack: widget.onBack,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _FormLabel('Full name'),
        const SizedBox(height: 8),
        TextField(
          controller: _fullNameController,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.person_outline_rounded),
            hintText: 'e.g. Aarav Patel',
          ),
        ),
        const SizedBox(height: 16),
        const _FormLabel('Email address'),
        const SizedBox(height: 8),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.email_outlined),
            hintText: 'you@example.com',
          ),
        ),
        const SizedBox(height: 16),
        const _FormLabel('Password'),
        const SizedBox(height: 8),
        TextField(
          controller: _passwordController,
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          decoration: const InputDecoration(hintText: 'At least 6 characters'),
        ),
        const SizedBox(height: 16),
        const _FormLabel('Confirm password'),
        const SizedBox(height: 8),
        TextField(
          controller: _confirmPasswordController,
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          decoration: const InputDecoration(hintText: 'Repeat your password'),
        ),
        const SizedBox(height: 22),
        FilledButton(
          onPressed: widget.loading
              ? null
              : () {
                  final fullName = _fullNameController.text.trim();
                  final email = _emailController.text.trim().toLowerCase();
                  final password = _passwordController.text;
                  if (fullName.isEmpty ||
                      !email.contains('@') ||
                      !email.contains('.') ||
                      password.length < 6) {
                    setState(
                      () => _validationError = 'Enter your full name, a valid email, and a password with at least 6 characters.',
                    );
                  } else if (password != _confirmPasswordController.text) {
                    setState(
                      () => _validationError = 'Your passwords do not match.',
                    );
                  } else {
                    setState(() => _validationError = null);
                    widget.onCreateAccount(fullName, email, password);
                  }
                },
          style: _primaryStyle(full: true),
          child: Text(
            widget.loading ? 'Creating account...' : 'Create account',
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: TextButton(
            onPressed: widget.loading ? null : widget.onBack,
            child: const Text("Already have an account? Sign in"),
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

class SetStaffPasswordPage extends StatefulWidget {
  const SetStaffPasswordPage({
    super.key,
    required this.email,
    required this.role,
    required this.onSetPassword,
    required this.onBack,
    required this.loading,
    this.error,
  });
  final String email, role;
  final ValueChanged<String> onSetPassword;
  final VoidCallback onBack;
  final bool loading;
  final String? error;

  @override
  State<SetStaffPasswordPage> createState() => _SetStaffPasswordPageState();
}

class _SetStaffPasswordPageState extends State<SetStaffPasswordPage> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _validationError;
  bool _hidePassword = true;
  bool _hideConfirmPassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AuthShell(
    title: 'Set your password.',
    subtitle: 'Your invitation has been verified. Set a password for future sign-ins.',
    onBack: () {},
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FormLabel('Signed in as'),
        const SizedBox(height: 8),
        Text(widget.email),
        const SizedBox(height: 12),
        _FormLabel('Assigned role'),
        const SizedBox(height: 8),
        Text(widget.role),
        const SizedBox(height: 16),
        const _FormLabel('Password'),
        const SizedBox(height: 8),
        TextField(
          controller: _passwordController,
          obscureText: _hidePassword,
          enableSuggestions: false,
          autocorrect: false,
          decoration: InputDecoration(
            hintText: 'At least 6 characters',
            suffixIcon: IconButton(
              onPressed: () => setState(() => _hidePassword = !_hidePassword),
              icon: Icon(
                _hidePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const _FormLabel('Confirm password'),
        const SizedBox(height: 8),
        TextField(
          controller: _confirmPasswordController,
          obscureText: _hideConfirmPassword,
          enableSuggestions: false,
          autocorrect: false,
          decoration: InputDecoration(
            hintText: 'Repeat your password',
            suffixIcon: IconButton(
              onPressed: () => setState(
                () => _hideConfirmPassword = !_hideConfirmPassword,
              ),
              icon: Icon(
                _hideConfirmPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        FilledButton(
          onPressed: widget.loading
              ? null
              : () {
                  final password = _passwordController.text;
                  if (password.length < 6) {
                    setState(
                      () => _validationError =
                          'Enter a password with at least 6 characters.',
                    );
                  } else if (password != _confirmPasswordController.text) {
                    setState(() => _validationError = 'Your passwords do not match.');
                  } else {
                    setState(() => _validationError = null);
                    widget.onSetPassword(password);
                  }
                },
          style: _primaryStyle(full: true),
          child: Text(widget.loading ? 'Saving password...' : 'Continue'),
        ),
        const SizedBox(height: 20),
        Center(
          child: TextButton(
            onPressed: widget.loading ? null : widget.onBack,
            child: const Text("Already have an account? Sign in"),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: TextButton(
            onPressed: widget.loading ? null : widget.onBack,
            child: const Text("Already have an account? Sign in"),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: TextButton(
            onPressed: widget.loading ? null : widget.onBack,
            child: const Text("Already have an account? Sign in"),
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

class StaffJoinPage extends StatefulWidget {
  const StaffJoinPage({
    super.key,
    required this.onBack,
    required this.onStart,
    required this.loading,
    this.error,
  });
  final VoidCallback onBack;
  final void Function(String email, String password) onStart;
  final bool loading;
  final String? error;

  @override
  State<StaffJoinPage> createState() => _StaffJoinPageState();
}

class _StaffJoinPageState extends State<StaffJoinPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _validationError;
  bool _hidePassword = true;
  bool _hideConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AuthShell(
    title: 'Join a team.',
    subtitle: 'Use the email your owner invited.',
    onBack: widget.onBack,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _FormLabel('Invited email address'),
        const SizedBox(height: 8),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(hintText: 'you@example.com'),
        ),
        const SizedBox(height: 16),
        const _FormLabel('Create password'),
        const SizedBox(height: 8),
        TextField(
          controller: _passwordController,
          obscureText: _hidePassword,
          enableSuggestions: false,
          autocorrect: false,
          decoration: InputDecoration(
            hintText: 'At least 6 characters',
            suffixIcon: IconButton(
              onPressed: () => setState(() => _hidePassword = !_hidePassword),
              icon: Icon(
                _hidePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const _FormLabel('Confirm password'),
        const SizedBox(height: 8),
        TextField(
          controller: _confirmPasswordController,
          obscureText: _hideConfirmPassword,
          enableSuggestions: false,
          autocorrect: false,
          decoration: InputDecoration(
            hintText: 'Repeat your password',
            suffixIcon: IconButton(
              onPressed: () => setState(
                () => _hideConfirmPassword = !_hideConfirmPassword,
              ),
              icon: Icon(
                _hideConfirmPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        FilledButton(
          onPressed: widget.loading
              ? null
              : () {
                  final email = _emailController.text.trim().toLowerCase();
                  final password = _passwordController.text;
                  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email) ||
                      password.length < 6) {
                    setState(
                      () => _validationError =
                          'Enter your invited email and a password with at least 6 characters.',
                    );
                  } else if (password != _confirmPasswordController.text) {
                    setState(() => _validationError = 'Your passwords do not match.');
                  } else {
                    setState(() => _validationError = null);
                    widget.onStart(email, password);
                  }
                },
          style: _primaryStyle(full: true),
          child: Text(widget.loading ? 'Sending code...' : 'Send verification code'),
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

class StaffOtpPage extends StatefulWidget {
  const StaffOtpPage({
    super.key,
    required this.email,
    required this.onBack,
    required this.onVerify,
    required this.loading,
    this.error,
  });
  final String email;
  final VoidCallback onBack;
  final ValueChanged<String> onVerify;
  final bool loading;
  final String? error;

  @override
  State<StaffOtpPage> createState() => _StaffOtpPageState();
}

class _StaffOtpPageState extends State<StaffOtpPage> {
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AuthShell(
    title: 'Check your email.',
    subtitle: 'Enter the six-digit verification code sent to ${widget.email}.',
    onBack: widget.onBack,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(labelText: 'Verification code'),
        ),
        const SizedBox(height: 22),
        FilledButton(
          onPressed: widget.loading
              ? null
              : () {
                  final code = _codeController.text.trim();
                  if (RegExp(r'^\d{6}$').hasMatch(code)) {
                    widget.onVerify(code);
                  }
                },
          style: _primaryStyle(full: true),
          child: Text(widget.loading ? 'Verifying...' : 'Verify and join'),
        ),
        if (widget.error != null) ...[
          const SizedBox(height: 12),
          _AuthError(message: widget.error!),
        ],
      ],
    ),
  );
}

class _AuthError extends StatelessWidget {
  const _AuthError({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xffffe9e7),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(message, style: const TextStyle(color: Color(0xff9d2520))),
  );
}
