import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flowtill/theme.dart';
import 'package:flowtill/models/inventory_item.dart';
import 'package:flowtill/models/stock_movement.dart';
import 'package:flowtill/services/inventory_repository.dart';
import 'package:flowtill/services/stock_movement_service.dart';
import 'package:flowtill/providers/outlet_provider.dart';
import 'package:flowtill/providers/staff_provider.dart';
import 'package:intl/intl.dart';

/// Stock Adjustments Screen
/// Allows authorized staff to manually adjust inventory quantities
class StockAdjustmentsScreen extends StatefulWidget {
  const StockAdjustmentsScreen({super.key});

  @override
  State<StockAdjustmentsScreen> createState() => _StockAdjustmentsScreenState();
}

class _StockAdjustmentsScreenState extends State<StockAdjustmentsScreen> {
  final _inventoryRepository = InventoryRepository();
  final _stockMovementService = StockMovementService();
  
  List<InventoryItem> _inventoryItems = [];
  InventoryItem? _selectedItem;
  
  final _quantityController = TextEditingController();
  String _adjustmentType = 'add'; // 'add', 'remove', 'set'
  String _reason = 'Breakage';
  final _notesController = TextEditingController();
  
  List<Map<String, dynamic>> _recentMovements = [];
  bool _isLoading = false;
  bool _isSubmitting = false;

  final List<String> _predefinedReasons = [
    'Breakage',
    'Theft',
    'Stocktake Correction',
    'Delivery',
    'Wastage',
    'Promotion',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final outletProvider = context.read<OutletProvider>();
    final outletId = outletProvider.currentOutlet?.id;
    
    if (outletId == null) {
      setState(() => _isLoading = false);
      return;
    }

    // Load inventory items
    final items = await _inventoryRepository.getInventoryForOutlet(outletId);
    
    // Load recent movements
    final movements = await _stockMovementService.getStockMovementsWithDetails(
      outletId: outletId,
      limit: 50,
    );

    setState(() {
      _inventoryItems = items;
      _recentMovements = movements;
      _isLoading = false;
    });
  }

  Future<void> _submitAdjustment() async {
    if (_selectedItem == null) {
      _showError('Please select an inventory item');
      return;
    }

    final qtyText = _quantityController.text.trim();
    if (qtyText.isEmpty) {
      _showError('Please enter a quantity');
      return;
    }

    final qty = double.tryParse(qtyText);
    if (qty == null || qty <= 0) {
      _showError('Please enter a valid quantity');
      return;
    }

    setState(() => _isSubmitting = true);

    final outletProvider = context.read<OutletProvider>();
    final staffProvider = context.read<StaffProvider>();
    final outletId = outletProvider.currentOutlet?.id;
    final staffId = staffProvider.currentStaff?.id;

    if (outletId == null) {
      _showError('No outlet selected');
      setState(() => _isSubmitting = false);
      return;
    }

    bool success;

    if (_adjustmentType == 'set') {
      // Set to specific quantity
      success = await _stockMovementService.setInventoryQuantity(
        outletId: outletId,
        inventoryItemId: _selectedItem!.id,
        newQty: qty,
        reason: _reason,
        note: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        staffId: staffId,
      );
    } else {
      // Add or remove
      final changeQty = _adjustmentType == 'add' ? qty : -qty;
      success = await _stockMovementService.createStockMovement(
        outletId: outletId,
        inventoryItemId: _selectedItem!.id,
        changeQty: changeQty,
        reason: _reason,
        note: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        staffId: staffId,
      );
    }

    setState(() => _isSubmitting = false);

    if (success) {
      _showSuccess('Stock adjustment recorded successfully');
      _clearForm();
      _loadData(); // Reload to show new movement
    } else {
      _showError('Failed to record stock adjustment');
    }
  }

  void _clearForm() {
    setState(() {
      _selectedItem = null;
      _quantityController.clear();
      _adjustmentType = 'add';
      _reason = 'Breakage';
      _notesController.clear();
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                // Left panel - Adjustment form
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: AppSpacing.paddingLg,
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      border: Border(
                        right: BorderSide(
                          color: colorScheme.outline.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Stock Adjustment',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Manually adjust inventory quantities and track stock movements',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          
                          // Inventory item selector
                          _buildInventoryItemSelector(theme, colorScheme),
                          const SizedBox(height: AppSpacing.lg),

                          // Current quantity display
                          if (_selectedItem != null) ...[
                            _buildCurrentQuantityCard(theme, colorScheme),
                            const SizedBox(height: AppSpacing.lg),
                          ],

                          // Adjustment type
                          _buildAdjustmentTypeSelector(theme, colorScheme),
                          const SizedBox(height: AppSpacing.lg),

                          // Quantity input
                          _buildQuantityInput(theme, colorScheme),
                          const SizedBox(height: AppSpacing.lg),

                          // Reason selector
                          _buildReasonSelector(theme, colorScheme),
                          const SizedBox(height: AppSpacing.lg),

                          // Notes input
                          _buildNotesInput(theme, colorScheme),
                          const SizedBox(height: AppSpacing.xl),

                          // Submit button
                          _buildSubmitButton(theme, colorScheme),
                        ],
                      ),
                    ),
                  ),
                ),

                // Right panel - Movement history
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: AppSpacing.paddingLg,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Recent Stock Movements',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh),
                              onPressed: _loadData,
                              tooltip: 'Refresh',
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Expanded(
                          child: _buildMovementHistory(theme, colorScheme),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildInventoryItemSelector(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Inventory Item',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.3),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<InventoryItem>(
              value: _selectedItem,
              hint: Padding(
                padding: AppSpacing.paddingMd,
                child: Text(
                  'Choose an item...',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              isExpanded: true,
              padding: AppSpacing.paddingMd,
              borderRadius: BorderRadius.circular(AppRadius.md),
              items: _inventoryItems.map((item) {
                return DropdownMenuItem(
                  value: item,
                  child: Text(
                    '${item.name}${item.sku != null ? ' (${item.sku})' : ''}',
                    style: theme.textTheme.bodyLarge,
                  ),
                );
              }).toList(),
              onChanged: (item) => setState(() => _selectedItem = item),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentQuantityCard(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: AppSpacing.paddingLg,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Stock',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${_selectedItem!.currentQty.toStringAsFixed(2)} ${_selectedItem!.unit}',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          Icon(
            Icons.inventory,
            size: 48,
            color: colorScheme.primary.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildAdjustmentTypeSelector(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Adjustment Type',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _buildTypeButton(
                'Add',
                'add',
                Icons.add_circle,
                Colors.green,
                theme,
                colorScheme,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildTypeButton(
                'Remove',
                'remove',
                Icons.remove_circle,
                Colors.red,
                theme,
                colorScheme,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildTypeButton(
                'Set To',
                'set',
                Icons.settings,
                Colors.blue,
                theme,
                colorScheme,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeButton(
    String label,
    String value,
    IconData icon,
    Color color,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final isSelected = _adjustmentType == value;
    return InkWell(
      onTap: () => setState(() => _adjustmentType = value),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: AppSpacing.paddingMd,
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.2)
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isSelected ? color : colorScheme.outline.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? color : colorScheme.onSurfaceVariant,
              size: 32,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityInput(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _adjustmentType == 'set' ? 'New Quantity' : 'Quantity',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _quantityController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
          ],
          decoration: InputDecoration(
            hintText: 'Enter quantity',
            suffixText: _selectedItem?.unit ?? 'units',
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(
                color: colorScheme.primary,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReasonSelector(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reason',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.3),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _reason,
              isExpanded: true,
              padding: AppSpacing.paddingMd,
              borderRadius: BorderRadius.circular(AppRadius.md),
              items: _predefinedReasons.map((reason) {
                return DropdownMenuItem(
                  value: reason,
                  child: Text(reason, style: theme.textTheme.bodyLarge),
                );
              }).toList(),
              onChanged: (value) => setState(() => _reason = value ?? 'Breakage'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotesInput(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notes (Optional)',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _notesController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Add any additional notes...',
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(
                color: colorScheme.primary,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(ThemeData theme, ColorScheme colorScheme) {
    return ElevatedButton(
      onPressed: _isSubmitting ? null : _submitAdjustment,
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      child: _isSubmitting
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              'Record Adjustment',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onPrimary,
              ),
            ),
    );
  }

  Widget _buildMovementHistory(ThemeData theme, ColorScheme colorScheme) {
    if (_recentMovements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No stock movements yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _recentMovements.length,
      itemBuilder: (context, index) {
        final data = _recentMovements[index];
        final movement = data['movement'] as StockMovement;
        final inventoryName = data['inventory_name'] as String;
        final inventoryUnit = data['inventory_unit'] as String;
        final staffName = data['staff_name'] as String;

        final isPositive = movement.changeQty > 0;
        final changeColor = isPositive ? Colors.green : Colors.red;
        final changeIcon = isPositive ? Icons.add : Icons.remove;

        return Card(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          child: ListTile(
            contentPadding: AppSpacing.paddingMd,
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: changeColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(changeIcon, color: changeColor, size: 24),
            ),
            title: Text(
              inventoryName,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${isPositive ? '+' : ''}${movement.changeQty.toStringAsFixed(2)} $inventoryUnit',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: changeColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Reason: ${movement.reason}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                if (movement.note != null && movement.note!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Note: ${movement.note}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'By: $staffName',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            trailing: Text(
              DateFormat('MMM d, HH:mm').format(movement.createdAt),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        );
      },
    );
  }
}
