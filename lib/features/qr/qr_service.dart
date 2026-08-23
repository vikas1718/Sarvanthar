import 'package:supabase_flutter/supabase_flutter.dart';

import 'qr_token.dart';

class QrService {
  const QrService(this._client);

  final SupabaseClient _client;

  static const _columns =
      'id,business_id,stall_id,dining_table_id,scope,token,status,'
      'created_at,regenerated_at';

  /// Active tokens for a business. RLS narrows this to the scopes the caller
  /// may manage, so a stall manager never sees another stall's token.
  Future<List<QrToken>> loadActive(String businessId) async {
    final rows = await _client
        .from('qr_tokens')
        .select(_columns)
        .eq('business_id', businessId)
        .eq('status', 'active');
    return List<Map<String, dynamic>>.from(rows).map(QrToken.fromJson).toList();
  }

  /// Mints a token, or replaces the target's existing one.
  ///
  /// Regenerating revokes the previous token in the same transaction, so any
  /// QR already printed stops resolving the moment this returns.
  Future<QrToken> generate({
    required String businessId,
    required QrScope scope,
    String? stallId,
    String? diningTableId,
  }) async {
    final row = await _client.rpc<Map<String, dynamic>>(
      'generate_qr_token',
      params: {
        'p_business_id': businessId,
        'p_scope': scope.value,
        'p_stall_id': stallId,
        'p_dining_table_id': diningTableId,
      },
    );
    return QrToken.fromJson(row);
  }
}
