part of '../../main.dart';

/// Owner/manager surface for minting the opaque QR tokens guests scan.
///
/// The codes rendered here point at [AppConfig.qrScanBaseUrl], a placeholder
/// origin for the customer-facing app that does not exist yet. Only the origin
/// is a placeholder: the tokens are real and already resolvable through
/// `resolve_qr_token`, so nothing printed today has to be reissued when the
/// scan destination ships.
class QrManagementPage extends StatefulWidget {
  const QrManagementPage({
    super.key,
    required this.businessId,
    required this.businessName,
    required this.isFoodCourt,
    required this.role,
    required this.stallId,
  });

  final String businessId, businessName, role;
  final bool isFoodCourt;

  /// Set for a stall-scoped manager, who may only mint their own stall's code.
  final String? stallId;

  @override
  State<QrManagementPage> createState() => _QrManagementPageState();
}

class _QrManagementPageState extends State<QrManagementPage> {
  late final QrService _service;
  List<DiningTable> _tables = const [];
  List<Stall> _stalls = const [];
  Map<String, QrToken> _tokens = const {};
  final Set<String> _busy = <String>{};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = QrService(Supabase.instance.client);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final client = Supabase.instance.client;
    try {
      final tables = await TableService(client).load(widget.businessId);
      final stalls = widget.isFoodCourt
          ? await StallService(client).loadForBusiness(widget.businessId)
          : const <Stall>[];
      final tokens = await _service.loadActive(widget.businessId);
      if (!mounted) return;
      setState(() {
        _tables = tables;
        _stalls = widget.stallId == null
            ? stalls.where((stall) => stall.isActive).toList()
            : stalls.where((stall) => stall.id == widget.stallId).toList();
        _tokens = {
          for (final token in tokens) token.targetKey: token,
        };
        _loading = false;
      });
    } on PostgrestException catch (error) {
      if (mounted) {
        setState(() {
          _error = _qrError(error);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not load QR codes.';
          _loading = false;
        });
      }
    }
  }

  Future<QrToken?> _generate({
    required QrScope scope,
    required String targetKey,
    String? stallId,
    String? diningTableId,
  }) async {
    setState(() => _busy.add(targetKey));
    try {
      final token = await _service.generate(
        businessId: widget.businessId,
        scope: scope,
        stallId: stallId,
        diningTableId: diningTableId,
      );
      if (mounted) {
        setState(() => _tokens = {..._tokens, token.targetKey: token});
      }
      return token;
    } on PostgrestException catch (error) {
      if (mounted) _showError(_qrError(error));
      return null;
    } catch (_) {
      if (mounted) _showError('Could not create that QR code.');
      return null;
    } finally {
      if (mounted) setState(() => _busy.remove(targetKey));
    }
  }

  Future<void> _open(_QrTarget target) async {
    var token = _tokens[target.key];
    if (token == null) {
      token = await _generate(
        scope: target.scope,
        targetKey: target.key,
        stallId: target.stallId,
        diningTableId: target.diningTableId,
      );
      if (token == null || !mounted) return;
    }
    await showDialog<void>(
      context: context,
      builder: (_) => _QrPreviewDialog(
        target: target,
        token: token!,
        businessName: widget.businessName,
        onRegenerate: () => _regenerate(target),
      ),
    );
  }

  /// Returns the replacement token so the open preview can swap to it, or null
  /// if the manager backed out of the warning.
  Future<QrToken?> _regenerate(_QrTarget target) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Regenerate this QR code?'),
        content: Text(
          'The current code for ${target.label} stops working immediately. '
          'Anything already printed or displayed becomes unscannable, and '
          'guests using it will be told to ask staff for the new one.\n\n'
          'Only regenerate if the old code has been copied, misused, or moved '
          'to a different spot.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep current code'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xffb3261e),
              foregroundColor: Colors.white,
            ),
            child: const Text('Regenerate and invalidate'),
          ),
        ],
      ),
    );
    if (confirmed != true) return null;
    final token = await _generate(
      scope: target.scope,
      targetKey: target.key,
      stallId: target.stallId,
      diningTableId: target.diningTableId,
    );
    if (token != null && mounted) {
      _showError('New code issued. Reprint and replace the old one.');
    }
    return token;
  }

  void _showError(String message) => _notice(context, message);

  List<_QrTarget> get _tableTargets => _tables
      .map(
        (table) => _QrTarget(
          key: table.id,
          scope: QrScope.table,
          label: 'Table ${table.number}',
          detail:
              '${table.capacity} seats · ${table.type == 'outdoor' ? 'Outdoor' : 'Indoor'}',
          icon: table.type == 'outdoor'
              ? Icons.deck_outlined
              : Icons.table_restaurant_outlined,
          diningTableId: table.id,
          inactive: !table.isActive,
        ),
      )
      .toList();

  List<_QrTarget> get _counterTargets => widget.isFoodCourt
      ? _stalls
            .map(
              (stall) => _QrTarget(
                key: stall.id,
                scope: QrScope.stall,
                label: stall.name,
                detail: 'Counter and takeaway orders',
                icon: Icons.storefront_outlined,
                stallId: stall.id,
                inactive: !stall.isActive,
              ),
            )
            .toList()
      : [
          _QrTarget(
            key: widget.businessId,
            scope: QrScope.business,
            label: widget.businessName.isEmpty
                ? 'Counter'
                : '${widget.businessName} counter',
            detail: 'Counter and takeaway orders',
            icon: Icons.point_of_sale_outlined,
          ),
        ];

  @override
  Widget build(BuildContext context) => _PageShell(
    title: 'QR Codes',
    subtitle: 'Mint the codes guests scan to reach your menu.',
    action: OutlinedButton.icon(
      onPressed: _loading ? null : _load,
      icon: const Icon(Icons.refresh_rounded, size: 18),
      label: const Text('Refresh'),
    ),
    child: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(
            child: Column(
              children: [
                Text(_error!),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _QrDestinationNotice(),
              const SizedBox(height: 22),
              _QrSection(
                title: 'Dine-in tables',
                caption:
                    'One code per table. Scanning tells us which table the order came from.',
                targets: _tableTargets,
                busy: _busy,
                tokens: _tokens,
                onOpen: _open,
                emptyMessage:
                    'No tables yet. Add tables first, then mint their codes.',
              ),
              const SizedBox(height: 26),
              _QrSection(
                title: widget.isFoodCourt
                    ? 'Stall counters'
                    : 'Counter and takeaway',
                caption: widget.isFoodCourt
                    ? 'One code per stall for guests ordering at the counter.'
                    : 'A single code for walk-up and takeaway orders.',
                targets: _counterTargets,
                busy: _busy,
                tokens: _tokens,
                onOpen: _open,
                emptyMessage:
                    'No active stalls yet. Add a stall to mint its counter code.',
              ),
            ],
          ),
  );
}

/// One physical thing a QR code can point at.
class _QrTarget {
  const _QrTarget({
    required this.key,
    required this.scope,
    required this.label,
    required this.detail,
    required this.icon,
    this.stallId,
    this.diningTableId,
    this.inactive = false,
  });

  final String key;
  final QrScope scope;
  final String label, detail;
  final IconData icon;
  final String? stallId, diningTableId;
  final bool inactive;
}

class _QrDestinationNotice extends StatelessWidget {
  const _QrDestinationNotice();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xfffff1df),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xffffd9a8)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline_rounded, color: Color(0xffa35809)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Scan destination is not live yet',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xffa35809),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Codes point at ${AppConfig.qrScanBaseUrl}/scan/…, which is a '
                'placeholder until the guest ordering site ships. The codes '
                'themselves are final — only the web address changes, so you '
                'will not need to reprint anything.',
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _QrSection extends StatelessWidget {
  const _QrSection({
    required this.title,
    required this.caption,
    required this.targets,
    required this.busy,
    required this.tokens,
    required this.onOpen,
    required this.emptyMessage,
  });

  final String title, caption, emptyMessage;
  final List<_QrTarget> targets;
  final Set<String> busy;
  final Map<String, QrToken> tokens;
  final ValueChanged<_QrTarget> onOpen;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 2),
      Text(caption),
      const SizedBox(height: 14),
      if (targets.isEmpty)
        _Panel(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Center(child: Text(emptyMessage)),
          ),
        )
      else
        LayoutBuilder(
          builder: (_, constraints) {
            final columns = constraints.maxWidth >= 980
                ? 3
                : constraints.maxWidth >= 640
                ? 2
                : 1;
            final width =
                (constraints.maxWidth - (14 * (columns - 1))) / columns;
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: targets
                  .map(
                    (target) => SizedBox(
                      width: width,
                      child: _QrTargetCard(
                        target: target,
                        token: tokens[target.key],
                        busy: busy.contains(target.key),
                        onOpen: () => onOpen(target),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
    ],
  );
}

class _QrTargetCard extends StatelessWidget {
  const _QrTargetCard({
    required this.target,
    required this.token,
    required this.busy,
    required this.onOpen,
  });

  final _QrTarget target;
  final QrToken? token;
  final bool busy;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final issued = token != null;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xfffff1db),
                child: Icon(target.icon, color: _amber),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      target.label,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(target.detail),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (issued)
            Center(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _line),
                ),
                child: QrImageView(
                  data: token!.scanUrl,
                  size: 96,
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.white,
                ),
              ),
            )
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 22),
                child: Icon(
                  Icons.qr_code_2_rounded,
                  size: 60,
                  color: _line,
                ),
              ),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              _QrStatePill(issued: issued, inactive: target.inactive),
              const Spacer(),
              if (busy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                FilledButton.icon(
                  onPressed: onOpen,
                  icon: Icon(
                    issued ? Icons.print_outlined : Icons.qr_code_rounded,
                    size: 17,
                  ),
                  label: Text(issued ? 'View & print' : 'Generate'),
                  style: _primaryStyle(),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QrStatePill extends StatelessWidget {
  const _QrStatePill({required this.issued, required this.inactive});

  final bool issued, inactive;

  @override
  Widget build(BuildContext context) {
    final (label, background, foreground) = switch ((issued, inactive)) {
      (true, true) => ('Target inactive', const Color(0xfffff1df), const Color(0xffa35809)),
      (true, false) => ('Code ready', const Color(0xffeaf7ef), const Color(0xff39825c)),
      _ => ('Not generated', const Color(0xfff1f2f4), _muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _QrPreviewDialog extends StatefulWidget {
  const _QrPreviewDialog({
    required this.target,
    required this.token,
    required this.businessName,
    required this.onRegenerate,
  });

  final _QrTarget target;
  final QrToken token;
  final String businessName;
  final Future<QrToken?> Function() onRegenerate;

  @override
  State<_QrPreviewDialog> createState() => _QrPreviewDialogState();
}

class _QrPreviewDialogState extends State<_QrPreviewDialog> {
  late QrToken _token;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _token = widget.token;
  }

  Future<Uint8List> _buildPdf() async {
    final document = pw.Document(title: '${widget.target.label} QR code');
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        build: (context) => pw.Padding(
          padding: const pw.EdgeInsets.all(28),
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                widget.businessName,
                style: pw.TextStyle(fontSize: 14, letterSpacing: 1.4),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                widget.target.label,
                style: pw.TextStyle(
                  fontSize: 30,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 22),
              // Vector barcode rather than a rasterised widget, so the print
              // stays crisp at any paper size.
              pw.BarcodeWidget(
                data: _token.scanUrl,
                barcode: pw.Barcode.qrCode(),
                width: 230,
                height: 230,
                drawText: false,
              ),
              pw.SizedBox(height: 22),
              pw.Text('Scan to see the menu and order'),
              pw.SizedBox(height: 10),
              pw.Text(
                _token.scanUrl,
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              ),
            ],
          ),
        ),
      ),
    );
    return document.save();
  }

  Future<void> _run(Future<void> Function() action, String failure) async {
    setState(() => _working = true);
    try {
      await action();
    } catch (_) {
      if (mounted) _notice(context, failure);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _print() => _run(
    () async => Printing.layoutPdf(
      onLayout: (_) => _buildPdf(),
      name: '${widget.target.label} QR code',
    ),
    'Could not open the print dialog.',
  );

  Future<void> _download() => _run(
    () async => Printing.sharePdf(
      bytes: await _buildPdf(),
      filename:
          '${widget.target.label.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '-')}-qr.pdf',
    ),
    'Could not save the PDF.',
  );

  Future<void> _regenerate() async {
    final replacement = await widget.onRegenerate();
    if (replacement != null && mounted) setState(() => _token = replacement);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.target.label),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _line),
              ),
              child: QrImageView(
                data: _token.scanUrl,
                size: 216,
                padding: EdgeInsets.zero,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xfffbfaf8),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _line),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      _token.scanUrl,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy link',
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: _token.scanUrl),
                      );
                      if (context.mounted) _notice(context, 'Link copied.');
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _token.regeneratedAt == null
                    ? 'Issued ${_qrDate(_token.createdAt)}'
                    : 'Reissued ${_qrDate(_token.regeneratedAt!)}',
                style: const TextStyle(fontSize: 12, color: _muted),
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton.icon(
        onPressed: _working ? null : _regenerate,
        icon: const Icon(Icons.autorenew_rounded, size: 18),
        label: const Text('Regenerate'),
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xffb3261e),
        ),
      ),
      const Spacer(),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
      OutlinedButton.icon(
        onPressed: _working ? null : _download,
        icon: const Icon(Icons.download_rounded, size: 18),
        label: const Text('Download'),
      ),
      FilledButton.icon(
        onPressed: _working ? null : _print,
        icon: const Icon(Icons.print_rounded, size: 18),
        label: const Text('Print'),
        style: _primaryStyle(),
      ),
    ],
  );
}

String _qrDate(DateTime value) {
  final local = value.toLocal();
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${local.day} ${months[local.month - 1]} ${local.year}';
}

String _qrError(PostgrestException error) {
  const safe = {
    'QR code management requires owner or manager access',
    'Dining table not found or archived',
    'Dining table belongs to a different business',
    'Stall QR codes exist only under food court businesses',
    'Another QR code for this target was just created. Reload and try again.',
  };
  if (safe.contains(error.message)) return error.message;
  if (error.code == '42883' || error.code == 'PGRST202') {
    return 'QR codes are unavailable until the approved migration is applied.';
  }
  if (error.code == '42P01') {
    return 'QR codes are unavailable until the approved migration is applied.';
  }
  return 'Could not update the QR code. Please try again.';
}
