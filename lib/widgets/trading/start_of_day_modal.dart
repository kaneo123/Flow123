import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flowtill/providers/trading_day_provider.dart';
import 'package:flowtill/providers/navigation_provider.dart';
import 'package:flowtill/theme.dart';

/// Modal for starting a trading day with opening float
class StartOfDayModal extends StatefulWidget {
  final String outletId;
  final VoidCallback? onStarted;
  final bool canCancel;

  const StartOfDayModal({
    super.key,
    required this.outletId,
    this.onStarted,
    this.canCancel = true,
  });

  @override
  State<StartOfDayModal> createState() => _StartOfDayModalState();
}

class _StartOfDayModalState extends State<StartOfDayModal> {
  final _floatController = TextEditingController();
  double _suggestedFloat = 0.0;
  double? _lastVariance;
  bool _isLoading = true;
  String _floatSource = 'carry_forward';

  @override
  void initState() {
    super.initState();
    _loadSuggestion();
  }

  Future<void> _loadSuggestion() async {
    final tradingDayProvider = context.read<TradingDayProvider>();
    
    final suggestedFloat = await tradingDayProvider.getSuggestedOpeningFloat(widget.outletId);
    final lastVariance = await tradingDayProvider.getLastDayVariance(widget.outletId);

    setState(() {
      _suggestedFloat = suggestedFloat;
      _lastVariance = lastVariance;
      _floatController.text = suggestedFloat.toStringAsFixed(2);
      _floatSource = suggestedFloat > 0 ? 'carry_forward' : 'zero';
      _isLoading = false;
    });
  }

  void _useSuggested() {
    setState(() {
      _floatController.text = _suggestedFloat.toStringAsFixed(2);
      _floatSource = _suggestedFloat > 0 ? 'carry_forward' : 'zero';
    });
  }

  void _setZero() {
    setState(() {
      _floatController.text = '0.00';
      _floatSource = 'zero';
    });
  }

  Future<void> _startDay() async {
    final float = double.tryParse(_floatController.text) ?? 0.0;
    
    if (float < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Opening float cannot be negative')),
      );
      return;
    }

    final navProvider = context.read<NavigationProvider>();
    final tradingDayProvider = context.read<TradingDayProvider>();

    if (navProvider.loggedInStaff == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No staff logged in')),
      );
      return;
    }

    // Determine float source
    String source = _floatSource;
    if (float != _suggestedFloat) {
      source = 'manual';
    }

    final success = await tradingDayProvider.startTradingDay(
      outletId: widget.outletId,
      staffId: navProvider.loggedInStaff!.id,
      openingFloat: float,
      floatSource: source,
    );

    if (success && mounted) {
      Navigator.of(context).pop();
      widget.onStarted?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Trading day started with £${float.toStringAsFixed(2)} float'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tradingDayProvider.error ?? 'Failed to start trading day'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return WillPopScope(
      onWillPop: () async => widget.canCancel,
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Container(
          width: 500,
          padding: AppSpacing.paddingLg,
          child: _isLoading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: CircularProgressIndicator(),
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      children: [
                        Icon(
                          Icons.wb_sunny,
                          size: 32,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            'Start Trading Day',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (widget.canCancel)
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Info text
                    Text(
                      'Set your opening cash float to begin trading',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Suggested float display
                    if (_suggestedFloat > 0) ...[
                      Container(
                        padding: AppSpacing.paddingMd,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                            color: colorScheme.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.lightbulb,
                              color: colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Suggested Float',
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '£${_suggestedFloat.toStringAsFixed(2)}',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      color: colorScheme.onSurface,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (_lastVariance != null && _lastVariance != 0)
                                    Text(
                                      'Last day variance: ${_lastVariance! < 0 ? "-" : "+"}£${_lastVariance!.abs().toStringAsFixed(2)}',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: _lastVariance! < 0
                                            ? colorScheme.error
                                            : Colors.green,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],

                    // Float input
                    Text(
                      'Opening Float Amount',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: _floatController,
                      decoration: InputDecoration(
                        prefixText: '£ ',
                        hintText: '0.00',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        contentPadding: AppSpacing.paddingMd,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                      ],
                      onChanged: (_) => setState(() {
                        _floatSource = 'manual';
                      }),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Quick buttons
                    Row(
                      children: [
                        if (_suggestedFloat > 0) ...[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _useSuggested,
                              icon: const Icon(Icons.history, size: 18),
                              label: const Text('Use Suggested'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                        ],
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _setZero,
                            icon: const Icon(Icons.money_off, size: 18),
                            label: const Text('Set to £0'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (widget.canCancel) ...[
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                        ],
                        Consumer<TradingDayProvider>(
                          builder: (context, provider, _) => FilledButton.icon(
                            onPressed: provider.isLoading ? null : _startDay,
                            icon: provider.isLoading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.check),
                            label: Text(provider.isLoading ? 'Starting...' : 'Start Day'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
