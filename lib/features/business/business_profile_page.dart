part of '../../main.dart';

class BusinessProfilePage extends StatefulWidget {
  const BusinessProfilePage({super.key, required this.businessId});

  final String businessId;

  @override
  State<BusinessProfilePage> createState() => _BusinessProfilePageState();
}

class _BusinessProfilePageState extends State<BusinessProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _logoController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _currencyController = TextEditingController(text: 'INR');
  final _taxController = TextEditingController();

  BusinessProfile? _profile;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  BusinessProfileService get _service =>
      BusinessProfileService(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant BusinessProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.businessId != widget.businessId) _load();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _currencyController.dispose();
    _taxController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await _service.load(widget.businessId);
      if (!mounted) return;
      _apply(profile);
      setState(() {
        _profile = profile;
        _loading = false;
      });
    } on PostgrestException catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = _messageFor(error);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Connection problem. Please try again.';
        });
      }
    }
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final taxText = _taxController.text.trim();
      final profile = await _service.update(
        businessId: widget.businessId,
        logoUrl: _optional(_logoController.text),
        phone: _optional(_phoneController.text),
        email: _optional(_emailController.text),
        address: _optional(_addressController.text),
        currency: _currencyController.text.trim().toUpperCase(),
        taxPercentage: taxText.isEmpty ? null : double.parse(taxText),
      );
      if (!mounted) return;
      _apply(profile);
      setState(() {
        _profile = profile;
        _saving = false;
      });
      _notice(context, 'Business profile updated successfully.');
    } on PostgrestException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = _messageFor(error);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Connection problem. Please try again.';
        });
      }
    }
  }

  void _apply(BusinessProfile profile) {
    _logoController.text = profile.logoUrl ?? '';
    _phoneController.text = profile.phone ?? '';
    _emailController.text = profile.email ?? '';
    _addressController.text = profile.address ?? '';
    _currencyController.text = profile.currency ?? 'INR';
    _taxController.text = profile.taxPercentage?.toString() ?? '';
  }

  String? _optional(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _messageFor(PostgrestException error) {
    const safeMessages = {
      'Only the business owner can update the business profile',
      'Currency must be a three-letter code',
      'Tax percentage must be between 0 and 100',
      'Business not found',
      'Authentication required',
    };
    return safeMessages.contains(error.message)
        ? error.message
        : 'We could not update the business profile. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_profile == null) {
      return _PageShell(
        title: 'Business Profile',
        subtitle: 'Manage your business information.',
        child: _ErrorPanel(message: _error!, onRetry: _load),
      );
    }
    final profile = _profile!;
    return _PageShell(
      title: 'Business Profile',
      subtitle: 'Manage the information associated with your workspace.',
      child: Form(
        key: _formKey,
        child: _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xfffff1df),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.business_rounded,
                      color: _amber,
                      size: 34,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Logo upload will be available in a future update.',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _ProfileField(
                label: 'Business Name',
                initialValue: profile.name,
                readOnly: true,
              ),
              _ProfileField(
                label: 'Business Type',
                initialValue: profile.type == 'food_court'
                    ? 'Food Court'
                    : 'Restaurant',
                readOnly: true,
              ),
              _ProfileField(
                label: 'Business Code',
                initialValue: profile.businessCode,
                readOnly: true,
              ),
              _ProfileField(
                label: 'Logo URL',
                controller: _logoController,
                hintText: 'Optional image URL',
                keyboardType: TextInputType.url,
              ),
              _ProfileField(
                label: 'Phone',
                controller: _phoneController,
                keyboardType: TextInputType.phone,
              ),
              _ProfileField(
                label: 'Email',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty) return null;
                  final valid = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                      .hasMatch(email);
                  return valid ? null : 'Enter a valid email address.';
                },
              ),
              _ProfileField(
                label: 'Address',
                controller: _addressController,
                maxLines: 3,
              ),
              _ProfileField(
                label: 'Currency',
                controller: _currencyController,
                textCapitalization: TextCapitalization.characters,
                validator: (value) =>
                    RegExp(r'^[A-Za-z]{3}$').hasMatch(value?.trim() ?? '')
                    ? null
                    : 'Enter a three-letter currency code.',
              ),
              _ProfileField(
                label: 'Tax Percentage',
                controller: _taxController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return null;
                  final tax = double.tryParse(text);
                  if (tax == null) return 'Enter a valid number.';
                  if (tax < 0 || tax > 100) {
                    return 'Tax percentage must be between 0 and 100.';
                  }
                  return null;
                },
              ),
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 16),
              ],
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Saving...' : 'Save Changes'),
                style: _primaryStyle(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.label,
    this.controller,
    this.initialValue,
    this.readOnly = false,
    this.hintText,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
    this.validator,
  });

  final String label;
  final TextEditingController? controller;
  final String? initialValue;
  final bool readOnly;
  final String? hintText;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final int maxLines;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FormLabel(label),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          initialValue: initialValue,
          readOnly: readOnly,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            hintText: hintText,
            suffixIcon: readOnly
                ? const Icon(Icons.lock_outline_rounded, size: 18)
                : null,
          ),
        ),
      ],
    ),
  );
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => _Panel(
    child: Column(
      children: [
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    ),
  );
}
