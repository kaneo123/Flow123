import 'package:flutter/foundation.dart';
import 'package:flowtill/models/order.dart';
import 'package:flowtill/models/order_item.dart';
import 'package:flowtill/models/product.dart';
import 'package:flowtill/models/split_bill.dart';
import 'package:flowtill/models/selected_modifier.dart';
import 'package:flowtill/models/loyalty_models.dart';
import 'package:flowtill/services/order_repository_hybrid.dart';
import 'package:flowtill/services/transaction_repository_hybrid.dart';
import 'package:flowtill/services/inventory_repository.dart';
import 'package:flowtill/services/promotion_service.dart';
import 'package:flowtill/services/promotion_engine.dart';
import 'package:flowtill/services/packaged_deal_service.dart';
import 'package:flowtill/services/packaged_deal_engine.dart';
import 'package:flowtill/services/table_lock_service.dart';
import 'package:uuid/uuid.dart';

/// Callback type for logging order actions to history
typedef OrderActionLogger = Future<void> Function({
  required String actionType,
  required String actionDescription,
  Map<String, dynamic>? meta,
});

class OrderProvider with ChangeNotifier {
  final _uuid = const Uuid();
  // Cloud-first with offline failover + outbox queue
  final _orderRepository = OrderRepositoryHybrid();
  final _transactionRepository = TransactionRepositoryHybrid();
  final _inventoryRepository = InventoryRepository();
  final _promotionService = PromotionService();
  late final _promotionEngine = PromotionEngine(_promotionService);
  PackagedDealService? _packagedDealService;
  PackagedDealEngine? _packagedDealEngine;
  final _tableLockService = TableLockService();
  Order? _currentOrder;
  final List<Order> _parkedOrders = [];
  bool _serviceChargeEnabled = false;
  Map<String, Product> _productsById = {};
  SplitBill? _activeSplitBill;
  List<String> _paidSplitItemIds = [];
  final Map<String, Map<String, int>> _sentQuantitiesByOrder = {};
  
  /// Staff-specific parked orders (staff_id → their quick-service order)
  final Map<String, Order> _parkedOrdersByStaff = {};

  /// Optional callback for logging actions (set by OrderHistoryProvider)
  OrderActionLogger? onLogAction;

  Order? get currentOrder => _currentOrder;
  List<Order> get parkedOrders => _parkedOrders;
  bool get serviceChargeEnabled => _serviceChargeEnabled;
  SplitBill? get activeSplitBill => _activeSplitBill;
  List<String> get paidSplitItemIds => _paidSplitItemIds;

  /// Returns items that have not yet been sent to the kitchen for the current order
  List<OrderItem> getPendingPrintItems() {
    if (_currentOrder == null) return [];
    final order = _currentOrder!;
    final sentMap = _sentQuantitiesByOrder.putIfAbsent(order.id, () => {});

    return order.items.map((item) {
      final sentQty = sentMap[item.id] ?? 0;
      final remaining = item.quantity - sentQty;
      if (remaining <= 0) return null;
      return item.copyWith(quantity: remaining);
    }).whereType<OrderItem>().toList();
  }

  /// Marks the provided items as printed for the given order ID
  void markItemsPrinted({required String orderId, required List<OrderItem> items}) {
    final sentMap = _sentQuantitiesByOrder.putIfAbsent(orderId, () => {});
    for (final item in items) {
      // Snap to the current quantity so future prints only send new additions
      sentMap[item.id] = item.quantity;
    }
  }

  void _seedPrintedQuantities(Order order, {bool markAsSent = false}) {
    final sentMap = _sentQuantitiesByOrder.putIfAbsent(order.id, () => {});
    if (markAsSent) {
      for (final item in order.items) {
        sentMap[item.id] = item.quantity;
      }
    }
  }

  /// Load promotions for the given outlet (should be called when outlet is selected)
  Future<void> loadPromotions(String outletId) async {
    await _promotionService.loadActivePromotions(outletId);
  }

  /// Set the packaged deal service (needed for deal detection)
  void setPackagedDealService(PackagedDealService packagedDealService) {
    _packagedDealService = packagedDealService;
    _packagedDealEngine = PackagedDealEngine(packagedDealService);
    debugPrint('📦 OrderProvider: Packaged deal engine initialized');
  }

  /// Set the product catalog (needed for promotion calculation)
  void setProductCatalog(List<Product> products) {
    _productsById = {for (final p in products) p.id: p};
    debugPrint('📦 OrderProvider: Product catalog set with ${_productsById.length} products');
  }

  /// Detect and apply packaged deals to the current order
  void _applyPackagedDeals() {
    debugPrint('');
    debugPrint('🔔 📦 OrderProvider._applyPackagedDeals() CALLED 📦 🔔');
    
    if (_currentOrder == null || _currentOrder!.items.isEmpty) {
      debugPrint('   ⏭️  SKIPPING: order is null or empty');
      debugPrint('');
      return;
    }

    if (_packagedDealEngine == null) {
      debugPrint('   ⏭️  SKIPPING: packaged deal engine not initialized');
      debugPrint('');
      return;
    }

    try {
      debugPrint('   Current order ID: ${_currentOrder!.id}');
      debugPrint('   Current items in order: ${_currentOrder!.items.length}');
      debugPrint('   Products available in catalog: ${_productsById.length}');
      
      final result = _packagedDealEngine!.detectAndApplyDeals(
        order: _currentOrder!,
        productsById: _productsById,
      );

      if (result.dealsDetected) {
        debugPrint('🔔 ✅ DEALS DETECTED! Applied ${result.appliedDealIds.length} deal(s)');
        debugPrint('   Updated order to ${result.updatedItems.length} items');
        
        _currentOrder = _currentOrder!.copyWith(items: result.updatedItems);
        
        // Log action for table orders only
        if (_currentOrder!.tableNumber != null && result.appliedDealIds.isNotEmpty) {
          onLogAction?.call(
            actionType: 'packaged_deal_applied',
            actionDescription: 'Applied ${result.appliedDealIds.length} packaged deal(s)',
            meta: {'deal_ids': result.appliedDealIds},
          );
        }
      } else {
        debugPrint('🔔 ❌ NO DEALS DETECTED');
      }
      debugPrint('');
    } catch (e, stackTrace) {
      debugPrint('⚠️ OrderProvider: Failed to apply packaged deals: $e');
      debugPrint('Stack: $stackTrace');
      debugPrint('');
      // Don't fail the order - just log the error
    }
  }

  /// Recalculate promotions for the current order
  void _applyPromotions() {
    debugPrint('🎁 _applyPromotions() called');
    
    if (_currentOrder == null || _currentOrder!.items.isEmpty) {
      debugPrint('   ⏭️  Skipping: order is null or empty');
      return;
    }

    try {
      final activePromotions = _promotionService.getActivePromotionsForNow();
      debugPrint('   Active promotions: ${activePromotions.length}');
      
      if (activePromotions.isEmpty) {
        debugPrint('   No active promotions, clearing any existing');
        // Clear promotions if none are active
        if (_currentOrder!.appliedPromotions.isNotEmpty || _currentOrder!.promotionDiscount > 0) {
          _currentOrder = _currentOrder!.copyWith(
            appliedPromotions: [],
            promotionDiscount: 0.0,
          );
          debugPrint('   ✅ Cleared promotions');
        }
        return;
      }

      debugPrint('   Products in catalog: ${_productsById.length}');
      debugPrint('   Calculating promotions...');
      
      final result = _promotionEngine.calculate(
        order: _currentOrder!,
        promotions: activePromotions,
        productsById: _productsById,
      );

      debugPrint('   Result: ${result.appliedPromotions.length} promotions applied, total discount: £${result.totalDiscount.toStringAsFixed(2)}');

      _currentOrder = _currentOrder!.copyWith(
        appliedPromotions: result.appliedPromotions,
        promotionDiscount: result.totalDiscount,
      );
      
      debugPrint('   ✅ Promotions applied successfully');
    } catch (e, stackTrace) {
      debugPrint('⚠️ OrderProvider: Failed to apply promotions: $e');
      debugPrint('Stack: $stackTrace');
      // Don't fail the order - just log the error
    }
  }

  void initializeOrder(String outletId, String? staffId, {bool? autoEnableServiceCharge, double? outletServiceChargePercent}) {
    if (_currentOrder == null) {
      // Auto-enable service charge if outlet has it enabled
      final shouldEnableServiceCharge = autoEnableServiceCharge ?? false;
      final serviceChargeRate = shouldEnableServiceCharge && outletServiceChargePercent != null
          ? outletServiceChargePercent / 100.0
          : 0.0;
      
      _currentOrder = Order(
        id: _uuid.v4(),
        outletId: outletId,
        staffId: staffId,
        items: [],
        createdAt: DateTime.now(),
        serviceChargeRate: serviceChargeRate,
      );
      _serviceChargeEnabled = shouldEnableServiceCharge;
      _seedPrintedQuantities(_currentOrder!);
      
      debugPrint('🆕 OrderProvider: Initialized order with service charge: $shouldEnableServiceCharge (rate: ${(serviceChargeRate * 100).toStringAsFixed(2)}%)');
      notifyListeners();
    }
  }

  void addProduct(Product product, double taxRate, {List<SelectedModifier>? selectedModifiers}) {
    debugPrint('📦 OrderProvider.addProduct() called');
    debugPrint('   Product: ${product.name} (${product.id})');
    debugPrint('   🥩 IS CARVERY: ${product.isCarvery}');
    debugPrint('   📊 TRACK STOCK: ${product.trackStock}');
    debugPrint('   🔗 LINKED INVENTORY: ${product.linkedInventoryItemId}');
    debugPrint('   Tax Rate: ${(taxRate * 100).toStringAsFixed(1)}%');
    debugPrint('   Modifiers: ${selectedModifiers?.length ?? 0}');
    
    if (_currentOrder == null) {
      debugPrint('   ❌ ABORT: _currentOrder is NULL');
      return;
    }

    debugPrint('   Current Order ID: ${_currentOrder!.id}');
    debugPrint('   Current Items: ${_currentOrder!.items.length}');
    
    // Always add items as separate line items - combining happens only during receipt printing
    debugPrint('   🆕 Adding new item to basket');
    final newItemId = _uuid.v4();
    debugPrint('   New item ID: $newItemId');
    
    final newItem = OrderItem(
      id: newItemId,
      product: product,
      quantity: 1,
      selectedModifiers: selectedModifiers ?? [],
      taxRate: taxRate,
    );
    
    final updatedItems = List<OrderItem>.from(_currentOrder!.items)..add(newItem);
    debugPrint('   Items count: ${_currentOrder!.items.length} → ${updatedItems.length}');
    
    _currentOrder = _currentOrder!.copyWith(items: updatedItems);
    debugPrint('   ✅ Order updated with new item');
    
    // Log action for table orders only
    if (_currentOrder!.tableNumber != null) {
      final lineTotal = newItem.unitPrice;
      onLogAction?.call(
        actionType: 'item_added',
        actionDescription: 'Added 1 × ${product.name} (£${lineTotal.toStringAsFixed(2)})',
        meta: {'product_id': product.id, 'quantity': 1, 'has_modifiers': selectedModifiers?.isNotEmpty ?? false},
      );
    }
    
    debugPrint('   📦 Checking for packaged deals...');
    _applyPackagedDeals();
    debugPrint('   🎁 Applying promotions...');
    _applyPromotions();
    debugPrint('   📢 Calling notifyListeners()...');
    notifyListeners();
    debugPrint('   ✅ addProduct() complete. Final items count: ${_currentOrder!.items.length}');
  }

  /// Add a miscellaneous item with custom name and price
  void addMiscellaneousItem(String name, double price, {bool includeVat = true}) {
    debugPrint('📋 OrderProvider.addMiscellaneousItem() called');
    debugPrint('   Name: $name');
    debugPrint('   Price: £${price.toStringAsFixed(2)}');
    debugPrint('   Include VAT: $includeVat');
    
    if (_currentOrder == null) {
      debugPrint('   ❌ ABORT: _currentOrder is NULL');
      return;
    }

    // Create a temporary Product for the miscellaneous item
    // Use a unique ID with 'misc_' prefix to identify it
    final miscProduct = Product(
      id: 'misc_${_uuid.v4()}',
      name: name,
      price: price,
      outletId: _currentOrder!.outletId,
      categoryId: 'miscellaneous',
      active: true,
      trackStock: false,
      createdAt: DateTime.now(),
    );

    // Use 20% tax rate (standard UK VAT) if includeVat is true, otherwise 0%
    final taxRate = includeVat ? 0.20 : 0.0;
    
    debugPrint('   Created misc product with ID: ${miscProduct.id}');
    debugPrint('   Using tax rate: ${(taxRate * 100).toStringAsFixed(1)}%');
    
    // Add using the existing addProduct method (but always create new item, don't increment)
    final newItemId = _uuid.v4();
    final newItem = OrderItem(
      id: newItemId,
      product: miscProduct,
      quantity: 1,
      taxRate: taxRate,
    );
    
    final updatedItems = List<OrderItem>.from(_currentOrder!.items)..add(newItem);
    _currentOrder = _currentOrder!.copyWith(items: updatedItems);
    
    // Log action for table orders only
    if (_currentOrder!.tableNumber != null) {
      onLogAction?.call(
        actionType: 'misc_item_added',
        actionDescription: 'Added miscellaneous item: $name (£${price.toStringAsFixed(2)})',
        meta: {'name': name, 'price': price},
      );
    }
    
    debugPrint('   ✅ Miscellaneous item added successfully');
    _applyPackagedDeals();
    _applyPromotions();
    notifyListeners();
  }

  void removeItem(String itemId) {
    if (_currentOrder == null) return;
    
    // Find the item before removing to log details
    final removedItem = _currentOrder!.items.firstWhere((item) => item.id == itemId);
    final lineTotal = removedItem.subtotal;
    
    final updatedItems = _currentOrder!.items.where((item) => item.id != itemId).toList();
    _currentOrder = _currentOrder!.copyWith(items: updatedItems);
    
    // Log action for table orders only
    if (_currentOrder!.tableNumber != null) {
      onLogAction?.call(
        actionType: 'item_removed',
        actionDescription: 'Removed ${removedItem.quantity} × ${removedItem.product.name} (£${lineTotal.toStringAsFixed(2)})',
        meta: {'product_id': removedItem.product.id, 'quantity': removedItem.quantity},
      );
    }
    
    _applyPackagedDeals();
    _applyPromotions();
    notifyListeners();
  }

  void incrementQuantity(String itemId) {
    if (_currentOrder == null) return;
    final updatedItems = List<OrderItem>.from(_currentOrder!.items);
    final index = updatedItems.indexWhere((item) => item.id == itemId);
    if (index >= 0) {
      updatedItems[index].quantity++;
      _currentOrder = _currentOrder!.copyWith(items: updatedItems);
      _applyPackagedDeals();
      _applyPromotions();
      notifyListeners();
    }
  }

  void decrementQuantity(String itemId) {
    if (_currentOrder == null) return;
    final updatedItems = List<OrderItem>.from(_currentOrder!.items);
    final index = updatedItems.indexWhere((item) => item.id == itemId);
    if (index >= 0) {
      if (updatedItems[index].quantity > 1) {
        updatedItems[index].quantity--;
        _currentOrder = _currentOrder!.copyWith(items: updatedItems);
      } else {
        updatedItems.removeAt(index);
        _currentOrder = _currentOrder!.copyWith(items: updatedItems);
      }
      _applyPackagedDeals();
      _applyPromotions();
      notifyListeners();
    }
  }

  void updateItemNotes(String itemId, String notes) {
    if (_currentOrder == null) return;
    final updatedItems = List<OrderItem>.from(_currentOrder!.items);
    final index = updatedItems.indexWhere((item) => item.id == itemId);
    if (index >= 0) {
      updatedItems[index] = updatedItems[index].copyWith(notes: notes);
      _currentOrder = _currentOrder!.copyWith(items: updatedItems);
      
      // Log action for table orders only
      if (_currentOrder!.tableNumber != null && notes.isNotEmpty) {
        onLogAction?.call(
          actionType: 'item_note_added',
          actionDescription: 'Added note to ${updatedItems[index].product.name}: "$notes"',
          meta: {'product_id': updatedItems[index].product.id, 'notes': notes},
        );
      }
      
      notifyListeners();
    }
  }

  /// Update an order item's modifiers
  void updateItemModifiers(String itemId, List<SelectedModifier> newModifiers) {
    if (_currentOrder == null) return;
    final updatedItems = List<OrderItem>.from(_currentOrder!.items);
    final index = updatedItems.indexWhere((item) => item.id == itemId);
    if (index >= 0) {
      updatedItems[index] = updatedItems[index].copyWith(selectedModifiers: newModifiers);
      _currentOrder = _currentOrder!.copyWith(items: updatedItems);
      
      // Log action for table orders only
      if (_currentOrder!.tableNumber != null) {
        onLogAction?.call(
          actionType: 'item_modifiers_updated',
          actionDescription: 'Updated modifiers for ${updatedItems[index].product.name}',
          meta: {
            'product_id': updatedItems[index].product.id,
            'modifiers_count': newModifiers.length
          },
        );
      }
      
      // Recalculate deals and promotions as item price may have changed
      _applyPackagedDeals();
      _applyPromotions();
      notifyListeners();
    }
  }

  /// Toggle service charge (using outlet's configured percentage)
  void toggleServiceCharge(double outletServiceChargePercent) {
    debugPrint('🔄 OrderProvider.toggleServiceCharge() called');
    debugPrint('   Current enabled: $_serviceChargeEnabled');
    debugPrint('   Outlet service charge %: $outletServiceChargePercent');
    
    if (_currentOrder == null) {
      debugPrint('   ❌ ABORT: _currentOrder is NULL');
      return;
    }
    
    _serviceChargeEnabled = !_serviceChargeEnabled;
    final rate = _serviceChargeEnabled ? (outletServiceChargePercent / 100.0) : 0.0;
    
    debugPrint('   New enabled: $_serviceChargeEnabled');
    debugPrint('   Calculated rate: $rate (${(rate * 100).toStringAsFixed(2)}%)');
    debugPrint('   Current order subtotal: £${_currentOrder!.subtotal.toStringAsFixed(2)}');
    
    _currentOrder = _currentOrder!.copyWith(serviceChargeRate: rate);
    
    debugPrint('   Service charge rate in order: ${_currentOrder!.serviceChargeRate}');
    debugPrint('   Calculated service charge amount: £${_currentOrder!.serviceCharge.toStringAsFixed(2)}');
    debugPrint('   ✅ Service charge toggled successfully');
    
    notifyListeners();
  }

  /// Set service charge enabled state with outlet percentage
  void setServiceChargeEnabled(bool enabled, double outletServiceChargePercent) {
    debugPrint('📝 OrderProvider.setServiceChargeEnabled() called');
    debugPrint('   Enabled: $enabled');
    debugPrint('   Outlet service charge %: $outletServiceChargePercent');
    
    if (_currentOrder == null) {
      debugPrint('   ❌ ABORT: _currentOrder is NULL');
      return;
    }
    
    _serviceChargeEnabled = enabled;
    final rate = enabled ? (outletServiceChargePercent / 100.0) : 0.0;
    
    debugPrint('   Calculated rate: $rate (${(rate * 100).toStringAsFixed(2)}%)');
    debugPrint('   Current order subtotal: £${_currentOrder!.subtotal.toStringAsFixed(2)}');
    
    _currentOrder = _currentOrder!.copyWith(serviceChargeRate: rate);
    
    debugPrint('   Service charge rate in order: ${_currentOrder!.serviceChargeRate}');
    debugPrint('   Calculated service charge amount: £${_currentOrder!.serviceCharge.toStringAsFixed(2)}');
    debugPrint('   ✅ Service charge set successfully');
    
    notifyListeners();
  }

  void applyDiscount(double amount) {
    if (_currentOrder == null) return;
    _currentOrder = _currentOrder!.copyWith(discountAmount: amount);
    
    // Log action for table orders only
    if (_currentOrder!.tableNumber != null && amount > 0) {
      onLogAction?.call(
        actionType: 'discount_applied',
        actionDescription: 'Applied discount (£${amount.toStringAsFixed(2)})',
        meta: {'discount_amount': amount},
      );
    }
    
    notifyListeners();
  }

  void attachLoyaltyCustomer({
    required LoyaltyCustomer customer,
    String? restaurantId,
    double? pointsPreview,
  }) {
    if (_currentOrder == null) return;
    _currentOrder = _currentOrder!.copyWith(
      loyaltyCustomerId: customer.id,
      loyaltyCustomerName: customer.fullName,
      loyaltyIdentifier: customer.identifier,
      loyaltyRestaurantId: restaurantId ?? _currentOrder!.loyaltyRestaurantId,
      loyaltyPointsToAward: pointsPreview ?? _currentOrder!.loyaltyPointsToAward,
    );
    notifyListeners();
  }

  /// Apply loyalty attachment in a single update (customer, optional reward, and points)
  void applyLoyaltyAttachment({
    required LoyaltyCustomer customer,
    required double pointsToAward,
    String? restaurantId,
    LoyaltyReward? reward,
    double? discountAmount,
  }) {
    if (_currentOrder == null) return;

    final hadReward = _currentOrder!.loyaltyRewardId != null;
    final hasReward = reward != null;
    final resolvedDiscount = hasReward
        ? (discountAmount ?? 0.0)
        : (hadReward ? 0.0 : _currentOrder!.discountAmount);

    _currentOrder = _currentOrder!.copyWith(
      loyaltyCustomerId: customer.id,
      loyaltyCustomerName: customer.fullName,
      loyaltyIdentifier: customer.identifier,
      loyaltyRewardId: reward?.id,
      loyaltyRewardType: reward?.type.name,
      loyaltyRewardName: reward?.name,
      loyaltyRewardDiscountType: reward?.discountType.name,
      loyaltyRewardValue: reward?.discountValue,
      loyaltyPointsToAward: pointsToAward,
      loyaltyRestaurantId: restaurantId ?? _currentOrder!.loyaltyRestaurantId,
      discountAmount: resolvedDiscount,
    );

    notifyListeners();
  }

  void setLoyaltyReward({
    required LoyaltyReward reward,
    required double discountAmount,
    required double pointsToAward,
    String? restaurantId,
  }) {
    if (_currentOrder == null) return;

    _currentOrder = _currentOrder!.copyWith(
      discountAmount: discountAmount,
      loyaltyRewardId: reward.id,
      loyaltyRewardType: reward.type.name,
      loyaltyRewardName: reward.name,
      loyaltyRewardDiscountType: reward.discountType.name,
      loyaltyRewardValue: reward.discountValue,
      loyaltyPointsToAward: pointsToAward,
      loyaltyRestaurantId: restaurantId ?? _currentOrder!.loyaltyRestaurantId,
    );

    notifyListeners();
  }

  void setLoyaltyPoints(double points) {
    if (_currentOrder == null) return;
    _currentOrder = _currentOrder!.copyWith(loyaltyPointsToAward: points);
    notifyListeners();
  }

  void clearLoyaltyAttachment() {
    if (_currentOrder == null) return;
    _currentOrder = _currentOrder!.copyWith(
      loyaltyCustomerId: null,
      loyaltyCustomerName: null,
      loyaltyIdentifier: null,
      loyaltyRewardId: null,
      loyaltyRewardType: null,
      loyaltyRewardName: null,
      loyaltyRewardDiscountType: null,
      loyaltyRewardValue: null,
      loyaltyPointsToAward: null,
      loyaltyRestaurantId: null,
      discountAmount: 0.0,
    );
    notifyListeners();
  }

  void clearDiscount() {
    if (_currentOrder == null) return;
    
    // Log action for table orders only (if there was a discount to clear)
    if (_currentOrder!.tableNumber != null && _currentOrder!.discountAmount > 0) {
      onLogAction?.call(
        actionType: 'discount_removed',
        actionDescription: 'Removed discount (£${_currentOrder!.discountAmount.toStringAsFixed(2)})',
        meta: {'previous_discount': _currentOrder!.discountAmount},
      );
    }
    
    _currentOrder = _currentOrder!.copyWith(discountAmount: 0.0);
    notifyListeners();
  }

  void applyVoucher(double amount) {
    if (_currentOrder == null) return;
    _currentOrder = _currentOrder!.copyWith(voucherAmount: amount);
    
    // Log action for table orders only
    if (_currentOrder!.tableNumber != null && amount > 0) {
      onLogAction?.call(
        actionType: 'voucher_applied',
        actionDescription: 'Applied voucher (£${amount.toStringAsFixed(2)})',
        meta: {'voucher_amount': amount},
      );
    }
    
    notifyListeners();
  }

  void applyLoyaltyRedemption(double amount) {
    if (_currentOrder == null) return;
    _currentOrder = _currentOrder!.copyWith(loyaltyRedeemed: amount);
    
    // Log action for table orders only
    if (_currentOrder!.tableNumber != null && amount > 0) {
      onLogAction?.call(
        actionType: 'loyalty_applied',
        actionDescription: 'Applied loyalty redemption (£${amount.toStringAsFixed(2)})',
        meta: {'loyalty_amount': amount},
      );
    }
    
    notifyListeners();
  }

  void setTableNumber(String? tableNumber) {
    if (_currentOrder == null) return;
    _currentOrder = _currentOrder!.copyWith(tableNumber: tableNumber);
    notifyListeners();
  }

  void updateStaffId(String? staffId) {
    if (_currentOrder == null) return;
    debugPrint('📝 OrderProvider: Updating staff ID to: ${staffId ?? "null"}');
    _currentOrder = _currentOrder!.copyWith(staffId: staffId);
    notifyListeners();
  }

  void parkOrder({bool? autoEnableServiceCharge, double? outletServiceChargePercent}) {
    if (_currentOrder != null && _currentOrder!.items.isNotEmpty) {
      _parkedOrders.add(_currentOrder!);
      clearOrder(
        autoEnableServiceCharge: autoEnableServiceCharge,
        outletServiceChargePercent: outletServiceChargePercent,
      );
      notifyListeners();
    }
  }

  /// Park current order and persist to Supabase with status='parked'
  Future<bool> parkCurrentOrderToSupabase() async {
    if (_currentOrder == null || _currentOrder!.items.isEmpty) {
      debugPrint('⚠️ Cannot park: No order or empty order');
      return false;
    }

    try {
      debugPrint('⏸️ Parking order to Supabase: ${_currentOrder!.id}');

      // Convert in-memory Order to Supabase models
      final (eposOrder, eposItems) = _orderRepository.convertToEposModels(_currentOrder!);
      
      // Override status to 'parked'
      final parkedOrder = eposOrder.copyWith(
        status: 'parked',
        parkedAt: DateTime.now(),
      );

      // Save order + items to Supabase
      final saved = await _orderRepository.upsertOrderWithItems(parkedOrder, eposItems);
      if (!saved) {
        debugPrint('❌ Failed to park order to Supabase');
        return false;
      }

      // Log action for table orders only
      if (_currentOrder!.tableNumber != null) {
        await onLogAction?.call(
          actionType: 'order_parked',
          actionDescription: 'Order sent away (parked)',
        );
      }

      // End the session since we're parking
      await _tableLockService.endSession();

      debugPrint('✅ Order parked successfully');
      
      // Note: After parking, caller should reinitialize with outlet settings
      // For now, clear the order without any state
      _currentOrder = null;
      _serviceChargeEnabled = false;
      notifyListeners();
      
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ Error parking order: $e');
      debugPrint('Stack: $stackTrace');
      return false;
    }
  }

  /// Resume an existing order from Supabase (for table orders)
  Future<void> resumeOrderFromSupabase(String orderId, {String? staffId, String? staffName}) async {
    debugPrint('🔄 OrderProvider: Resuming order $orderId');

    try {
      // Fetch the EposOrder from Supabase
      final eposOrder = await _orderRepository.getOrderById(orderId, onlineOnly: true);
      if (eposOrder == null) {
        debugPrint('❌ Order not found: $orderId');
        return;
      }

      // Fetch order items
      final eposItems = await _orderRepository.getOrderItems(orderId, onlineOnly: true);

      // Convert to in-memory Order model
      _currentOrder = Order.fromEposModels(eposOrder, eposItems);
      _serviceChargeEnabled = _currentOrder!.serviceChargeRate > 0;
      _seedPrintedQuantities(_currentOrder!, markAsSent: true);
      
      // Start a session for this table/tab (if staff info provided)
      if (staffId != null && staffName != null) {
        await _tableLockService.startSession(
          outletId: _currentOrder!.outletId,
          orderId: _currentOrder!.id,
          tableId: _currentOrder!.tableId,
          staffId: staffId,
          staffName: staffName,
        );
      }
      
      // Recalculate promotions for resumed order
      _applyPromotions();
      
      // Log action for table orders only
      if (_currentOrder!.tableNumber != null) {
        await onLogAction?.call(
          actionType: 'order_resumed',
          actionDescription: 'Order resumed',
        );
      }
      
      debugPrint('✅ Order resumed: ${_currentOrder!.id}');
      debugPrint('   Type: ${eposOrder.orderType}');
      debugPrint('   Table: ${eposOrder.tableNumber ?? "N/A"}');
      debugPrint('   Items: ${eposItems.length}');
      
      notifyListeners();
    } catch (e, stackTrace) {
      debugPrint('❌ Error resuming order: $e');
      debugPrint('Stack: $stackTrace');
    }
  }

  /// Initialize a table order (use the order ID from Supabase)
  Future<void> initializeTableOrder({
    required String orderId,
    required String outletId,
    required String tableId,
    required String tableNumber,
    String? staffId,
    String? staffName,
    bool? autoEnableServiceCharge,
    double? outletServiceChargePercent,
  }) async {
    // Auto-enable service charge if outlet has it enabled
    final shouldEnableServiceCharge = autoEnableServiceCharge ?? false;
    final serviceChargeRate = shouldEnableServiceCharge && outletServiceChargePercent != null
        ? outletServiceChargePercent / 100.0
        : 0.0;
    
    _currentOrder = Order(
      id: orderId,
      outletId: outletId,
      staffId: staffId,
      tableId: tableId,
      tableNumber: tableNumber,
      items: [],
      createdAt: DateTime.now(),
      serviceChargeRate: serviceChargeRate,
    );
    _serviceChargeEnabled = shouldEnableServiceCharge;
    
    // Start a session for this table (if staff info provided)
    if (staffId != null && staffName != null) {
      await _tableLockService.startSession(
        outletId: outletId,
        orderId: orderId,
        tableId: tableId,
        staffId: staffId,
        staffName: staffName,
      );
    }
    _seedPrintedQuantities(_currentOrder!);
    
    debugPrint('🍽️ OrderProvider: Initialized table order for Table $tableNumber (Order ID: $orderId)');
    debugPrint('   Service charge auto-enabled: $shouldEnableServiceCharge (rate: ${(serviceChargeRate * 100).toStringAsFixed(2)}%)');
    notifyListeners();
  }

  void restoreParkedOrder(int index) {
    if (index >= 0 && index < _parkedOrders.length) {
      _currentOrder = _parkedOrders.removeAt(index);
      _serviceChargeEnabled = _currentOrder!.serviceChargeRate > 0;
      _applyPromotions();
      notifyListeners();
    }
  }

  void clearOrder({bool? autoEnableServiceCharge, double? outletServiceChargePercent}) {
    // End any active session before clearing
    _tableLockService.endSession();
    
    final oldOutletId = _currentOrder?.outletId;
    final oldStaffId = _currentOrder?.staffId;
    
    // Auto-enable service charge if outlet has it enabled
    final shouldEnableServiceCharge = autoEnableServiceCharge ?? false;
    final serviceChargeRate = shouldEnableServiceCharge && outletServiceChargePercent != null
        ? outletServiceChargePercent / 100.0
        : 0.0;
    
    // Create a completely fresh order without any table association
    _currentOrder = Order(
      id: _uuid.v4(),
      outletId: oldOutletId ?? '',
      staffId: oldStaffId,
      items: [],
      createdAt: DateTime.now(),
      serviceChargeRate: serviceChargeRate,
    );
    _serviceChargeEnabled = shouldEnableServiceCharge;
    _seedPrintedQuantities(_currentOrder!);
    _seedPrintedQuantities(_currentOrder!);
    
    debugPrint('🧹 OrderProvider: Order cleared, created fresh quick-service order (${_currentOrder!.id})');
    debugPrint('   Service charge auto-enabled: $shouldEnableServiceCharge (rate: ${(serviceChargeRate * 100).toStringAsFixed(2)}%)');
    notifyListeners();
  }

  void completeOrder({
    required String paymentMethod,
    required double amountPaid,
    double changeDue = 0.0,
  }) {
    if (_currentOrder == null) return;
    
    _currentOrder = _currentOrder!.copyWith(
      paymentMethod: paymentMethod,
      amountPaid: amountPaid,
      changeDue: changeDue,
      completedAt: DateTime.now(),
    );
    
    debugPrint('💰 Order completed: ${_currentOrder!.id}');
    debugPrint('   Status: completed');
    debugPrint('   Payment Method: $paymentMethod');
    debugPrint('   Amount Paid: £${amountPaid.toStringAsFixed(2)}');
    debugPrint('   Change Due: £${changeDue.toStringAsFixed(2)}');
    debugPrint('   Total: £${_currentOrder!.totalDue.toStringAsFixed(2)}');
    if (_currentOrder!.tableNumber != null) {
      debugPrint('   Table: ${_currentOrder!.tableNumber} (will be freed after save)');
    }
    
    notifyListeners();
  }

  /// Save completed order to Supabase (orders + order_items + transactions)
  /// Table associations are kept for history, but status='completed' frees the table
  /// Also decrements inventory for products with track_stock enabled
  Future<bool> saveCompletedOrderToSupabase({
    String? splitPaymentSummary,
    Map<String, double>? splitPayments,
  }) async {
    if (_currentOrder == null || _currentOrder!.completedAt == null) {
      debugPrint('⚠️ Cannot save: No completed order');
      return false;
    }

    try {
      debugPrint('💾 Saving completed order to Supabase: ${_currentOrder!.id}');

      // Convert in-memory Order to Supabase models with status='completed'
      final (eposOrder, eposItems) = _orderRepository.convertToEposModels(_currentOrder!);
      
      // Ensure status is 'completed' and keep table associations for history
      final completedOrder = eposOrder.copyWith(
        status: 'completed',
        completedAt: _currentOrder!.completedAt,
        paymentMethod: _currentOrder!.paymentMethod,
        changeDue: _currentOrder!.changeDue,
        // Keep tableId and tableNumber for historical records
      );

      // 1. Save order + items (upsert if exists, insert if new)
      final orderSaved = await _orderRepository.upsertOrderWithItems(completedOrder, eposItems);
      if (!orderSaved) {
        debugPrint('❌ Failed to save order to Supabase');
        return false;
      }

      // 2. Record transaction(s)
      if (splitPayments != null && splitPayments.isNotEmpty) {
        // Split bill: Create separate transactions for each payment method
        debugPrint('💰 Recording split bill transactions:');
        debugPrint('   Split summary: $splitPaymentSummary');
        
        bool allTransactionsSucceeded = true;
        
        for (final entry in splitPayments.entries) {
          final paymentMethod = entry.key;
          final amount = entry.value;
          
          debugPrint('   Recording $paymentMethod transaction: £${amount.toStringAsFixed(2)}');
          
          final transaction = await _transactionRepository.recordTransactionFromOrder(
            order: completedOrder,
            paymentMethod: paymentMethod,
            amountPaid: amount,
            changeGiven: 0.0, // Change is handled per-split, not per-transaction
            meta: {
              'split_bill': true,
              'split_summary': splitPaymentSummary,
            },
          );

          if (transaction == null) {
            debugPrint('⚠️ Failed to record $paymentMethod transaction');
            allTransactionsSucceeded = false;
          }
        }
        
        if (!allTransactionsSucceeded) {
          debugPrint('⚠️ Order saved but some split bill transactions failed');
          return false;
        }
      } else {
        // Single payment method: Create one transaction
        final transaction = await _transactionRepository.recordTransactionFromOrder(
          order: completedOrder,
          paymentMethod: _currentOrder!.paymentMethod ?? 'Unknown',
          amountPaid: _currentOrder!.amountPaid,
          changeGiven: _currentOrder!.changeDue,
        );

        if (transaction == null) {
          debugPrint('⚠️ Order saved but transaction recording failed');
          return false;
        }
      }

      // 3. Decrement inventory based on BackOffice inventory mode
      debugPrint('📦 Processing inventory deduction for order items...');
      debugPrint('   Total items in order: ${_currentOrder!.items.length}');
      
      for (final item in _currentOrder!.items) {
        final product = item.product;
        
        debugPrint('');
        debugPrint('   🔍 Item: ${product.name}');
        debugPrint('      - isCarvery: ${product.isCarvery}');
        debugPrint('      - trackStock: ${product.trackStock}');
        debugPrint('      - linkedInventoryItemId: ${product.linkedInventoryItemId}');
        debugPrint('      - quantity: ${item.quantity}');
        
        // Skip if track_stock is false
        if (!product.trackStock) {
          debugPrint('      ⏭️  SKIPPING - track_stock is false');
          continue;
        }
        
        debugPrint('      ✅ Will process inventory deduction');
        
        // A) Basic Inventory Mode: Check if linked_inventory_item_id is set
        if (product.linkedInventoryItemId != null) {
          debugPrint('     Mode: Basic Inventory (linked_inventory_item_id: ${product.linkedInventoryItemId})');
          await _inventoryRepository.deductBasicInventoryStock(
            inventoryItemId: product.linkedInventoryItemId!,
            quantity: item.quantity.toDouble(),
          );
        } 
        // B) Enhanced Inventory Mode: Check for active recipe
        else {
          debugPrint('     Mode: Enhanced Inventory (checking for active recipe)');
          await _inventoryRepository.deductRecipeBasedStock(
            productId: product.id,
            quantity: item.quantity,
          );
        }
      }

      debugPrint('✅ Order, transaction, and inventory updated successfully');
      debugPrint('   Status: completed');
      if (_currentOrder!.tableNumber != null) {
        debugPrint('   Table ${_currentOrder!.tableNumber} is now free (status=completed)');
      }
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ Error saving order to Supabase: $e');
      debugPrint('Stack: $stackTrace');
      return false;
    }
  }

  void startNewOrder({bool? autoEnableServiceCharge, double? outletServiceChargePercent}) {
    final oldOutletId = _currentOrder?.outletId;
    final oldStaffId = _currentOrder?.staffId;
    
    // Auto-enable service charge if outlet has it enabled
    final shouldEnableServiceCharge = autoEnableServiceCharge ?? false;
    final serviceChargeRate = shouldEnableServiceCharge && outletServiceChargePercent != null
        ? outletServiceChargePercent / 100.0
        : 0.0;
    
    // Create completely fresh order without any table association
    _currentOrder = Order(
      id: _uuid.v4(),
      outletId: oldOutletId ?? '',
      staffId: oldStaffId,
      items: [],
      createdAt: DateTime.now(),
      serviceChargeRate: serviceChargeRate,
    );
    _serviceChargeEnabled = shouldEnableServiceCharge;
    
    debugPrint('🆕 OrderProvider: Started new order (${_currentOrder!.id})');
    debugPrint('   Service charge auto-enabled: $shouldEnableServiceCharge (rate: ${(serviceChargeRate * 100).toStringAsFixed(2)}%)');
    notifyListeners();
  }

  /// Clear current order and any table selection
  void clearCurrentOrderAndSelection() {
    _currentOrder = null;
    _serviceChargeEnabled = false;
    _activeSplitBill = null;
    _paidSplitItemIds.clear();
    debugPrint('🧹 OrderProvider: Cleared current order and selection');
    notifyListeners();
  }

  // ==================== SPLIT BILL FUNCTIONALITY ====================

  /// Create a split bill by selecting specific items
  SplitBill createSplitBillByItems(List<OrderItem> selectedItems) {
    if (_currentOrder == null) {
      throw Exception('No current order to split');
    }

    // Calculate subtotal and tax for selected items
    double subtotal = 0.0;
    double taxAmount = 0.0;
    for (final item in selectedItems) {
      subtotal += item.subtotal;
      taxAmount += item.taxAmount;
    }

    // Calculate proportional discount share
    final totalSubtotal = _currentOrder!.subtotal;
    final discountRatio = totalSubtotal > 0 ? subtotal / totalSubtotal : 0.0;
    final discountShare = (_currentOrder!.discountAmount + _currentOrder!.voucherAmount + _currentOrder!.loyaltyRedeemed) * discountRatio;
    final promotionDiscountShare = _currentOrder!.promotionDiscount * discountRatio;

    // Calculate service charge for this split (applied after discounts)
    final splitAfterDiscount = subtotal - promotionDiscountShare - discountShare;
    final serviceChargeShare = splitAfterDiscount * _currentOrder!.serviceChargeRate;

    // Calculate total due
    final totalDue = subtotal + taxAmount + serviceChargeShare - discountShare - promotionDiscountShare;

    _activeSplitBill = SplitBill(
      items: selectedItems,
      subtotal: subtotal,
      taxAmount: taxAmount,
      discountShare: discountShare,
      promotionDiscountShare: promotionDiscountShare,
      serviceChargeShare: serviceChargeShare,
      totalDue: totalDue,
      splitType: 'items',
    );

    debugPrint('🔀 OrderProvider: Created item-based split bill');
    debugPrint('   Items: ${selectedItems.length}');
    debugPrint('   Subtotal: £${subtotal.toStringAsFixed(2)}');
    debugPrint('   Total Due: £${totalDue.toStringAsFixed(2)}');

    notifyListeners();
    return _activeSplitBill!;
  }

  /// Create even splits (divide bill by number of people)
  SplitBill createEvenSplit(int numberOfPeople, int splitIndex) {
    if (_currentOrder == null) {
      throw Exception('No current order to split');
    }
    if (numberOfPeople <= 0 || splitIndex <= 0 || splitIndex > numberOfPeople) {
      throw Exception('Invalid split parameters');
    }

    // Calculate per-person amounts
    final subtotalPerPerson = _currentOrder!.subtotal / numberOfPeople;
    final taxPerPerson = _currentOrder!.taxAmount / numberOfPeople;
    final discountPerPerson = (_currentOrder!.discountAmount + _currentOrder!.voucherAmount + _currentOrder!.loyaltyRedeemed) / numberOfPeople;
    final promotionDiscountPerPerson = _currentOrder!.promotionDiscount / numberOfPeople;
    
    // Service charge is calculated after discounts
    final afterDiscounts = subtotalPerPerson - promotionDiscountPerPerson - discountPerPerson;
    final serviceChargePerPerson = afterDiscounts * _currentOrder!.serviceChargeRate;
    
    final totalPerPerson = subtotalPerPerson + taxPerPerson + serviceChargePerPerson - discountPerPerson - promotionDiscountPerPerson;

    _activeSplitBill = SplitBill(
      items: _currentOrder!.items, // Include all items for reference
      subtotal: subtotalPerPerson,
      taxAmount: taxPerPerson,
      discountShare: discountPerPerson,
      promotionDiscountShare: promotionDiscountPerPerson,
      serviceChargeShare: serviceChargePerPerson,
      totalDue: totalPerPerson,
      splitType: 'even',
      splitIndex: splitIndex,
      totalSplits: numberOfPeople,
    );

    debugPrint('🔀 OrderProvider: Created even split ($splitIndex of $numberOfPeople)');
    debugPrint('   Total Due per person: £${totalPerPerson.toStringAsFixed(2)}');

    notifyListeners();
    return _activeSplitBill!;
  }

  /// Mark split bill as paid and remove items from order
  Future<bool> finalizeSplitBillPayment({
    required String paymentMethod,
    required double amountPaid,
    double changeDue = 0.0,
  }) async {
    if (_currentOrder == null || _activeSplitBill == null) {
      debugPrint('⚠️ Cannot finalize split: No order or split bill');
      return false;
    }

    try {
      debugPrint('💰 Finalizing split bill payment');
      debugPrint('   Payment Method: $paymentMethod');
      debugPrint('   Amount: £${amountPaid.toStringAsFixed(2)}');

      // Record transaction for this split
      final (eposOrder, eposItems) = _orderRepository.convertToEposModels(_currentOrder!);
      final splitTransaction = await _transactionRepository.recordTransactionFromOrder(
        order: eposOrder,
        paymentMethod: paymentMethod,
        amountPaid: _activeSplitBill!.totalDue,
        changeGiven: changeDue,
      );

      if (splitTransaction == null) {
        debugPrint('⚠️ Failed to record split transaction');
        return false;
      }

      // For item-based splits, remove paid items from order
      if (_activeSplitBill!.splitType == 'items') {
        // Mark items as paid
        for (final item in _activeSplitBill!.items) {
          _paidSplitItemIds.add(item.id);
        }

        // Remove paid items from current order
        final remainingItems = _currentOrder!.items.where((item) => !_paidSplitItemIds.contains(item.id)).toList();
        
        if (remainingItems.isEmpty) {
          // All items paid - complete the order
          debugPrint('✅ All items paid via splits - completing order');
          _currentOrder = _currentOrder!.copyWith(
            items: [],
            paymentMethod: 'Split: $paymentMethod',
            amountPaid: amountPaid,
            changeDue: changeDue,
            completedAt: DateTime.now(),
          );
        } else {
          // Still have remaining items
          _currentOrder = _currentOrder!.copyWith(items: remainingItems);
          debugPrint('📝 ${remainingItems.length} items remaining in order');
        }
      }

      // Clear active split
      _activeSplitBill = null;
      
      debugPrint('✅ Split bill payment finalized');
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ Error finalizing split payment: $e');
      debugPrint('Stack: $stackTrace');
      return false;
    }
  }

  /// Clear the active split bill (cancel split)
  void cancelSplitBill() {
    _activeSplitBill = null;
    debugPrint('❌ Split bill cancelled');
    notifyListeners();
  }

  /// Get remaining order total after paid splits
  double get remainingOrderTotal {
    if (_currentOrder == null) return 0.0;
    
    if (_paidSplitItemIds.isEmpty) {
      return _currentOrder!.totalDue;
    }

    // Calculate total for unpaid items
    final remainingItems = _currentOrder!.items.where((item) => !_paidSplitItemIds.contains(item.id));
    double subtotal = 0.0;
    double taxAmount = 0.0;
    for (final item in remainingItems) {
      subtotal += item.subtotal;
      taxAmount += item.taxAmount;
    }

    // Proportional discounts
    final totalSubtotal = _currentOrder!.subtotal;
    final ratio = totalSubtotal > 0 ? subtotal / totalSubtotal : 0.0;
    final discountShare = (_currentOrder!.discountAmount + _currentOrder!.voucherAmount + _currentOrder!.loyaltyRedeemed) * ratio;
    final promotionShare = _currentOrder!.promotionDiscount * ratio;

    // Service charge after discounts
    final afterDiscounts = subtotal - promotionShare - discountShare;
    final serviceCharge = afterDiscounts * _currentOrder!.serviceChargeRate;

    return subtotal + taxAmount + serviceCharge - discountShare - promotionShare;
  }

  /// Reset paid splits (for new orders)
  void resetSplits() {
    _paidSplitItemIds.clear();
    _activeSplitBill = null;
    debugPrint('🔄 Split bills reset');
  }

  // ==================== STAFF-SPECIFIC ORDER MANAGEMENT ====================

  /// Park current quick-service order for a specific staff member
  /// Only parks if it's a quick-service order (no table) with items
  void parkOrderForStaff(String staffId) {
    if (_currentOrder == null) {
      debugPrint('⚠️ OrderProvider: No current order to park for staff $staffId');
      return;
    }

    // Only park quick-service orders (orders without tables)
    if (_currentOrder!.tableNumber != null) {
      debugPrint('⚠️ OrderProvider: Cannot park table order for staff. Table orders are shared.');
      return;
    }

    // Only park if order has items
    if (_currentOrder!.items.isEmpty) {
      debugPrint('⚠️ OrderProvider: Order is empty, nothing to park for staff $staffId');
      return;
    }

    debugPrint('💼 OrderProvider: Parking quick-service order for staff $staffId');
    debugPrint('   Order ID: ${_currentOrder!.id}');
    debugPrint('   Items: ${_currentOrder!.items.length}');
    debugPrint('   Total: £${_currentOrder!.totalDue.toStringAsFixed(2)}');

    // Save the current order for this staff
    _parkedOrdersByStaff[staffId] = _currentOrder!;
    
    // Clear current order state
    _currentOrder = null;
    _serviceChargeEnabled = false;
    _activeSplitBill = null;
    _paidSplitItemIds.clear();
    
    debugPrint('✅ OrderProvider: Order parked for staff $staffId');
    notifyListeners();
  }

  /// Restore a staff member's parked quick-service order
  /// Returns true if an order was restored, false otherwise
  bool restoreOrderForStaff(String staffId) {
    if (!_parkedOrdersByStaff.containsKey(staffId)) {
      debugPrint('ℹ️ OrderProvider: No parked order found for staff $staffId');
      return false;
    }

    final parkedOrder = _parkedOrdersByStaff[staffId]!;
    
    debugPrint('💼 OrderProvider: Restoring parked order for staff $staffId');
    debugPrint('   Order ID: ${parkedOrder.id}');
    debugPrint('   Items: ${parkedOrder.items.length}');
    debugPrint('   Total: £${parkedOrder.totalDue.toStringAsFixed(2)}');

    // Update the staff ID to current staff (in case it changed)
    _currentOrder = parkedOrder.copyWith(staffId: staffId);
    _serviceChargeEnabled = _currentOrder!.serviceChargeRate > 0;
    
    // Recalculate promotions for restored order
    _applyPromotions();
    
    // Remove from parked orders
    _parkedOrdersByStaff.remove(staffId);
    
    debugPrint('✅ OrderProvider: Order restored for staff $staffId');
    notifyListeners();
    return true;
  }

  /// Clear all parked orders for a staff member (useful on logout if not restoring)
  void clearParkedOrderForStaff(String staffId) {
    if (_parkedOrdersByStaff.containsKey(staffId)) {
      debugPrint('🗑️ OrderProvider: Clearing parked order for staff $staffId');
      _parkedOrdersByStaff.remove(staffId);
      notifyListeners();
    }
  }

  /// Check if a staff member has a parked order
  bool hasParkedOrderForStaff(String staffId) {
    return _parkedOrdersByStaff.containsKey(staffId);
  }

  @override
  void dispose() {
    // Clean up table lock service
    _tableLockService.dispose();
    super.dispose();
  }
}
