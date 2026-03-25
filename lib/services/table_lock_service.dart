import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flowtill/models/table_session.dart';
import 'package:flowtill/services/device_identification_service.dart';
import 'package:flowtill/supabase/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Service for managing table/tab session locks with real-time awareness
/// 
/// Platform-aware behavior:
/// - WEB: Direct Supabase operations for table_sessions (real-time, heartbeat, etc)
/// - DEVICE: Deferred/no-op behavior to avoid FK violations with local-first orders
/// 
/// Implements a hybrid soft-locking approach:
/// - Sessions track who has a table/tab open
/// - Real-time updates notify when someone else opens the same table
/// - Heartbeat mechanism auto-expires stale sessions
/// - Users can "take over" if needed with confirmation
class TableLockService {
  static final TableLockService _instance = TableLockService._internal();
  factory TableLockService() => _instance;
  TableLockService._internal();

  final _uuid = const Uuid();
  Timer? _heartbeatTimer;
  String? _currentSessionId;
  RealtimeChannel? _realtimeChannel;
  
  /// Callback for when another user opens the current order
  Function(TableSession)? onOtherUserOpened;
  
  /// Callback for when another user updates the current order
  Function(TableSession)? onOtherUserUpdated;
  
  /// Callback for when another user closes their session
  Function(String sessionId)? onOtherUserClosed;

  /// Start a new session for an order/table
  /// Returns the created session or null if failed
  /// 
  /// Platform-aware behavior:
  /// - WEB: Creates table_session in Supabase immediately
  /// - DEVICE: Defers table_session creation to avoid FK violations with local-first orders
  Future<TableSession?> startSession({
    required String outletId,
    required String orderId,
    String? tableId,
    required String staffId,
    required String staffName,
  }) async {
    if (kIsWeb) {
      // WEB: Direct Supabase insert
      return _startSessionWeb(
        outletId: outletId,
        orderId: orderId,
        tableId: tableId,
        staffId: staffId,
        staffName: staffName,
      );
    } else {
      // DEVICE: Defer session creation to avoid FK violations
      // Table sessions will be created during sync after parent order exists in cloud
      debugPrint('[TABLE_SESSION_SYNC] Device: Deferring table_session creation (local-first order)');
      debugPrint('[TABLE_SESSION_SYNC]    Order: $orderId');
      debugPrint('[TABLE_SESSION_SYNC]    Table: $tableId');
      debugPrint('[TABLE_SESSION_SYNC]    Reason: Parent order may only exist locally, FK violation risk');
      
      // For device builds, we just track the session locally in memory
      // Real-time locking/heartbeat not needed for device builds (single-device operation)
      _currentSessionId = null; // No remote session ID on device
      return null; // Session creation deferred
    }
  }
  
  /// WEB ONLY: Create table_session in Supabase
  Future<TableSession?> _startSessionWeb({
    required String outletId,
    required String orderId,
    String? tableId,
    required String staffId,
    required String staffName,
  }) async {
    try {
      debugPrint('[TABLE_SESSION_SYNC] Web: Creating table_session in Supabase');
      debugPrint('[TABLE_SESSION_SYNC]    Order: $orderId');
      
      final deviceId = await DeviceIdentificationService.instance.getDeviceId();
      final now = DateTime.now();
      
      final sessionData = {
        'outlet_id': outletId,
        'order_id': orderId,
        'table_id': tableId,
        'staff_id': staffId,
        'staff_name': staffName,
        'device_id': deviceId,
        'session_started_at': now.toIso8601String(),
        'last_heartbeat_at': now.toIso8601String(),
        'is_active': true,
      };

      final result = await SupabaseService.insert('table_sessions', sessionData);
      
      if (!result.isSuccess || result.data == null || result.data!.isEmpty) {
        debugPrint('[TABLE_SESSION_SYNC] ❌ Failed to create session: ${result.error}');
        return null;
      }

      final session = TableSession.fromJson(result.data!.first);
      _currentSessionId = session.id;
      
      // Start heartbeat timer (every 30 seconds)
      _startHeartbeat();
      
      // Subscribe to real-time updates for this order
      _subscribeToOrderSessions(orderId, staffId);
      
      debugPrint('[TABLE_SESSION_SYNC] ✅ Session created: ${session.id}');
      return session;
    } catch (e, stackTrace) {
      debugPrint('[TABLE_SESSION_SYNC] ❌ Error creating session: $e');
      return null;
    }
  }

  /// Update heartbeat to keep session alive
  /// Only active on web builds where real-time sessions are created
  Future<void> _updateHeartbeat() async {
    if (!kIsWeb || _currentSessionId == null) return;

    try {
      await SupabaseService.update(
        'table_sessions',
        {
          'last_heartbeat_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        filters: {'id': _currentSessionId!},
      );
    } catch (e) {
      // Silently fail heartbeat
    }
  }

  /// Start periodic heartbeat updates
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _updateHeartbeat();
    });
  }

  /// End the current session
  /// Only active on web builds where real-time sessions exist
  Future<void> endSession() async {
    if (!kIsWeb || _currentSessionId == null) return;

    try {
      debugPrint('[TABLE_SESSION_SYNC] Ending session: $_currentSessionId');
      
      await SupabaseService.update(
        'table_sessions',
        {
          'is_active': false,
          'updated_at': DateTime.now().toIso8601String(),
        },
        filters: {'id': _currentSessionId!},
      );
      
      _currentSessionId = null;
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
      _unsubscribeFromRealtime();
      
      debugPrint('[TABLE_SESSION_SYNC] ✅ Session ended');
    } catch (e) {
      debugPrint('[TABLE_SESSION_SYNC] ⚠️ Error ending session: $e');
    }
  }

  /// Get all active sessions for an order
  /// Only functional on web builds
  Future<List<TableSession>> getActiveSessionsForOrder(String orderId) async {
    if (!kIsWeb) {
      debugPrint('[TABLE_SESSION_SYNC] Device: Skipping session query (not applicable for device builds)');
      return [];
    }
    
    try {
      final result = await SupabaseService.select(
        'table_sessions',
        filters: {'order_id': orderId, 'is_active': true},
        orderBy: 'session_started_at',
        ascending: true,
      );

      if (!result.isSuccess || result.data == null) {
        return [];
      }

      final sessions = result.data!
          .map((json) => TableSession.fromJson(json))
          .where((s) => !s.isStale) // Filter out stale sessions
          .toList();
      
      return sessions;
    } catch (e) {
      return [];
    }
  }

  /// Get other users currently on this order (excluding current user)
  Future<List<TableSession>> getOtherActiveSessions(String orderId, String currentStaffId) async {
    final allSessions = await getActiveSessionsForOrder(orderId);
    return allSessions.where((s) => s.staffId != currentStaffId).toList();
  }

  /// Take over - end other sessions and start a new one
  /// Only functional on web builds
  Future<TableSession?> takeOver({
    required String outletId,
    required String orderId,
    String? tableId,
    required String staffId,
    required String staffName,
  }) async {
    if (!kIsWeb) {
      debugPrint('[TABLE_SESSION_SYNC] Device: Skipping takeover (not applicable for device builds)');
      return null;
    }
    
    try {
      debugPrint('[TABLE_SESSION_SYNC] Taking over sessions for order: $orderId');
      
      // End all other active sessions for this order
      await SupabaseService.update(
        'table_sessions',
        {
          'is_active': false,
          'updated_at': DateTime.now().toIso8601String(),
        },
        filters: {'order_id': orderId, 'is_active': true},
      );
      
      // Start new session
      return await startSession(
        outletId: outletId,
        orderId: orderId,
        tableId: tableId,
        staffId: staffId,
        staffName: staffName,
      );
    } catch (e) {
      debugPrint('[TABLE_SESSION_SYNC] ❌ Error during takeover: $e');
      return null;
    }
  }

  /// Subscribe to real-time updates for an order's sessions
  /// Only active on web builds
  void _subscribeToOrderSessions(String orderId, String currentStaffId) {
    if (!kIsWeb) return; // Real-time not needed on device builds
    
    _unsubscribeFromRealtime();
    
    try {
      final supabase = Supabase.instance.client;
      
      _realtimeChannel = supabase
          .channel('table_sessions_$orderId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'table_sessions',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'order_id',
              value: orderId,
            ),
            callback: (payload) {
              final session = TableSession.fromJson(payload.newRecord);
              
              // Only notify if it's not the current staff
              if (session.staffId != currentStaffId) {
                onOtherUserOpened?.call(session);
              }
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'table_sessions',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'order_id',
              value: orderId,
            ),
            callback: (payload) {
              final session = TableSession.fromJson(payload.newRecord);
              
              // Only notify if it's not the current staff and session became inactive
              if (session.staffId != currentStaffId) {
                if (!session.isActive) {
                  onOtherUserClosed?.call(session.id);
                } else {
                  onOtherUserUpdated?.call(session);
                }
              }
            },
          )
          .subscribe();
    } catch (e) {
      // Silently fail subscription
    }
  }

  /// Unsubscribe from real-time updates
  void _unsubscribeFromRealtime() {
    if (_realtimeChannel != null) {
      Supabase.instance.client.removeChannel(_realtimeChannel!);
      _realtimeChannel = null;
    }
  }

  /// Cleanup stale sessions (can be called periodically)
  Future<void> cleanupStaleSessions() async {
    try {
      await SupabaseService.update(
        'table_sessions',
        {
          'is_active': false,
          'updated_at': DateTime.now().toIso8601String(),
        },
        filters: {
          'is_active': true,
        },
      );
    } catch (e) {
      // Silently fail
    }
  }

  /// Dispose resources
  void dispose() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _unsubscribeFromRealtime();
    _currentSessionId = null;
  }
}
