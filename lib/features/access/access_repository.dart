import 'package:supabase_flutter/supabase_flutter.dart';

import 'access_models.dart';

class AccessRepository {
  AccessRepository(this._client);
  final SupabaseClient _client;

  Future<List<BusinessAccess>> loadAccess() async {
    final direct = await _client
        .from('business_memberships')
        .select('role, businesses!inner(id, name, type, logo_url, is_deleted)')
        .eq('status', 'active');
    final stall = await _client
        .from('stall_memberships')
        .select(
          'role, stalls!inner(id, name, businesses!inner(id, name, type, is_deleted))',
        )
        .eq('status', 'active');

    final results = <BusinessAccess>[];
    for (final row in List<Map<String, dynamic>>.from(direct)) {
      final business = Map<String, dynamic>.from(row['businesses'] as Map);
      if (business['is_deleted'] == true) continue;
      results.add(
        BusinessAccess(
          businessId: business['id'] as String,
          businessName: business['name'] as String,
          businessType: business['type'] as String,
          businessLogoUrl: business['logo_url'] as String?,
          role: row['role'] as String,
        ),
      );
    }
    for (final row in List<Map<String, dynamic>>.from(stall)) {
      final stallData = Map<String, dynamic>.from(row['stalls'] as Map);
      final business = Map<String, dynamic>.from(
        stallData['businesses'] as Map,
      );
      if (business['is_deleted'] == true) continue;
      results.add(
        BusinessAccess(
          businessId: business['id'] as String,
          businessName: business['name'] as String,
          businessType: business['type'] as String,
          businessLogoUrl: business['logo_url'] as String?,
          role: row['role'] as String,
          stallId: stallData['id'] as String,
          stallName: stallData['name'] as String,
        ),
      );
    }
    return results;
  }
}
