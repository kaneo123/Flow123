// Receipt Formatting Settings Widget for Printer Settings Screen
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flowtill/models/outlet.dart';
import 'package:flowtill/providers/outlet_provider.dart';
import 'package:flowtill/services/printer/printer_service.dart';
import 'package:flowtill/theme.dart';
import 'package:intl/intl.dart';

class ReceiptFormattingSettings extends StatefulWidget {
  const ReceiptFormattingSettings({super.key});

  @override
  State<ReceiptFormattingSettings> createState() => _ReceiptFormattingSettingsState();
}

class _ReceiptFormattingSettingsState extends State<ReceiptFormattingSettings> {
  final TextEditingController _headerController = TextEditingController();
  final TextEditingController _footerController = TextEditingController();
  final TextEditingController _logoUrlController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _headerController.dispose();
    _footerController.dispose();
    _logoUrlController.dispose();
    super.dispose();
  }

  String _replacePlaceholders(String text, Outlet outlet) {
    return text
        .replaceAll('{outletName}', outlet.name)
        .replaceAll('{address}', outlet.fullAddress)
        .replaceAll('{phone}', outlet.phone ?? '')
        .replaceAll('{time}', DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final outletProvider = context.watch<OutletProvider>();
    final outlet = outletProvider.currentOutlet;
    
    if (outlet == null) {
      return const Padding(
        padding: AppSpacing.paddingLg,
        child: Text('No outlet selected'),
      );
    }

    // Update controllers when outlet changes
    if (_headerController.text.isEmpty && outlet.receiptHeaderText.isNotEmpty) {
      _headerController.text = outlet.receiptHeaderText;
    }
    if (_footerController.text.isEmpty && outlet.receiptFooterText.isNotEmpty) {
      _footerController.text = outlet.receiptFooterText;
    }
    if (_logoUrlController.text.isEmpty && outlet.receiptLogoUrl != null) {
      _logoUrlController.text = outlet.receiptLogoUrl!;
    }

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: AppSpacing.paddingLg,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.lg),
                topRight: Radius.circular(AppRadius.lg),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.receipt,
                  color: colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  'Receipt Formatting',
                  style: context.textStyles.titleLarge?.bold,
                ),
              ],
            ),
          ),

          // Header Text
          Padding(
            padding: AppSpacing.paddingLg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Header Text',
                  style: context.textStyles.titleMedium?.semiBold,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _headerController,
                  maxLines: 3,
                  enabled: !_isSaving,
                  decoration: InputDecoration(
                    hintText: 'e.g. {outletName}\n{address}\n{phone}',
                    helperText: 'Placeholders: {outletName}, {address}, {phone}, {time}',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: colorScheme.outline.withValues(alpha: 0.1)),

          // Footer Text
          Padding(
            padding: AppSpacing.paddingLg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Footer Text',
                  style: context.textStyles.titleMedium?.semiBold,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _footerController,
                  maxLines: 3,
                  enabled: !_isSaving,
                  decoration: InputDecoration(
                    hintText: 'e.g. Thank you for your visit!\nWe hope to see you again soon.',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: colorScheme.outline.withValues(alpha: 0.1)),

          // Logo Settings
          SwitchListTile(
            contentPadding: AppSpacing.paddingLg,
            title: Text(
              'Show Logo on Receipt',
              style: context.textStyles.titleMedium?.semiBold,
            ),
            value: outlet.receiptShowLogo,
            onChanged: _isSaving ? null : (bool value) async {
              setState(() => _isSaving = true);
              final success = await outletProvider.updateOutlet(outlet.id, {
                'receipt_show_logo': value,
              });
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Logo display ${value ? 'enabled' : 'disabled'}' : 'Failed to update'),
                    backgroundColor: success ? null : Colors.red,
                  ),
                );
              }
              setState(() => _isSaving = false);
            },
          ),

          if (outlet.receiptShowLogo) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: TextField(
                controller: _logoUrlController,
                enabled: !_isSaving,
                decoration: InputDecoration(
                  labelText: 'Logo URL',
                  helperText: 'Image will be auto-scaled to max width 350px',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          Divider(height: 1, color: colorScheme.outline.withValues(alpha: 0.1)),

          // Font Size
          Padding(
            padding: AppSpacing.paddingLg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Font Size: ${outlet.receiptFontSize}',
                  style: context.textStyles.titleMedium?.semiBold,
                ),
                Slider(
                  value: outlet.receiptFontSize.toDouble(),
                  min: 16,
                  max: 32,
                  divisions: 16,
                  label: outlet.receiptFontSize.toString(),
                  onChanged: _isSaving ? null : (value) async {
                    setState(() => _isSaving = true);
                    await outletProvider.updateOutlet(outlet.id, {
                      'receipt_font_size': value.toInt(),
                    });
                    setState(() => _isSaving = false);
                  },
                ),
              ],
            ),
          ),

          Divider(height: 1, color: colorScheme.outline.withValues(alpha: 0.1)),

          // Line Spacing
          Padding(
            padding: AppSpacing.paddingLg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Line Spacing: ${outlet.receiptLineSpacing}',
                  style: context.textStyles.titleMedium?.semiBold,
                ),
                Slider(
                  value: outlet.receiptLineSpacing.toDouble(),
                  min: 2,
                  max: 10,
                  divisions: 8,
                  label: outlet.receiptLineSpacing.toString(),
                  onChanged: _isSaving ? null : (value) async {
                    setState(() => _isSaving = true);
                    await outletProvider.updateOutlet(outlet.id, {
                      'receipt_line_spacing': value.toInt(),
                    });
                    setState(() => _isSaving = false);
                  },
                ),
              ],
            ),
          ),

          Divider(height: 1, color: colorScheme.outline.withValues(alpha: 0.1)),

          // Visibility Toggles
          SwitchListTile(
            contentPadding: AppSpacing.paddingLg,
            title: Text(
              'Show VAT Breakdown',
              style: context.textStyles.titleMedium,
            ),
            value: outlet.receiptShowVatBreakdown,
            onChanged: _isSaving ? null : (value) async {
              setState(() => _isSaving = true);
              await outletProvider.updateOutlet(outlet.id, {
                'receipt_show_vat_breakdown': value,
              });
              setState(() => _isSaving = false);
            },
          ),

          Divider(height: 1, color: colorScheme.outline.withValues(alpha: 0.1)),

          SwitchListTile(
            contentPadding: AppSpacing.paddingLg,
            title: Text(
              'Show Service Charge',
              style: context.textStyles.titleMedium,
            ),
            value: outlet.receiptShowServiceCharge,
            onChanged: _isSaving ? null : (value) async {
              setState(() => _isSaving = true);
              await outletProvider.updateOutlet(outlet.id, {
                'receipt_show_service_charge': value,
              });
              setState(() => _isSaving = false);
            },
          ),

          Divider(height: 1, color: colorScheme.outline.withValues(alpha: 0.1)),

          SwitchListTile(
            contentPadding: AppSpacing.paddingLg,
            title: Text(
              'Show Promotions / Loyalty Cards',
              style: context.textStyles.titleMedium,
            ),
            value: outlet.receiptShowPromotions,
            onChanged: _isSaving ? null : (value) async {
              setState(() => _isSaving = true);
              await outletProvider.updateOutlet(outlet.id, {
                'receipt_show_promotions': value,
              });
              setState(() => _isSaving = false);
            },
          ),

          Divider(height: 1, color: colorScheme.outline.withValues(alpha: 0.1)),

          // Compact Layout Toggle
          SwitchListTile(
            contentPadding: AppSpacing.paddingLg,
            title: Text(
              'Use Compact Layout',
              style: context.textStyles.titleMedium?.semiBold,
            ),
            subtitle: Text(
              'Reduces blank lines and spacing for shorter receipts',
              style: context.textStyles.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            value: outlet.receiptUseCompactLayout,
            onChanged: _isSaving ? null : (value) async {
              setState(() => _isSaving = true);
              await outletProvider.updateOutlet(outlet.id, {
                'receipt_use_compact_layout': value,
              });
              setState(() => _isSaving = false);
            },
          ),

          Divider(height: 1, color: colorScheme.outline.withValues(alpha: 0.1)),

          // Large Total Text Toggle
          SwitchListTile(
            contentPadding: AppSpacing.paddingLg,
            title: Text(
              'Large Total Text',
              style: context.textStyles.titleMedium?.semiBold,
            ),
            subtitle: Text(
              'Display total amount in large bold text',
              style: context.textStyles.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            value: outlet.receiptLargeTotalText,
            onChanged: _isSaving ? null : (value) async {
              setState(() => _isSaving = true);
              await outletProvider.updateOutlet(outlet.id, {
                'receipt_large_total_text': value,
              });
              setState(() => _isSaving = false);
            },
          ),

          Divider(height: 1, color: colorScheme.outline.withValues(alpha: 0.1)),

          // Codepage Selection
          Padding(
            padding: AppSpacing.paddingLg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Character Encoding',
                  style: context.textStyles.titleMedium?.semiBold,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Select the character encoding for proper £ symbol printing. CP437 is recommended for most thermal printers.',
                  style: context.textStyles.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'CP437', label: Text('CP437')),
                            ButtonSegment(value: 'CP858', label: Text('CP858')),
                            ButtonSegment(value: 'CP1252', label: Text('CP1252')),
                            ButtonSegment(value: 'ISO-8859-15', label: Text('ISO-8859-15')),
                          ],
                          selected: {outlet.receiptCodepage},
                          onSelectionChanged: _isSaving ? null : (Set<String> selection) async {
                            setState(() => _isSaving = true);
                            await outletProvider.updateOutlet(outlet.id, {
                              'receipt_codepage': selection.first,
                            });
                            setState(() => _isSaving = false);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Divider(height: 1, color: colorScheme.outline.withValues(alpha: 0.1)),

          // Save Button
          Padding(
            padding: AppSpacing.paddingLg,
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : () async {
                  setState(() => _isSaving = true);
                  
                  final updates = <String, dynamic>{
                    'receipt_header_text': _headerController.text,
                    'receipt_footer_text': _footerController.text,
                  };
                  
                  if (outlet.receiptShowLogo && _logoUrlController.text.isNotEmpty) {
                    updates['receipt_logo_url'] = _logoUrlController.text;
                  }
                  
                  final success = await outletProvider.updateOutlet(outlet.id, updates);
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success ? 'Receipt formatting saved' : 'Failed to save'),
                        backgroundColor: success ? null : Colors.red,
                      ),
                    );
                  }
                  
                  setState(() => _isSaving = false);
                },
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Header & Footer'),
              ),
            ),
          ),

          Divider(height: 1, color: colorScheme.outline.withValues(alpha: 0.1)),

          // Test Print Button
          Padding(
            padding: AppSpacing.paddingLg,
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : () async {
                  try {
                    await PrinterService.instance.printFormattedTestReceipt(outlet);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Test receipt sent to printer')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Print failed: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.print),
                label: const Text('TEST RECEIPT FORMAT'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.secondaryContainer,
                  foregroundColor: colorScheme.onSecondaryContainer,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
