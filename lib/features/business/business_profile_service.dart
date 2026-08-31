import 'package:supabase_flutter/supabase_flutter.dart';

import 'business_profile.dart';

class BusinessProfileService {
  const BusinessProfileService(this._client);

  final SupabaseClient _client;

  Future<BusinessProfile> load(String businessId) async {
    final row = await _client
        .from('businesses')
        .select(
          'id, name, type, logo_url, phone, email, address, currency, tax_percentage',
        )
        .eq('id', businessId)
        .single();
    return BusinessProfile.fromJson(row);
  }

  Future<BusinessProfile> update({
    required String businessId,
    required String? logoUrl,
    required String? phone,
    required String? email,
    required String? address,
    required String currency,
    required double? taxPercentage,
  }) async {
    final row = await _client.rpc<Map<String, dynamic>>(
      'update_business_profile',
      params: {
        'p_business_id': businessId,
        'p_logo_url': logoUrl,
        'p_phone': phone,
        'p_email': email,
        'p_address': address,
        'p_currency': currency,
        'p_tax_percentage': taxPercentage,
      },
    );
    return BusinessProfile.fromJson(row);
  }
}
