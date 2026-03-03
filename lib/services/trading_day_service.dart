import 'package:flutter/foundation.dart';
import 'package:flowtill/models/trading_day.dart';
import 'package:flowtill/services/outlet_service.dart';
import 'package:flowtill/supabase/supabase_config.dart';
import 'package:uuid/uuid.dart';

/// Service for managing trading day operations
class TradingDayService {
  final _uuid = const Uuid();

  /// Get the current open trading day for an outlet
  Future<ServiceResult<TradingDay?>> getCurrentTradingDay(String outletId) async {
    try {
      // Query for trading days where closed_at is null (still open)
      // Note: Using .not() with .eq() is not supported, so we filter manually
      final allDays = await SupabaseConfig.client
          .from('trading_days')
          .select('*')
          .eq('outlet_id', outletId)
          .order('opened_at', ascending: false)
          .limit(10);

      // Filter for open days (closed_at is null)
      final openDays = (allDays as List)
          .where((day) => day['closed_at'] == null)
          .toList();

      if (openDays.isEmpty) {
        return ServiceResult.success(null);
      }

      final response = openDays.first;

      if (response == null) {
        return ServiceResult.success(null);
      }

      final tradingDay = TradingDay.fromJson(response);
      return ServiceResult.success(tradingDay);
    } catch (e, stackTrace) {
      return ServiceResult.failure('Failed to get current trading day: ${e.toString()}');
    }
  }

  /// Check if we need to start a new trading day based on operating hours
  /// Returns true if we should show the Start of Day modal
  Future<ServiceResult<bool>> shouldStartNewTradingDay(
    String outletId,
    String? operatingHoursOpen,
  ) async {
    try {
      // Get the current/last trading day
      final allDays = await SupabaseConfig.client
          .from('trading_days')
          .select('*')
          .eq('outlet_id', outletId)
          .order('opened_at', ascending: false)
          .limit(1);

      final now = DateTime.now();
      
      // If no trading days exist at all, we need to start one
      if ((allDays as List).isEmpty) {
        return ServiceResult.success(true);
      }

      final lastDay = TradingDay.fromJson((allDays as List).first);
      
      // If there's an open trading day, check if it's still valid for today
      if (lastDay.isOpen) {
        // If no operating hours set, keep the existing trading day open
        if (operatingHoursOpen == null) {
          return ServiceResult.success(false);
        }

        // Check if we've crossed into a new trading day
        final shouldStartNew = _isNewTradingDayNeeded(lastDay.tradingDate, now, operatingHoursOpen);
        if (shouldStartNew) {
          return ServiceResult.success(true);
        }

        return ServiceResult.success(false);
      }

      // Trading day is closed - check if we need to start a new one
      if (operatingHoursOpen == null) {
        // No operating hours set - require manual start
        return ServiceResult.success(true);
      }

      // Check if we've passed the opening hours since the last trading day
      final shouldStartNew = _isNewTradingDayNeeded(lastDay.tradingDate, now, operatingHoursOpen);
      if (shouldStartNew) {
        return ServiceResult.success(true);
      }

      return ServiceResult.success(false);
    } catch (e, stackTrace) {
      return ServiceResult.failure('Failed to check for new trading day: ${e.toString()}');
    }
  }

  /// Determine if a new trading day is needed based on operating hours
  bool _isNewTradingDayNeeded(DateTime lastTradingDate, DateTime now, String openingHours) {
    try {
      // Parse opening hours (e.g., "10:00")
      final parts = openingHours.split(':');
      if (parts.length != 2) return true; // Invalid format, require new day
      
      final openHour = int.parse(parts[0]);
      final openMinute = int.parse(parts[1]);

      // Calculate the "trading day" date based on opening hours
      // If current time is before opening hours, we're still in yesterday's trading day
      DateTime currentTradingDate;
      if (now.hour < openHour || (now.hour == openHour && now.minute < openMinute)) {
        // Before opening hours - we're in yesterday's trading day
        currentTradingDate = DateTime(now.year, now.month, now.day - 1);
      } else {
        // After opening hours - we're in today's trading day
        currentTradingDate = DateTime(now.year, now.month, now.day);
      }

      // Compare dates (ignoring time)
      final lastDate = DateTime(
        lastTradingDate.year,
        lastTradingDate.month,
        lastTradingDate.day,
      );
      
      final needsNew = currentTradingDate.isAfter(lastDate);
      
      return needsNew;
    } catch (e) {
      return true; // On error, require new day to be safe
    }
  }

  /// Get the last closed trading day for carry-forward suggestion
  Future<ServiceResult<TradingDay?>> getLastClosedTradingDay(String outletId) async {
    try {
      final response = await SupabaseConfig.client
          .from('trading_days')
          .select('*')
          .eq('outlet_id', outletId)
          .not('closed_at', 'is', null)
          .order('closed_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        return ServiceResult.success(null);
      }

      final tradingDay = TradingDay.fromJson(response);
      return ServiceResult.success(tradingDay);
    } catch (e) {
      return ServiceResult.failure('Failed to get last closed trading day: ${e.toString()}');
    }
  }

  /// Start a new trading day
  Future<ServiceResult<TradingDay>> startTradingDay({
    required String outletId,
    required String staffId,
    required double openingFloat,
    required String floatSource,
  }) async {
    try {
      // Check if there's already an open trading day
      final currentResult = await getCurrentTradingDay(outletId);
      if (!currentResult.isSuccess) {
        return ServiceResult.failure(currentResult.error ?? 'Failed to check for existing trading day');
      }

      if (currentResult.data != null) {
        return ServiceResult.failure('A trading day is already open for this outlet');
      }

      final tradingDay = TradingDay(
        id: _uuid.v4(),
        outletId: outletId,
        tradingDate: DateTime.now(),
        openedAt: DateTime.now(),
        openedByStaffId: staffId,
        openingFloatAmount: openingFloat,
        openingFloatSource: floatSource,
      );

      final response = await SupabaseConfig.client
          .from('trading_days')
          .insert(tradingDay.toJson())
          .select()
          .single();

      final created = TradingDay.fromJson(response);
      return ServiceResult.success(created);
    } catch (e) {
      return ServiceResult.failure('Failed to start trading day: ${e.toString()}');
    }
  }

  /// End the current trading day
  Future<ServiceResult<TradingDay>> endTradingDay({
    required String tradingDayId,
    required String staffId,
    required double closingCashCounted,
    required double totalCashSales,
    required double totalCardSales,
    required double totalSales,
    required bool carryForward,
    double? customCarryForwardAmount,
  }) async {
    try {
      // Get the current trading day to calculate variance
      final currentResult = await _getTradingDayById(tradingDayId);
      if (!currentResult.isSuccess || currentResult.data == null) {
        return ServiceResult.failure('Trading day not found');
      }

      final current = currentResult.data!;
      
      // Calculate expected cash (opening float + cash sales)
      final expectedCash = current.openingFloatAmount + totalCashSales;
      final cashVariance = closingCashCounted - expectedCash;
      
      // Determine carry forward amount
      final carryForwardCash = carryForward 
          ? (customCarryForwardAmount ?? closingCashCounted)
          : 0.0;

      final updates = {
        'closed_at': DateTime.now().toIso8601String(),
        'closed_by_staff_id': staffId,
        'closing_cash_counted': closingCashCounted,
        'cash_variance': cashVariance,
        'carry_forward_cash': carryForwardCash,
        'is_carry_forward': carryForward,
        'total_cash_sales': totalCashSales,
        'total_card_sales': totalCardSales,
        'total_sales': totalSales,
      };

      final response = await SupabaseConfig.client
          .from('trading_days')
          .update(updates)
          .eq('id', tradingDayId)
          .select()
          .single();

      final updated = TradingDay.fromJson(response);
      return ServiceResult.success(updated);
    } catch (e) {
      return ServiceResult.failure('Failed to end trading day: ${e.toString()}');
    }
  }

  /// Get trading day by ID
  Future<ServiceResult<TradingDay?>> _getTradingDayById(String id) async {
    try {
      final response = await SupabaseConfig.client
          .from('trading_days')
          .select('*')
          .eq('id', id)
          .maybeSingle();

      if (response == null) {
        return ServiceResult.success(null);
      }

      final tradingDay = TradingDay.fromJson(response);
      return ServiceResult.success(tradingDay);
    } catch (e) {
      return ServiceResult.failure('Failed to get trading day: ${e.toString()}');
    }
  }

  /// Get trading days for a date range (for reporting)
  Future<ServiceResult<List<TradingDay>>> getTradingDays({
    required String outletId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  }) async {
    try {
      var query = SupabaseConfig.client
          .from('trading_days')
          .select('*')
          .eq('outlet_id', outletId);

      if (startDate != null) {
        query = query.gte('trading_date', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('trading_date', endDate.toIso8601String());
      }

      final response = await query
          .order('trading_date', ascending: false)
          .limit(limit);

      final tradingDays = (response as List)
          .map((json) => TradingDay.fromJson(json))
          .toList();

      return ServiceResult.success(tradingDays);
    } catch (e) {
      return ServiceResult.failure('Failed to get trading days: ${e.toString()}');
    }
  }
}
