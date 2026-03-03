import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/till_adjustment.dart';
import '../services/till_adjustment_service.dart';
import '../providers/outlet_provider.dart';
import '../providers/staff_provider.dart';

class AdjustmentsScreen extends StatefulWidget {
  const AdjustmentsScreen({super.key});

  @override
  State<AdjustmentsScreen> createState() => _AdjustmentsScreenState();
}

class _AdjustmentsScreenState extends State<AdjustmentsScreen> {
  final _service = TillAdjustmentService();
  List<TillAdjustment> _adjustments = [];
  bool _loading = true;
  String? _error;

  // Date filter
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadAdjustments();
  }

  Future<void> _loadAdjustments() async {
    final outlet = context.read<OutletProvider>().currentOutlet;
    if (outlet == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final adjustments = await _service.fetchAdjustments(
        outletId: outlet.id,
        startDate: _startDate,
        endDate: _endDate,
      );
      setState(() {
        _adjustments = adjustments;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _showAddAdjustmentDialog() async {
    final outlet = context.read<OutletProvider>().currentOutlet;
    final currentStaff = context.read<StaffProvider>().currentStaff;

    if (outlet == null || currentStaff == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No outlet or staff selected')),
      );
      return;
    }

    String type = 'removal';
    String reason = '';
    String amount = '';
    String? notes;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Till Adjustment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type dropdown
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'removal', child: Text('Cash Removal')),
                    DropdownMenuItem(value: 'addition', child: Text('Cash Addition')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => type = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                // Amount field
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    border: OutlineInputBorder(),
                    prefixText: '£',
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  onChanged: (value) => amount = value,
                ),
                const SizedBox(height: 16),
                // Reason dropdown
                DropdownButtonFormField<String>(
                  value: reason.isEmpty ? null : reason,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'petty_cash', child: Text('Petty Cash')),
                    DropdownMenuItem(value: 'cash_drop', child: Text('Cash Drop')),
                    DropdownMenuItem(value: 'float', child: Text('Float')),
                    DropdownMenuItem(value: 'till_shortage', child: Text('Till Shortage')),
                    DropdownMenuItem(value: 'till_overage', child: Text('Till Overage')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => reason = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                // Notes field
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  onChanged: (value) => notes = value.isEmpty ? null : value,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (amount.isEmpty || reason.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill in all required fields')),
                  );
                  return;
                }
                Navigator.of(context).pop(true);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (result == true && amount.isNotEmpty && reason.isNotEmpty) {
      try {
        final parsedAmount = double.parse(amount);
        final adjustmentAmount = type == 'removal' ? -parsedAmount.abs() : parsedAmount.abs();

        await _service.createAdjustment(
          outletId: outlet.id,
          staffId: currentStaff.id,
          amount: adjustmentAmount,
          type: type,
          reason: reason,
          notes: notes,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Adjustment added successfully')),
          );
          _loadAdjustments();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to add adjustment: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteAdjustment(TillAdjustment adjustment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Adjustment'),
        content: const Text('Are you sure you want to delete this adjustment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _service.deleteAdjustment(adjustment.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Adjustment deleted')),
          );
          _loadAdjustments();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e')),
          );
        }
      }
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadAdjustments();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '£');
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Till Adjustments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: 'Select Date Range',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAdjustments,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadAdjustments,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Date range display
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.grey.shade100,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${_adjustments.length} adjustments',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                    // Summary card
                    if (_adjustments.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                const Text('Total Removals', style: TextStyle(fontSize: 12)),
                                Text(
                                  currencyFormat.format(
                                    _adjustments
                                        .where((a) => a.amount < 0)
                                        .fold<double>(0, (sum, a) => sum + a.amount)
                                        .abs(),
                                  ),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                const Text('Total Additions', style: TextStyle(fontSize: 12)),
                                Text(
                                  currencyFormat.format(
                                    _adjustments
                                        .where((a) => a.amount > 0)
                                        .fold<double>(0, (sum, a) => sum + a.amount),
                                  ),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                const Text('Net Impact', style: TextStyle(fontSize: 12)),
                                Text(
                                  currencyFormat.format(
                                    _adjustments.fold<double>(0, (sum, a) => sum + a.amount),
                                  ),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    // Adjustments list
                    Expanded(
                      child: _adjustments.isEmpty
                          ? const Center(
                              child: Text('No adjustments found for this period'),
                            )
                          : ListView.builder(
                              itemCount: _adjustments.length,
                              itemBuilder: (context, index) {
                                final adjustment = _adjustments[index];
                                final isRemoval = adjustment.amount < 0;

                                return Card(
                                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: isRemoval ? Colors.red.shade100 : Colors.green.shade100,
                                      child: Icon(
                                        isRemoval ? Icons.remove : Icons.add,
                                        color: isRemoval ? Colors.red : Colors.green,
                                      ),
                                    ),
                                    title: Text(
                                      currencyFormat.format(adjustment.amount.abs()),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isRemoval ? Colors.red : Colors.green,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(_formatReason(adjustment.reason)),
                                        Text(
                                          dateFormat.format(adjustment.timestamp),
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                        ),
                                        if (adjustment.notes != null && adjustment.notes!.isNotEmpty)
                                          Text(
                                            adjustment.notes!,
                                            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                                          ),
                                      ],
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _deleteAdjustment(adjustment),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddAdjustmentDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Adjustment'),
      ),
    );
  }

  String _formatReason(String reason) {
    switch (reason) {
      case 'petty_cash':
        return 'Petty Cash';
      case 'cash_drop':
        return 'Cash Drop';
      case 'float':
        return 'Float';
      case 'till_shortage':
        return 'Till Shortage';
      case 'till_overage':
        return 'Till Overage';
      case 'other':
        return 'Other';
      default:
        return reason;
    }
  }
}
