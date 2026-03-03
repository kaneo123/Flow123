import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flowtill/providers/staff_provider.dart';
import 'package:flowtill/providers/outlet_provider.dart';
import 'package:flowtill/providers/order_provider.dart';
import 'package:flowtill/theme.dart';

class StaffButton extends StatelessWidget {
  const StaffButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<StaffProvider>(
      builder: (context, staffProvider, _) {
        final isLoggedIn = staffProvider.isLoggedIn;
        final staffName = staffProvider.currentStaff?.fullName ?? 'Login';

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _handleStaffAction(context, isLoggedIn),
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              padding: AppSpacing.horizontalLg,
              height: 48,
              decoration: BoxDecoration(
                color: isLoggedIn 
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: isLoggedIn
                      ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)
                      : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isLoggedIn ? Icons.person : Icons.person_outline,
                    color: isLoggedIn 
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    staffName,
                    style: context.textStyles.titleSmall?.copyWith(
                      color: isLoggedIn
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleStaffAction(BuildContext context, bool isLoggedIn) {
    if (isLoggedIn) {
      _showLogoutDialog(context);
    } else {
      _showLoginDialog(context);
    }
  }

  void _showLoginDialog(BuildContext context) {
    final pinController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Staff Login'),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 4,
          decoration: const InputDecoration(
            labelText: 'PIN Code',
            hintText: 'Enter 4-digit PIN',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final outletId = context.read<OutletProvider>().currentOutlet?.id;
              if (outletId != null) {
                final staffProvider = context.read<StaffProvider>();
                final success = await staffProvider.login(pinController.text, outletId);
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                  if (success) {
                    // Restore the staff's parked order (if exists)
                    final authenticatedStaff = staffProvider.currentStaff;
                    if (authenticatedStaff != null) {
                      final orderProvider = context.read<OrderProvider>();
                      orderProvider.restoreOrderForStaff(authenticatedStaff.id);
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invalid PIN code')),
                    );
                  }
                }
              }
            },
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final orderProvider = context.read<OrderProvider>();
              context.read<StaffProvider>().logout(
                onParkOrder: (staffId) => orderProvider.parkOrderForStaff(staffId),
              );
              Navigator.pop(dialogContext);
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
