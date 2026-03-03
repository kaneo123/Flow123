import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Monitors network connectivity and provides online/offline status
class ConnectionService {
  static final ConnectionService _instance = ConnectionService._internal();
  factory ConnectionService() => _instance;
  ConnectionService._internal();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  
  bool _isOnline = true;
  StreamSubscription? _subscription;

  /// Stream of connection status changes (true = online, false = offline)
  Stream<bool> get connectionStream => _connectionController.stream;

  /// Current connection status
  bool get isOnline => _isOnline;

  /// Initialize connection monitoring
  Future<void> initialize() async {
    // Check initial connectivity
    final result = await _connectivity.checkConnectivity();
    _updateConnectionStatus(result.first);

    // Listen for connectivity changes
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      if (results.isNotEmpty) {
        _updateConnectionStatus(results.first);
      }
    });

    debugPrint('🌐 ConnectionService initialized. Status: ${_isOnline ? "Online" : "Offline"}');
  }

  void _updateConnectionStatus(ConnectivityResult result) {
    final wasOnline = _isOnline;
    _isOnline = result != ConnectivityResult.none;

    if (wasOnline != _isOnline) {
      debugPrint('🌐 Connection status changed: ${_isOnline ? "Online ✅" : "Offline ❌"}');
      _connectionController.add(_isOnline);
    }
  }

  /// Dispose of resources
  void dispose() {
    _subscription?.cancel();
    _connectionController.close();
  }
}
