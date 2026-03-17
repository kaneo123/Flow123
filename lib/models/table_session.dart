import 'package:flowtill/utils/sqlite_converters.dart';

/// Represents an active session where a staff member has a table/tab open
class TableSession {
  final String id;
  final String outletId;
  final String orderId;
  final String? tableId;
  final String? staffId;
  final String staffName;
  final String? deviceId;
  final DateTime sessionStartedAt;
  final DateTime lastHeartbeatAt;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  TableSession({
    required this.id,
    required this.outletId,
    required this.orderId,
    this.tableId,
    this.staffId,
    required this.staffName,
    this.deviceId,
    required this.sessionStartedAt,
    required this.lastHeartbeatAt,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  TableSession copyWith({
    String? id,
    String? outletId,
    String? orderId,
    String? tableId,
    String? staffId,
    String? staffName,
    String? deviceId,
    DateTime? sessionStartedAt,
    DateTime? lastHeartbeatAt,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => TableSession(
    id: id ?? this.id,
    outletId: outletId ?? this.outletId,
    orderId: orderId ?? this.orderId,
    tableId: tableId ?? this.tableId,
    staffId: staffId ?? this.staffId,
    staffName: staffName ?? this.staffName,
    deviceId: deviceId ?? this.deviceId,
    sessionStartedAt: sessionStartedAt ?? this.sessionStartedAt,
    lastHeartbeatAt: lastHeartbeatAt ?? this.lastHeartbeatAt,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'outlet_id': outletId,
    'order_id': orderId,
    'table_id': tableId,
    'staff_id': staffId,
    'staff_name': staffName,
    'device_id': deviceId,
    'session_started_at': sessionStartedAt.toIso8601String(),
    'last_heartbeat_at': lastHeartbeatAt.toIso8601String(),
    'is_active': isActive,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory TableSession.fromJson(Map<String, dynamic> json) => TableSession(
    id: json['id'] as String,
    outletId: json['outlet_id'] as String,
    orderId: json['order_id'] as String,
    tableId: json['table_id'] as String?,
    staffId: json['staff_id'] as String?,
    staffName: json['staff_name'] as String,
    deviceId: json['device_id'] as String?,
    sessionStartedAt: SQLiteConverters.toDateTime(json['session_started_at']) ?? DateTime.now(),
    lastHeartbeatAt: SQLiteConverters.toDateTime(json['last_heartbeat_at']) ?? DateTime.now(),
    isActive: SQLiteConverters.toBool(json['is_active']) ?? true,
    createdAt: SQLiteConverters.toDateTime(json['created_at']) ?? DateTime.now(),
    updatedAt: SQLiteConverters.toDateTime(json['updated_at']) ?? DateTime.now(),
  );

  /// Check if this session is stale (no heartbeat in last 5 minutes)
  bool get isStale {
    final now = DateTime.now();
    final difference = now.difference(lastHeartbeatAt);
    return difference.inMinutes >= 5;
  }

  /// Get a human-readable time since session started
  String get timeSinceStarted {
    final now = DateTime.now();
    final difference = now.difference(sessionStartedAt);
    
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }
}
