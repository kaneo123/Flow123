/// Represents a staff member's association with a specific outlet
/// This is a junction table model for the many-to-many relationship
class StaffOutlet {
  final String id;
  final String staffId;
  final String outletId;
  final String? roleId;
  final bool active;
  final DateTime createdAt;

  StaffOutlet({
    required this.id,
    required this.staffId,
    required this.outletId,
    this.roleId,
    this.active = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory StaffOutlet.fromJson(Map<String, dynamic> json) {
    return StaffOutlet(
      id: json['id'] as String? ?? '',
      staffId: json['staff_id'] as String? ?? '',
      outletId: json['outlet_id'] as String? ?? '',
      roleId: json['role_id'] as String?,
      active: json['active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'staff_id': staffId,
    'outlet_id': outletId,
    'role_id': roleId,
    'active': active,
    'created_at': createdAt.toIso8601String(),
  };
}
