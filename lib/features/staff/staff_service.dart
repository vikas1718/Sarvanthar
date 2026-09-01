import 'package:supabase_flutter/supabase_flutter.dart';

import 'staff_models.dart';

class StaffService {
  const StaffService(this._client);
  final SupabaseClient _client;
  Future<List<StaffMember>> loadStaff(String businessId) async {
    final rows = await _client.rpc<List<dynamic>>(
      'list_business_staff',
      params: {'p_business_id': businessId},
    );
    return rows
        .map((e) => StaffMember.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<PendingInvitation>> loadInvitations(String businessId) async {
    final rows = await _client
        .from('staff_invitations')
        .select(
          'id, recipient_email, recipient_phone, role, expires_at, stall_id, stalls(name)',
        )
        .eq('business_id', businessId)
        .eq('status', 'invited')
        .isFilter('accepted_at', null)
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows)
        .map(PendingInvitation.fromJson)
        .toList();
  }

  Future<CreatedInvitation> invite({
    required String businessId,
    required String? stallId,
    required String role,
    required String? email,
    required String? phone,
  }) async {
    final rows = await _client.rpc<List<dynamic>>(
      'create_staff_invitation',
      params: {
        'p_business_id': businessId,
        'p_stall_id': stallId,
        'p_role': role,
        'p_email': email,
        'p_phone': phone,
        'p_expires_in': '7 days',
      },
    );
    final invitation = CreatedInvitation.fromJson(
      Map<String, dynamic>.from(rows.first as Map),
    );
    return invitation;
  }

  Future<void> revoke(String businessId, String invitationId) => _client.rpc(
    'revoke_staff_invitation',
    params: {'p_business_id': businessId, 'p_invitation_id': invitationId},
  );

  Future<EmailInvitation?> loadMyPendingEmailInvitation() async {
    try {
      final rows = await _client.rpc<List<dynamic>>(
        'get_my_pending_email_invitation',
      );
      if (rows.isNotEmpty) {
        return EmailInvitation.fromJson(
          Map<String, dynamic>.from(rows.first as Map),
        );
      }
    } catch (_) {
      // Fall through to the recipient-scoped table lookup below.
    }

    final email = _client.auth.currentUser?.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) return null;
    final row = await _client
        .from('staff_invitations')
        .select('id, role, business_id, stall_id, created_at')
        .eq('recipient_email', email)
        .eq('status', 'invited')
        .isFilter('accepted_at', null)
        .gt('expires_at', DateTime.now().toIso8601String())
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    return EmailInvitation(
      id: row['id'] as String,
      businessName: 'your restaurant',
      ownerName: 'The restaurant owner',
      role: row['role'] as String,
    );
  }

  Future<void> decideMyEmailInvitation(String invitationId, bool accept) =>
      _client.rpc(
        'decide_my_email_invitation',
        params: {'p_invitation_id': invitationId, 'p_accept': accept},
      );

  Future<void> disable(String businessId, StaffMember member) =>
      member.scope == 'business'
      ? _client.rpc(
          'disable_business_staff',
          params: {'p_business_id': businessId, 'p_user_id': member.userId},
        )
      : _client.rpc(
          'disable_stall_staff',
          params: {
            'p_business_id': businessId,
            'p_stall_id': member.stallId,
            'p_user_id': member.userId,
          },
        );
  Future<InvitationPreview> preview(String token) async {
    final rows = await _client.rpc<List<dynamic>>(
      'get_staff_invitation',
      params: {'p_token': token},
    );
    return InvitationPreview.fromJson(
      Map<String, dynamic>.from(rows.first as Map),
    );
  }

  Future<void> redeem(String token) =>
      _client.rpc('redeem_staff_invitation', params: {'p_token': token});
}
