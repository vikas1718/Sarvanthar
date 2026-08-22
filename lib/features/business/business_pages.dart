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
  final void Function(String name, bool isFoodCourt, String businessCode)
  onCreate;
  final bool loading;
  final String? error;
  @override
  State<CreateBusinessPage> createState() => _CreateBusinessPageState();
}

class _CreateBusinessPageState extends State<CreateBusinessPage> {
  bool isFoodCourt = false;
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  String? _validationError;

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

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
        TextField(
          controller: _nameController,
          decoration: InputDecoration(hintText: 'e.g. The Courtyard Food Hall'),
        ),
        const SizedBox(height: 16),
        const _FormLabel('Business code'),
        const SizedBox(height: 7),
        TextField(
          controller: _codeController,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(hintText: 'e.g. COURTYARD01'),
        ),
        const SizedBox(height: 7),
        const Text(
          'Use 6â€“20 uppercase letters or numbers. Staff can use this code to identify your business.',
          style: TextStyle(fontSize: 12),
        ),
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
            initialValue: '3â€“5 stalls',
            items: const [
              DropdownMenuItem(
                value: '1â€“2 stalls',
                child: Text('1â€“2 stalls'),
              ),
              DropdownMenuItem(
                value: '3â€“5 stalls',
                child: Text('3â€“5 stalls'),
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
                  final code = _codeController.text.trim().toUpperCase();
                  if (name.isEmpty ||
                      !RegExp(r'^[A-Z0-9]{6,20}$').hasMatch(code)) {
                    setState(
                      () => _validationError = 'Enter a business name and a unique 6â€“20 character code.',
                    );
                    return;
                  }
                  setState(() => _validationError = null);
                  widget.onCreate(name, isFoodCourt, code);
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
