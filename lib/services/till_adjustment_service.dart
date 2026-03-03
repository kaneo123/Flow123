import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import '../models/till_adjustment.dart';
import '../database/app_database.dart';
import 'connection_service.dart';

class TillAdjustmentService {
  static final TillAdjustmentService _instance = TillAdjustmentService._internal();
  factory TillAdjustmentService() => _instance;
  TillAdjustmentService._internal();

  final _supabase = Supabase.instance.client;
  final _uuid = const Uuid();

  /// Create a new till adjustment (online-first)
  Future<TillAdjustment> createAdjustment({
    required String outletId,
    required String staffId,
    required double amount,
    required String type,
    required String reason,
    String? notes,
  }) async {
    final adjustment = TillAdjustment(
      id: _uuid.v4(),
      outletId: outletId,
      staffId: staffId,
      timestamp: DateTime.now(),
      amountPennies: (amount * 100).round(),
      adjustmentType: type,
      reason: reason,
      notes: notes,
    );

    final isOnline = await ConnectionService().isOnline;

    if (isOnline) {
      try {
        await _supabase.from('till_adjustments').insert(adjustment.toJson());

        // Cache to local DB
        if (!kIsWeb) {
          await _saveToLocalDb(adjustment);
        }
        return adjustment;
      } catch (e) {
        if (!kIsWeb) {
          await _saveToLocalDb(adjustment);
          return adjustment;
        }
        rethrow;
      }
    } else {
      // Offline - save to local DB
      if (!kIsWeb) {
        await _saveToLocalDb(adjustment);
        return adjustment;
      } else {
        throw Exception('Cannot create adjustments offline on web');
      }
    }
  }

  /// Fetch adjustments for an outlet and date range (online-first)
  Future<List<TillAdjustment>> fetchAdjustments({
    required String outletId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final isOnline = await ConnectionService().isOnline;

    if (isOnline) {
      try {
        // Build query with filters
        final response = await _supabase
            .from('till_adjustments')
            .select()
            .eq('outlet_id', outletId)
            .gte('timestamp', startDate?.toIso8601String() ?? '2020-01-01')
            .lte('timestamp', endDate?.toIso8601String() ?? DateTime.now().toIso8601String())
            .order('timestamp', ascending: false);
        final adjustments = (response as List)
            .map((json) => TillAdjustment.fromJson(json))
            .toList();

        // Cache to local DB
        if (!kIsWeb && adjustments.isNotEmpty) {
          await _cacheAdjustmentsToLocalDb(adjustments);
        }

        return adjustments;
      } catch (e) {
        if (!kIsWeb) {
          return _fetchFromLocalDb(outletId, startDate, endDate);
        }
        rethrow;
      }
    } else {
      // Offline - fetch from local DB
      if (!kIsWeb) {
        return _fetchFromLocalDb(outletId, startDate, endDate);
      } else {
        throw Exception('Cannot fetch adjustments offline on web');
      }
    }
  }

  /// Delete an adjustment (online-first)
  Future<void> deleteAdjustment(String adjustmentId) async {
    final isOnline = await ConnectionService().isOnline;

    if (isOnline) {
      try {
        await _supabase.from('till_adjustments').delete().eq('id', adjustmentId);

        // Delete from local DB
        if (!kIsWeb) {
          await _deleteFromLocalDb(adjustmentId);
        }
      } catch (e) {
        if (!kIsWeb) {
          await _deleteFromLocalDb(adjustmentId);
        } else {
          rethrow;
        }
      }
    } else {
      // Offline - delete from local DB
      if (!kIsWeb) {
        await _deleteFromLocalDb(adjustmentId);
      } else {
        throw Exception('Cannot delete adjustments offline on web');
      }
    }
  }

  // ===== LOCAL DB OPERATIONS =====

  Future<void> _saveToLocalDb(TillAdjustment adjustment) async {
    final db = await AppDatabase.instance.database;
    await db.insert(
      'till_adjustments',
      adjustment.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _cacheAdjustmentsToLocalDb(List<TillAdjustment> adjustments) async {
    final db = await AppDatabase.instance.database;
    final batch = db.batch();
    for (var adjustment in adjustments) {
      batch.insert(
        'till_adjustments',
        adjustment.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<TillAdjustment>> _fetchFromLocalDb(
    String outletId,
    DateTime? startDate,
    DateTime? endDate,
  ) async {
    final db = await AppDatabase.instance.database;
    var query = 'SELECT * FROM till_adjustments WHERE outlet_id = ?';
    final args = <dynamic>[outletId];

    if (startDate != null) {
      query += ' AND timestamp >= ?';
      args.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      query += ' AND timestamp <= ?';
      args.add(endDate.toIso8601String());
    }

    query += ' ORDER BY timestamp DESC';

    final results = await db.rawQuery(query, args);
    final adjustments = results.map((json) => TillAdjustment.fromJson(json)).toList();
    return adjustments;
  }

  Future<void> _deleteFromLocalDb(String adjustmentId) async {
    final db = await AppDatabase.instance.database;
    await db.delete('till_adjustments', where: 'id = ?', whereArgs: [adjustmentId]);
  }
}
