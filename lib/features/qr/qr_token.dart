import '../../core/config/app_config.dart';

/// An opaque, regenerable QR token pointing at one physical scan location.
///
/// The token itself carries no database identifiers; it is 128 bits of random
/// hex minted server-side. Only [resolveQrToken] on the backend can turn it
/// back into a business, stall, or table.
class QrToken {
  const QrToken({
    required this.id,
    required this.businessId,
    required this.scope,
    required this.token,
    required this.status,
    required this.createdAt,
    this.stallId,
    this.diningTableId,
    this.regeneratedAt,
  });

  factory QrToken.fromJson(Map<String, dynamic> json) => QrToken(
    id: json['id'] as String,
    businessId: json['business_id'] as String,
    scope: json['scope'] as String,
    token: json['token'] as String,
    status: json['status'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    stallId: json['stall_id'] as String?,
    diningTableId: json['dining_table_id'] as String?,
    regeneratedAt: json['regenerated_at'] == null
        ? null
        : DateTime.parse(json['regenerated_at'] as String),
  );

  final String id;
  final String businessId;
  final String scope;
  final String token;
  final String status;
  final DateTime createdAt;
  final String? stallId;
  final String? diningTableId;
  final DateTime? regeneratedAt;

  bool get isActive => status == 'active';

  /// Placeholder scan destination. The customer-facing Next.js app that serves
  /// this path does not exist yet; see [AppConfig.qrScanBaseUrl].
  String get scanUrl => AppConfig.qrScanUrl(token);

  /// Key used to pair a token with the table or stall it belongs to.
  String get targetKey => diningTableId ?? stallId ?? businessId;
}

enum QrScope {
  table('table'),
  stall('stall'),
  business('business');

  const QrScope(this.value);
  final String value;
}
