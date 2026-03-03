import 'package:flutter/foundation.dart';
import 'package:flowtill/models/trading_day.dart';
import 'package:flowtill/services/trading_day_service.dart';

/// Provider for managing trading day state
class TradingDayProvider with ChangeNotifier {
  final _tradingDayService = TradingDayService();

  TradingDay? _currentTradingDay;
  bool _isLoading = false;
  String? _error;

  TradingDay? get currentTradingDay => _currentTradingDay;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasTradingDay => _currentTradingDay != null && _currentTradingDay!.isOpen;

  /// Load the current trading day for an outlet
  Future<void> loadCurrentTradingDay(String outletId) async {
    debugPrint('📅 TradingDayProvider: loadCurrentTradingDay called for outlet: $outletId');
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _tradingDayService.getCurrentTradingDay(outletId);
    
    if (result.isSuccess) {
      _currentTradingDay = result.data;
      _error = null;
      
      if (_currentTradingDay != null) {
        debugPrint('✅ TradingDayProvider: Trading day loaded: ${_currentTradingDay!.isOpen ? "OPEN" : "CLOSED"}');
        debugPrint('   Trading day ID: ${_currentTradingDay!.id}');
        debugPrint('   Closed At: ${_currentTradingDay!.closedAt}');
        debugPrint('   hasTradingDay (getter): $hasTradingDay');
      } else {
        debugPrint('✅ TradingDayProvider: No trading day found (null)');
        debugPrint('   hasTradingDay (getter): $hasTradingDay');
        debugPrint('   → Start of Day modal SHOULD be shown');
      }
    } else {
      _error = result.error;
      debugPrint('❌ TradingDayProvider: Failed to load trading day: $_error');
      debugPrint('   hasTradingDay (getter): $hasTradingDay');
    }

    _isLoading = false;
    notifyListeners();
    debugPrint('📅 TradingDayProvider: loadCurrentTradingDay completed');
  }

  /// Check if we should start a new trading day based on operating hours
  Future<bool> shouldStartNewTradingDay(String outletId, String? operatingHoursOpen) async {
    final result = await _tradingDayService.shouldStartNewTradingDay(outletId, operatingHoursOpen);
    return result.isSuccess ? (result.data ?? true) : true;
  }

  /// Get suggested opening float from last closed trading day
  Future<double> getSuggestedOpeningFloat(String outletId) async {
    final result = await _tradingDayService.getLastClosedTradingDay(outletId);
    
    if (result.isSuccess && result.data != null) {
      final lastDay = result.data!;
      final carryForward = lastDay.carryForwardCash ?? 0.0;
      debugPrint('💰 TradingDayProvider: Suggested float from last day: £${carryForward.toStringAsFixed(2)}');
      return carryForward;
    }

    debugPrint('💰 TradingDayProvider: No previous day found, suggesting £0.00');
    return 0.0;
  }

  /// Get last day's variance for informational display
  Future<double?> getLastDayVariance(String outletId) async {
    final result = await _tradingDayService.getLastClosedTradingDay(outletId);
    
    if (result.isSuccess && result.data != null) {
      return result.data!.cashVariance;
    }

    return null;
  }

  /// Start a new trading day
  Future<bool> startTradingDay({
    required String outletId,
    required String staffId,
    required double openingFloat,
    required String floatSource,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _tradingDayService.startTradingDay(
      outletId: outletId,
      staffId: staffId,
      openingFloat: openingFloat,
      floatSource: floatSource,
    );

    if (result.isSuccess) {
      _currentTradingDay = result.data;
      _error = null;
      _isLoading = false;
      notifyListeners();
      debugPrint('✅ TradingDayProvider: Trading day started successfully');
      return true;
    } else {
      _error = result.error;
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ TradingDayProvider: Failed to start trading day: $_error');
      return false;
    }
  }

  /// End the current trading day
  Future<bool> endTradingDay({
    required String staffId,
    required double closingCashCounted,
    required double totalCashSales,
    required double totalCardSales,
    required double totalSales,
    required bool carryForward,
    double? customCarryForwardAmount,
  }) async {
    if (_currentTradingDay == null) {
      _error = 'No trading day to close';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _tradingDayService.endTradingDay(
      tradingDayId: _currentTradingDay!.id,
      staffId: staffId,
      closingCashCounted: closingCashCounted,
      totalCashSales: totalCashSales,
      totalCardSales: totalCardSales,
      totalSales: totalSales,
      carryForward: carryForward,
      customCarryForwardAmount: customCarryForwardAmount,
    );

    if (result.isSuccess) {
      _currentTradingDay = result.data;
      _error = null;
      _isLoading = false;
      notifyListeners();
      debugPrint('✅ TradingDayProvider: Trading day ended successfully');
      return true;
    } else {
      _error = result.error;
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ TradingDayProvider: Failed to end trading day: $_error');
      return false;
    }
  }

  /// Clear the current trading day (for logout/outlet switch)
  void clear() {
    _currentTradingDay = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}
