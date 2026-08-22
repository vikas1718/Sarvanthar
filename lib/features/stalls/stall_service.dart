import 'package:supabase_flutter/supabase_flutter.dart';

import 'stall.dart';

class StallService {
  const StallService(this._client);

  final SupabaseClient _client;

  Future<List<Stall>> loadForBusiness(String businessId) async {
    final rows = await _client
        .from('stalls')
        .select('id, business_id, name, slug, status')
        .eq('business_id', businessId)
        .isFilter('archived_at', null)
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows).map(Stall.fromJson).toList();
  }

  Future<Stall> create({
    required String businessId,
    required String name,
    required String? slug,
  }) async {
    final row = await _client.rpc<Map<String, dynamic>>(
      'create_stall',
      params: {'p_business_id': businessId, 'p_name': name, 'p_slug': slug},
    );
    return Stall.fromJson(row);
  }

  Future<Stall> update({
    required String businessId,
    required String stallId,
    required String name,
    required String? slug,
  }) async {
    final row = await _client.rpc<Map<String, dynamic>>(
      'update_stall',
      params: {
        'p_business_id': businessId,
        'p_stall_id': stallId,
        'p_name': name,
        'p_slug': slug,
      },
    );
    return Stall.fromJson(row);
  }

  Future<Stall> setStatus({
    required String businessId,
    required String stallId,
    required bool active,
  }) async {
    final row = await _client.rpc<Map<String, dynamic>>(
      'set_stall_status',
      params: {
        'p_business_id': businessId,
        'p_stall_id': stallId,
        'p_status': active ? 'active' : 'inactive',
      },
    );
    return Stall.fromJson(row);
  }

  Future<void> archive({
    required String businessId,
    required String stallId,
  }) async {
    await _client.rpc<Map<String, dynamic>>(
      'archive_stall',
      params: {'p_business_id': businessId, 'p_stall_id': stallId},
    );
  }
}
