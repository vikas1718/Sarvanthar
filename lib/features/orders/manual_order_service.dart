import 'package:supabase_flutter/supabase_flutter.dart';

class ManualOrderService {
  const ManualOrderService(this._client);

  final SupabaseClient _client;

  Future<String> submit({
    required String tableId,
    required String? stallId,
    required String requestId,
    required List<Map<String, dynamic>> items,
  }) async {
    return await _client.rpc<String>(
      'create_manual_order',
      params: {
        'p_table_id': tableId,
        'p_stall_id': stallId,
        'p_client_request_id': requestId,
        'p_items': items,
      },
    );
  }
}
