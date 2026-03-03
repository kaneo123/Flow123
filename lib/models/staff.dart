class Staff {
  final String id;
  final String fullName;
  final String? roleId;
  final int? _permissionLevel;
  final String pinCode;
  final String outletId;
  final bool active;
  final DateTime? lastLoginAt;
  final DateTime createdAt;
  
  /// Get permission level, defaulting to 1 if not set
  int get permissionLevel => _permissionLevel ?? 1;

  /// List of outlet IDs this staff member is associated with
  final List<String>? associatedOutletIds;

  Staff({
    required this.id,
    required this.fullName,
    this.roleId,
    int? permissionLevel,
    required this.pinCode,
    required this.outletId,
    this.active = true,
    this.lastLoginAt,
    DateTime? createdAt,
    this.associatedOutletIds,
  }) : _permissionLevel = permissionLevel,
       createdAt = createdAt ?? DateTime.now();

  factory Staff.fromJson(Map<String, dynamic> json) {
    return Staff(
      id: json['id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      roleId: json['role_id'] as String?,
      permissionLevel: json['permission_level'] as int?,
      pinCode: json['pin_code'] as String? ?? '',
      outletId: json['outlet_id'] as String? ?? '',
      active: json['active'] as bool? ?? true,
      lastLoginAt: json['last_login_at'] != null
          ? DateTime.parse(json['last_login_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      associatedOutletIds: json['associated_outlet_ids'] != null
          ? List<String>.from(json['associated_outlet_ids'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'full_name': fullName,
    'role_id': roleId,
    'permission_level': _permissionLevel,
    'pin_code': pinCode,
    'outlet_id': outletId,
    'active': active,
    'last_login_at': lastLoginAt?.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
    'associated_outlet_ids': associatedOutletIds,
  };

  Staff copyWith({
    String? id,
    String? fullName,
    String? roleId,
    int? permissionLevel,
    String? pinCode,
    String? outletId,
    bool? active,
    DateTime? lastLoginAt,
    DateTime? createdAt,
    List<String>? associatedOutletIds,
  }) => Staff(
    id: id ?? this.id,
    fullName: fullName ?? this.fullName,
    roleId: roleId ?? this.roleId,
    permissionLevel: permissionLevel ?? this.permissionLevel,
    pinCode: pinCode ?? this.pinCode,
    outletId: outletId ?? this.outletId,
    active: active ?? this.active,
    lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    createdAt: createdAt ?? this.createdAt,
    associatedOutletIds: associatedOutletIds ?? this.associatedOutletIds,
  );
}
