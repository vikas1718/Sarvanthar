class StaffMember {
  const StaffMember({
    required this.scope,
    required this.userId,
    required this.name,
    required this.role,
    required this.status,
    this.email,
    this.phone,
    this.stallId,
    this.stallName,
  });
  factory StaffMember.fromJson(Map<String, dynamic> j) => StaffMember(
    scope: j['membership_type'] as String,
    userId: j['user_id'] as String,
    name: j['full_name'] as String? ?? 'Team member',
    email: j['email'] as String?,
    phone: j['phone'] as String?,
    role: j['role'] as String,
    status: j['status'] as String,
    stallId: j['stall_id'] as String?,
    stallName: j['stall_name'] as String?,
  );
  final String scope, userId, name, role, status;
  final String? email, phone, stallId, stallName;
}

class PendingInvitation {
  const PendingInvitation({
    required this.id,
    required this.role,
    required this.expiresAt,
    this.email,
    this.phone,
    this.stallId,
    this.stallName,
  });
  factory PendingInvitation.fromJson(Map<String, dynamic> j) {
    final stall = j['stalls'] as Map<String, dynamic>?;
    return PendingInvitation(
      id: j['id'] as String,
      email: j['recipient_email'] as String?,
      phone: j['recipient_phone'] as String?,
      role: j['role'] as String,
      expiresAt: DateTime.parse(j['expires_at'] as String),
      stallId: j['stall_id'] as String?,
      stallName: stall?['name'] as String?,
    );
  }
  final String id, role;
  final String? email, phone, stallId, stallName;
  final DateTime expiresAt;
}

class CreatedInvitation {
  const CreatedInvitation({required this.token, required this.expiresAt});
  factory CreatedInvitation.fromJson(Map<String, dynamic> j) =>
      CreatedInvitation(
        token: j['token'] as String,
        expiresAt: DateTime.parse(j['expires_at'] as String),
      );
  final String token;
  final DateTime expiresAt;
}

class InvitationPreview {
  const InvitationPreview({
    required this.businessName,
    required this.role,
    required this.expiresAt,
    this.stallName,
  });
  factory InvitationPreview.fromJson(Map<String, dynamic> j) =>
      InvitationPreview(
        businessName: j['business_name'] as String,
        stallName: j['stall_name'] as String?,
        role: j['role'] as String,
        expiresAt: DateTime.parse(j['expires_at'] as String),
      );
  final String businessName, role;
  final String? stallName;
  final DateTime expiresAt;
}
