import 'package:supabase_flutter/supabase_flutter.dart';

import 'dining_table.dart';

class TableService {
  const TableService(this._client);

  final SupabaseClient _client;

  Future<List<DiningTable>> load(String businessId) async {
    final rows = await _client
        .from('dining_tables')
        .select('id,business_id,table_number,capacity,status,type')
        .eq('business_id', businessId)
        .isFilter('archived_at', null)
        .order('table_number');
    return List<Map<String, dynamic>>.from(rows)
        .map(DiningTable.fromJson)
        .toList();
  }

  Future<DiningTable> save({
    DiningTable? table,
    required String businessId,
    required String number,
    required int capacity,
    required String type,
  }) async {
    final row = await _client.rpc<Map<String, dynamic>>(
      table == null ? 'create_dining_table' : 'update_dining_table',
      params: {
        'p_business_id': businessId,
        if (table != null) 'p_table_id': table.id,
        'p_table_number': number,
        'p_capacity': capacity,
        'p_type': type,
      },
    );
    return DiningTable.fromJson(row);
  }

  Future<DiningTable> setStatus({
    required String businessId,
    required DiningTable table,
    required bool active,
  }) async {
    final row = await _client.rpc<Map<String, dynamic>>(
      'set_dining_table_status',
      params: {
        'p_business_id': businessId,
        'p_table_id': table.id,
        'p_status': active ? 'active' : 'inactive',
      },
    );
    return DiningTable.fromJson(row);
  }

  Future<void> archive({required String businessId, required String tableId}) =>
      _client.rpc(
        'archive_dining_table',
        params: {'p_business_id': businessId, 'p_table_id': tableId},
      );
}
