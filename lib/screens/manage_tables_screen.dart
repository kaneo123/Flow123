import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flowtill/models/outlet_table.dart';
import 'package:flowtill/providers/outlet_provider.dart';
import 'package:flowtill/services/outlet_table_repository.dart';
import 'package:flowtill/theme.dart';
import 'package:uuid/uuid.dart';

class ManageTablesScreen extends StatefulWidget {
  const ManageTablesScreen({super.key});

  @override
  State<ManageTablesScreen> createState() => _ManageTablesScreenState();
}

class _ManageTablesScreenState extends State<ManageTablesScreen> {
  final _repository = OutletTableRepository();
  Map<String, List<OutletTable>> _tablesByRoom = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTables();
  }

  Future<void> _loadTables() async {
    setState(() => _isLoading = true);

    final outlet = context.read<OutletProvider>().currentOutlet;
    if (outlet == null) {
      setState(() => _isLoading = false);
      return;
    }

    final tables = await _repository.getTablesGroupedByRoom(outlet.id);

    setState(() {
      _tablesByRoom = tables;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerHighest,
      appBar: AppBar(
        title: const Text('Manage Tables'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddTableDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tablesByRoom.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.table_restaurant, size: 64, color: Colors.grey),
                      const SizedBox(height: AppSpacing.md),
                      const Text(
                        'No tables configured',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      ElevatedButton.icon(
                        onPressed: _showAddTableDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Table'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: AppSpacing.paddingLg,
                  itemCount: _tablesByRoom.keys.length,
                  itemBuilder: (context, index) {
                    final roomName = _tablesByRoom.keys.elementAt(index);
                    final tables = _tablesByRoom[roomName]!;
                    return _RoomSection(
                      roomName: roomName,
                      tables: tables,
                      onEdit: _showEditTableDialog,
                      onDelete: _deleteTable,
                    );
                  },
                ),
    );
  }

  void _showAddTableDialog() {
    final outlet = context.read<OutletProvider>().currentOutlet;
    if (outlet == null) return;

    showDialog(
      context: context,
      builder: (context) => _TableFormDialog(
        outletId: outlet.id,
        onSave: (table) async {
          await _repository.createTable(table);
          _loadTables();
        },
      ),
    );
  }

  void _showEditTableDialog(OutletTable table) {
    showDialog(
      context: context,
      builder: (context) => _TableFormDialog(
        outletId: table.outletId,
        existingTable: table,
        onSave: (updatedTable) async {
          await _repository.updateTable(updatedTable);
          _loadTables();
        },
      ),
    );
  }

  Future<void> _deleteTable(OutletTable table) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Table'),
        content: Text('Are you sure you want to delete ${table.displayName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _repository.deleteTable(table.id);
      _loadTables();
    }
  }
}

class _RoomSection extends StatelessWidget {
  final String roomName;
  final List<OutletTable> tables;
  final Function(OutletTable) onEdit;
  final Function(OutletTable) onDelete;

  const _RoomSection({
    required this.roomName,
    required this.tables,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: AppSpacing.verticalSm,
      child: Padding(
        padding: AppSpacing.paddingLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              roomName,
              style: theme.textTheme.titleLarge?.bold,
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: tables.map((table) {
                return _TableChip(
                  table: table,
                  onEdit: () => onEdit(table),
                  onDelete: () => onDelete(table),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _TableChip extends StatelessWidget {
  final OutletTable table;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TableChip({
    required this.table,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                table.displayName,
                style: theme.textTheme.bodyLarge?.semiBold.copyWith(
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              InkWell(
                onTap: onDelete,
                child: Icon(
                  Icons.close,
                  size: 18,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TableFormDialog extends StatefulWidget {
  final String outletId;
  final OutletTable? existingTable;
  final Function(OutletTable) onSave;

  const _TableFormDialog({
    required this.outletId,
    this.existingTable,
    required this.onSave,
  });

  @override
  State<_TableFormDialog> createState() => _TableFormDialogState();
}

class _TableFormDialogState extends State<_TableFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _roomNameController;
  late TextEditingController _roomNumberController;
  late TextEditingController _tableNumberController;
  late TextEditingController _capacityController;

  @override
  void initState() {
    super.initState();
    _roomNameController = TextEditingController(text: widget.existingTable?.roomName ?? '');
    _roomNumberController = TextEditingController(text: widget.existingTable?.roomNumber?.toString() ?? '');
    _tableNumberController = TextEditingController(text: widget.existingTable?.tableNumber ?? '');
    _capacityController = TextEditingController(text: widget.existingTable?.capacity?.toString() ?? '');
  }

  @override
  void dispose() {
    _roomNameController.dispose();
    _roomNumberController.dispose();
    _tableNumberController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(widget.existingTable == null ? 'Add Table' : 'Edit Table'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _roomNameController,
                  decoration: const InputDecoration(
                    labelText: 'Room Name',
                    hintText: 'Main Dining Room',
                  ),
                  validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _roomNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Room Number (Optional)',
                    hintText: '1',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _tableNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Table Number / Name',
                    hintText: '1, John\'s Tab, VIP Room, etc.',
                  ),
                  validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _capacityController,
                  decoration: const InputDecoration(
                    labelText: 'Capacity (Optional)',
                    hintText: '4',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final roomName = _roomNameController.text.trim();
    final roomNumber = int.tryParse(_roomNumberController.text.trim());
    final tableNumber = _tableNumberController.text.trim();
    final capacity = int.tryParse(_capacityController.text.trim());

    final now = DateTime.now();
    final table = OutletTable(
      id: widget.existingTable?.id ?? const Uuid().v4(),
      outletId: widget.outletId,
      roomName: roomName,
      roomNumber: roomNumber,
      tableNumber: tableNumber,
      capacity: capacity,
      active: true,
      sortOrder: widget.existingTable?.sortOrder ?? 0,
      createdAt: widget.existingTable?.createdAt ?? now,
      updatedAt: now,
    );

    widget.onSave(table);
    Navigator.pop(context);
  }
}
