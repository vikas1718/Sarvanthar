part of '../../main.dart';

const _navy = Color(0xff172033);
const _amber = Color(0xffe78b20);
const _cream = Color(0xfffff9f2);
const _line = Color(0xffe9e1d5);
const _muted = Color(0xff6f7682);

class ConfigurationErrorPage extends StatelessWidget {
  const ConfigurationErrorPage({super.key, required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Brand(),
                const SizedBox(height: 28),
                Text(
                  'Configuration needed',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                Text(message, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    ),
  );
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
