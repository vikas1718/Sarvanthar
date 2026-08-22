part of '../../main.dart';

class BusinessSelectPage extends StatelessWidget {
  const BusinessSelectPage({
    super.key,
    required this.access,
    required this.onSelect,
    required this.onLogout,
  });
  final List<BusinessAccess> access;
  final ValueChanged<BusinessAccess> onSelect;
  final VoidCallback onLogout;
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
                const Brand(),
                const SizedBox(height: 54),
                Text(
                  'Choose a workspace.',
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(fontSize: 38),
                ),
                const SizedBox(height: 10),
                const Text(
                  'You have access to more than one business. Select the one you want to open.',
                ),
                const SizedBox(height: 26),
                ...access.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => onSelect(item),
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            border: Border.all(color: _line),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                item.isFoodCourt
                                    ? Icons.storefront_rounded
                                    : Icons.restaurant_rounded,
                                color: _amber,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.businessName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    Text(
                                      item.isFoodCourt
                                          ? 'Food court'
                                          : 'Restaurant',
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                color: _amber,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: TextButton(
                    onPressed: onLogout,
                    child: const Text('Log out'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
