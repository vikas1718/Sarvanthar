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
    return CreatedInvitation.fromJson(
      Map<String, dynamic>.from(rows.first as Map),
    );
  }

  Future<void> revoke(String businessId, String invitationId) => _client.rpc(
    'revoke_staff_invitation',
    params: {'p_business_id': businessId, 'p_invitation_id': invitationId},
  );

  /// Emails an invited teammate a secure passwordless sign-in link
  /// (Supabase magic link / OTP) addressed to [email].
  ///
  /// When they open the link and sign in, [redeemCurrentUserInvitation] grants
  /// the role the invitation carries, matched by their verified email address.
  Future<void> sendInvitationEmail(String email) =>
      _client.auth.signInWithOtp(email: email, shouldCreateUser: true);

  /// Applies any pending invitation addressed to the signed-in user's email,
  /// granting the role it carries. Safe to call on every sign-in: it does
  /// nothing when no matching invitation exists.
  Future<void> redeemCurrentUserInvitation() =>
      _client.rpc('redeem_current_staff_invitation');

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
