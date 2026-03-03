import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flowtill/theme.dart';
import 'package:flowtill/models/outlet_table.dart';
import 'package:flowtill/providers/table_layout_provider.dart';
import 'package:flowtill/providers/outlet_provider.dart';

/// Table Layout Settings Screen - Manage rooms and tables with drag-and-drop layout
class TableLayoutScreen extends StatefulWidget {
  const TableLayoutScreen({super.key});

  @override
  State<TableLayoutScreen> createState() => _TableLayoutScreenState();
}

class _TableLayoutScreenState extends State<TableLayoutScreen> {
  bool _hasLoadedData = false;

  @override
  void initState() {
    super.initState();
    debugPrint('🏗️ TableLayoutScreen: initState called');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasLoadedData) {
      debugPrint('🏗️ TableLayoutScreen: didChangeDependencies - loading data for first time');
      _hasLoadedData = true;
      _loadData();
    }
  }

  Future<void> _loadData() async {
    debugPrint('🏗️ TableLayoutScreen: _loadData called');
    final outletProvider = context.read<OutletProvider>();
    final tableProvider = context.read<TableLayoutProvider>();
    
    debugPrint('🏗️ TableLayoutScreen: Current outlet = ${outletProvider.currentOutlet?.name}');
    
    if (outletProvider.currentOutlet != null) {
      debugPrint('🏗️ TableLayoutScreen: Resetting provider state...');
      tableProvider.reset();
      
      debugPrint('🏗️ TableLayoutScreen: Calling loadRoomsForOutlet...');
      try {
        await tableProvider.loadRoomsForOutlet(outletProvider.currentOutlet!.id);
        debugPrint('🏗️ TableLayoutScreen: loadRoomsForOutlet completed successfully');
        debugPrint('🏗️ TableLayoutScreen: Rooms loaded: ${tableProvider.rooms.length}');
        debugPrint('🏗️ TableLayoutScreen: Tables loaded: ${tableProvider.tablesForRoom.length}');
        debugPrint('🏗️ TableLayoutScreen: isLoading: ${tableProvider.isLoading}');
      } catch (e, stackTrace) {
        debugPrint('❌ TableLayoutScreen: Error in loadRoomsForOutlet: $e');
        debugPrint('Stack trace: $stackTrace');
      }
    } else {
      debugPrint('⚠️ TableLayoutScreen: No current outlet found');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Consumer2<TableLayoutProvider, OutletProvider>(
        builder: (context, tableProvider, outletProvider, _) {
          if (outletProvider.currentOutlet == null) {
            return _buildNoOutletSelected(theme, colorScheme);
          }

          if (tableProvider.isLoading && tableProvider.rooms.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return Row(
            children: [
              // Left panel - Room & table management
              _LeftPanel(
                outletId: outletProvider.currentOutlet!.id,
              ),
              // Right panel - Drag & drop canvas
              Expanded(
                child: _RightPanel(
                  outletId: outletProvider.currentOutlet!.id,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNoOutletSelected(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.store_outlined, size: 64, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No Outlet Selected',
            style: theme.textTheme.titleLarge?.copyWith(color: colorScheme.onSurface),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Please select an outlet to manage table layouts',
            style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Left panel - Room and table list
class _LeftPanel extends StatelessWidget {
  final String outletId;

  const _LeftPanel({required this.outletId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tableProvider = context.watch<TableLayoutProvider>();

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(right: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: AppSpacing.paddingMd,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
              border: Border(bottom: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.table_bar, color: colorScheme.primary, size: 24),
                    const SizedBox(width: AppSpacing.sm),
                    Text('Table Layout', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Configure rooms and table positions',
                  style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),

          // Room selector
          if (tableProvider.rooms.isNotEmpty) ...[
            Padding(
              padding: AppSpacing.paddingMd,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Select Room', style: theme.textTheme.labelMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                      if (tableProvider.selectedRoomName != null)
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: colorScheme.error, size: 20),
                          onPressed: () => _confirmDeleteRoom(context, outletId, tableProvider.selectedRoomName!),
                          tooltip: 'Delete Room',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  DropdownButtonFormField<String>(
                    value: tableProvider.selectedRoomName,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      contentPadding: AppSpacing.paddingSm,
                    ),
                    items: tableProvider.rooms.map((room) => DropdownMenuItem(value: room, child: Text(room))).toList(),
                    onChanged: (roomName) {
                      if (roomName != null) {
                        tableProvider.selectRoom(outletId, roomName);
                      }
                    },
                  ),
                ],
              ),
            ),
            Divider(color: colorScheme.outline.withValues(alpha: 0.2)),
          ],

          // Add Room button
          Padding(
            padding: AppSpacing.paddingMd,
            child: OutlinedButton.icon(
              onPressed: () => _showAddRoomDialog(context, outletId),
              icon: const Icon(Icons.add),
              label: const Text('Add Room'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.md),
              ),
            ),
          ),

          if (tableProvider.selectedRoomName != null) ...[
            // Add Table button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: FilledButton.icon(
                onPressed: () => _showAddTableDialog(context, outletId, tableProvider.selectedRoomName!),
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Add Table'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Tables list
            Expanded(
              child: tableProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : tableProvider.tablesForRoom.isEmpty
                      ? _buildEmptyState(theme, colorScheme)
                      : _buildTablesList(context, tableProvider, theme, colorScheme),
            ),
          ] else
            Expanded(child: _buildNoRoomSelected(theme, colorScheme)),
        ],
      ),
    );
  }

  Widget _buildTablesList(BuildContext context, TableLayoutProvider tableProvider, ThemeData theme, ColorScheme colorScheme) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      itemCount: tableProvider.tablesForRoom.length,
      itemBuilder: (context, index) {
        final table = tableProvider.tablesForRoom[index];
        final isSelected = tableProvider.selectedTableId == table.id;

        return Card(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          color: isSelected ? colorScheme.primaryContainer.withValues(alpha: 0.3) : null,
          child: ListTile(
            onTap: () => tableProvider.selectTable(table.id),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: table.active ? colorScheme.primary : colorScheme.onSurfaceVariant,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Center(
                child: Text(
                  table.tableNumber,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: table.active ? colorScheme.onPrimary : colorScheme.surface,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            title: Text(table.displayName, style: theme.textTheme.bodyLarge),
            subtitle: Text(table.capacity != null ? 'Capacity: ${table.capacity}' : 'No capacity set',
                style: theme.textTheme.bodySmall),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit, color: colorScheme.primary, size: 20),
                  onPressed: () => _showEditTableDialog(context, outletId, table),
                  tooltip: 'Edit',
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: colorScheme.error, size: 20),
                  onPressed: () => _confirmDeleteTable(context, outletId, table),
                  tooltip: 'Delete',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.table_restaurant, size: 48, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: AppSpacing.md),
          Text('No Tables', style: theme.textTheme.titleMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.xs),
          Text('Add tables to this room', style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildNoRoomSelected(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.meeting_room, size: 48, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: AppSpacing.md),
          Text('No Room Selected', style: theme.textTheme.titleMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.xs),
          Text('Create a room to get started', style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  void _showAddRoomDialog(BuildContext context, String outletId) {
    final nameController = TextEditingController();
    final numberController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Room'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Room Name', hintText: 'e.g., Restaurant Floor 1'),
              autofocus: true,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: numberController,
              decoration: const InputDecoration(labelText: 'Room Number (optional)', hintText: 'e.g., 1'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                final number = int.tryParse(numberController.text.trim());
                context.read<TableLayoutProvider>().addRoom(outletId, name, number);
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showAddTableDialog(BuildContext context, String outletId, String roomName) {
    final tableProvider = context.read<TableLayoutProvider>();
    final tableNumberController = TextEditingController();
    final capacityController = TextEditingController();

    // Auto-generate next table number
    final existingTables = tableProvider.tablesForRoom;
    // Try to find the highest numeric table number, default to 1
    int nextTableNumber = 1;
    for (final t in existingTables) {
      final num = int.tryParse(t.tableNumber);
      if (num != null && num >= nextTableNumber) {
        nextTableNumber = num + 1;
      }
    }
    tableNumberController.text = nextTableNumber.toString();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Table'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: tableNumberController,
              decoration: const InputDecoration(
                labelText: 'Table Number / Name',
                hintText: '1, John\'s Tab, VIP Room, etc.',
              ),
              autofocus: true,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: capacityController,
              decoration: const InputDecoration(labelText: 'Capacity (optional)', hintText: 'Number of seats'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final tableNumber = tableNumberController.text.trim();
              final capacity = int.tryParse(capacityController.text.trim());

              if (tableNumber.isNotEmpty) {
                final newTable = OutletTable(
                  id: '',
                  outletId: outletId,
                  roomName: roomName,
                  tableNumber: tableNumber,
                  capacity: capacity,
                  active: true,
                  sortOrder: int.tryParse(tableNumber) ?? 0,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );

                context.read<TableLayoutProvider>().addOrUpdateTable(newTable);
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditTableDialog(BuildContext context, String outletId, OutletTable table) {
    final tableNumberController = TextEditingController(text: table.tableNumber);
    final capacityController = TextEditingController(text: table.capacity?.toString() ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Table'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: tableNumberController,
              decoration: const InputDecoration(
                labelText: 'Table Number / Name',
                hintText: '1, John\'s Tab, VIP Room, etc.',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: capacityController,
              decoration: const InputDecoration(labelText: 'Capacity (optional)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final tableNumber = tableNumberController.text.trim();
              final capacity = int.tryParse(capacityController.text.trim());

              if (tableNumber.isNotEmpty) {
                final updatedTable = table.copyWith(
                  tableNumber: tableNumber,
                  capacity: capacity,
                  updatedAt: DateTime.now(),
                );

                context.read<TableLayoutProvider>().addOrUpdateTable(updatedTable, isUpdate: true);
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteTable(BuildContext context, String outletId, OutletTable table) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Table'),
        content: Text('Are you sure you want to delete ${table.displayName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              context.read<TableLayoutProvider>().deleteTable(outletId, table.id, table.roomName);
              Navigator.pop(dialogContext);
            },
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteRoom(BuildContext context, String outletId, String roomName) {
    final tableProvider = context.read<TableLayoutProvider>();
    final tableCount = tableProvider.tablesForRoom.length;
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Room'),
        content: Text(
          'Are you sure you want to delete "$roomName"?\n\n'
          'This will delete all $tableCount table${tableCount == 1 ? '' : 's'} in this room.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              context.read<TableLayoutProvider>().deleteRoom(outletId, roomName);
              Navigator.pop(dialogContext);
            },
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

/// Right panel - Drag and drop canvas
class _RightPanel extends StatefulWidget {
  final String outletId;

  const _RightPanel({required this.outletId});

  @override
  State<_RightPanel> createState() => _RightPanelState();
}

class _RightPanelState extends State<_RightPanel> {
  double _zoomLevel = 1.0;
  final TransformationController _transformController = TransformationController();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tableProvider = context.watch<TableLayoutProvider>();

    if (tableProvider.selectedRoomName == null) {
      return _buildEmptyCanvas(theme, colorScheme);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Controls bar
        Container(
          padding: AppSpacing.paddingMd,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            border: Border(bottom: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2))),
          ),
          child: Row(
            children: [
              Text('Room: ${tableProvider.selectedRoomName}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                onPressed: () => setState(() {
                  _zoomLevel = (_zoomLevel - 0.1).clamp(0.5, 2.0);
                  _transformController.value = Matrix4.identity()..scale(_zoomLevel);
                }),
                icon: const Icon(Icons.zoom_out),
                tooltip: 'Zoom Out',
              ),
              Text('${(_zoomLevel * 100).toInt()}%', style: theme.textTheme.bodyMedium),
              IconButton(
                onPressed: () => setState(() {
                  _zoomLevel = (_zoomLevel + 0.1).clamp(0.5, 2.0);
                  _transformController.value = Matrix4.identity()..scale(_zoomLevel);
                }),
                icon: const Icon(Icons.zoom_in),
                tooltip: 'Zoom In',
              ),
              const SizedBox(width: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Reset Layout'),
                      content: const Text('This will reset all table positions to default. Continue?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
                        FilledButton(
                          onPressed: () {
                            tableProvider.resetTablePositions(widget.outletId);
                            Navigator.pop(dialogContext);
                          },
                          child: const Text('Reset'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Reset Layout'),
              ),
            ],
          ),
        ),

        // Canvas area
        Expanded(
          child: Container(
            color: colorScheme.surface,
            child: CustomPaint(
              painter: _GridPainter(colorScheme: colorScheme),
              child: InteractiveViewer(
                transformationController: _transformController,
                boundaryMargin: const EdgeInsets.all(100),
                minScale: 0.5,
                maxScale: 2.0,
                child: SizedBox(
                  width: 2000,
                  height: 2000,
                  child: Stack(
                    children: tableProvider.tablesForRoom.map((table) {
                      return _DraggableTableCard(
                        key: ValueKey(table.id),
                        table: table,
                        isSelected: tableProvider.selectedTableId == table.id,
                        onTap: () => tableProvider.selectTable(table.id),
                        onDragEnd: (x, y) => tableProvider.updateTablePosition(table.id, x, y),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCanvas(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.grid_on, size: 64, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: AppSpacing.md),
          Text('Select a room to view layout', style: theme.textTheme.titleMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }
}

/// Grid painter for canvas background
class _GridPainter extends CustomPainter {
  final ColorScheme colorScheme;

  _GridPainter({required this.colorScheme});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = colorScheme.outline.withValues(alpha: 0.1)
      ..strokeWidth = 1;

    const gridSize = 50.0;

    // Draw vertical lines
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw horizontal lines
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Draggable table card
class _DraggableTableCard extends StatefulWidget {
  final OutletTable table;
  final bool isSelected;
  final VoidCallback onTap;
  final Function(double x, double y) onDragEnd;

  const _DraggableTableCard({
    super.key,
    required this.table,
    required this.isSelected,
    required this.onTap,
    required this.onDragEnd,
  });

  @override
  State<_DraggableTableCard> createState() => _DraggableTableCardState();
}

class _DraggableTableCardState extends State<_DraggableTableCard> {
  late double _x;
  late double _y;

  @override
  void initState() {
    super.initState();
    final tableNum = int.tryParse(widget.table.tableNumber) ?? 0;
    _x = widget.table.posX ?? (100.0 + (tableNum * 50.0));
    _y = widget.table.posY ?? (100.0 + (tableNum * 50.0));
  }

  @override
  void didUpdateWidget(_DraggableTableCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.table.posX != null && widget.table.posY != null) {
      _x = widget.table.posX!;
      _y = widget.table.posY!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Positioned(
      left: _x,
      top: _y,
      child: GestureDetector(
        onTap: widget.onTap,
        onPanUpdate: (details) {
          setState(() {
            _x += details.delta.dx;
            _y += details.delta.dy;
            _x = _x.clamp(0, 1900);
            _y = _y.clamp(0, 1900);
          });
        },
        onPanEnd: (_) => widget.onDragEnd(_x, _y),
        child: _buildTableShape(context, theme, colorScheme),
      ),
    );
  }

  Widget _buildTableShape(BuildContext context, ThemeData theme, ColorScheme colorScheme) {
    final capacity = widget.table.capacity ?? 2;
    
    // Shape logic based on capacity:
    // 2 persons = square
    // 3-4 persons = rectangle (horizontal)
    // 5+ persons = larger rectangle
    
    if (capacity == 2) {
      return _buildSquare(theme, colorScheme, 100, 100);
    } else if (capacity >= 3 && capacity <= 4) {
      return _buildRectangle(theme, colorScheme, 140, 80);
    } else {
      // 5+ capacity: larger rectangle
      return _buildRectangle(theme, colorScheme, 160, 90);
    }
  }

  Widget _buildSquare(ThemeData theme, ColorScheme colorScheme, double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: widget.table.active
            ? (widget.isSelected ? colorScheme.primaryContainer : colorScheme.surface)
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: widget.isSelected ? colorScheme.primary : colorScheme.outline,
          width: widget.isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.table.tableNumber,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: widget.table.active ? colorScheme.primary : colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            if (widget.table.capacity != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person, size: 14, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 2),
                  Text(
                    widget.table.capacity.toString(),
                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRectangle(ThemeData theme, ColorScheme colorScheme, double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: widget.table.active
            ? (widget.isSelected ? colorScheme.primaryContainer : colorScheme.surface)
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: widget.isSelected ? colorScheme.primary : colorScheme.outline,
          width: widget.isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.table.tableNumber,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: widget.table.active ? colorScheme.primary : colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            if (widget.table.capacity != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person, size: 14, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 2),
                  Text(
                    widget.table.capacity.toString(),
                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

}
