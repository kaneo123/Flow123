import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flowtill/models/outlet.dart';
import 'package:flowtill/models/staff.dart';

/// Navigation items available in the app
enum NavigationItem {
  till,
  orderHistory,
  reporting,
  adjustments,
  stockAdjustments,
  endOfDay,
  tableLayout,
  settings,
}

/// Provider for managing app navigation and drawer state
/// Follows MVVM pattern - manages state for navigation drawer
class NavigationProvider extends ChangeNotifier {
  bool _isDrawerOpen = false;
  bool _isDrawerCollapsed = true; // Start collapsed (auto-hide on load)
  NavigationItem _currentItem = NavigationItem.till;
  Outlet? _currentOutlet;
  Staff? _loggedInStaff;
  bool _isOnline = true;
  bool _isSyncing = false;

  // Getters
  bool get isDrawerOpen => _isDrawerOpen;
  bool get isDrawerCollapsed => _isDrawerCollapsed;
  NavigationItem get currentItem => _currentItem;
  Outlet? get currentOutlet => _currentOutlet;
  Staff? get loggedInStaff => _loggedInStaff;
  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;

  /// Open the navigation drawer
  void openDrawer() {
    _isDrawerOpen = true;
    notifyListeners();
  }

  /// Close the navigation drawer
  void closeDrawer() {
    _isDrawerOpen = false;
    notifyListeners();
  }

  /// Toggle drawer open/close state
  void toggleDrawer() {
    _isDrawerOpen = !_isDrawerOpen;
    notifyListeners();
  }

  /// Toggle drawer collapsed state (for large screens)
  void toggleDrawerCollapsed() {
    _isDrawerCollapsed = !_isDrawerCollapsed;
    notifyListeners();
  }

  /// Set drawer collapsed state
  void setDrawerCollapsed(bool collapsed) {
    _isDrawerCollapsed = collapsed;
    notifyListeners();
  }

  /// Set the current navigation item
  void setCurrentItem(NavigationItem item) {
    _currentItem = item;
    notifyListeners();
  }

  /// Set the current outlet
  /// Uses post-frame callback to avoid setState during build
  void setCurrentOutlet(Outlet? outlet) {
    _currentOutlet = outlet;
    
    // Schedule notification for after current frame to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  /// Set the logged-in staff member
  /// Uses post-frame callback to avoid setState during build
  void setLoggedInStaff(Staff? staff) {
    _loggedInStaff = staff;
    
    // Schedule notification for after current frame to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  /// Set online/offline status
  void setOnlineStatus(bool isOnline) {
    _isOnline = isOnline;
    notifyListeners();
  }

  /// Set syncing status
  void setSyncingStatus(bool isSyncing) {
    _isSyncing = isSyncing;
    notifyListeners();
  }

  /// Perform logout action
  void logout() {
    _loggedInStaff = null;
    notifyListeners();
  }

  /// Get display name for navigation item
  String getNavigationItemLabel(NavigationItem item) {
    switch (item) {
      case NavigationItem.till:
        return 'Till';
      case NavigationItem.orderHistory:
        return 'Order History';
      case NavigationItem.reporting:
        return 'Reporting';
      case NavigationItem.adjustments:
        return 'Till Adjustments';
      case NavigationItem.stockAdjustments:
        return 'Stock Adjustments';
      case NavigationItem.endOfDay:
        return 'End of Day';
      case NavigationItem.tableLayout:
        return 'Table Layout';
      case NavigationItem.settings:
        return 'Settings';
    }
  }

  /// Get icon for navigation item
  IconData getNavigationItemIcon(NavigationItem item) {
    switch (item) {
      case NavigationItem.till:
        return Icons.point_of_sale;
      case NavigationItem.orderHistory:
        return Icons.history;
      case NavigationItem.reporting:
        return Icons.bar_chart;
      case NavigationItem.adjustments:
        return Icons.account_balance_wallet;
      case NavigationItem.stockAdjustments:
        return Icons.inventory_2;
      case NavigationItem.endOfDay:
        return Icons.event_available;
      case NavigationItem.tableLayout:
        return Icons.table_bar;
      case NavigationItem.settings:
        return Icons.settings_outlined;
    }
  }
}
