import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flowtill/providers/login_provider.dart';
import 'package:flowtill/providers/staff_provider.dart';
import 'package:flowtill/providers/outlet_provider.dart';
import 'package:flowtill/providers/order_provider.dart';
import 'package:flowtill/providers/catalog_provider.dart';
import 'package:flowtill/theme.dart';

/// Full-screen staff login page with PIN entry
class StaffLoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const StaffLoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends State<StaffLoginScreen> {
  bool _catalogPreloaded = false;

  @override
  void initState() {
    super.initState();
    // Load outlets when login screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeLoginData();
    });
  }

  Future<void> _initializeLoginData() async {
    final outletProvider = context.read<OutletProvider>();
    final catalogProvider = context.read<CatalogProvider>();
    
    // Load outlets first
    await outletProvider.loadOutlets();
    
    // If an outlet is available, preload catalog in the background
    final currentOutlet = outletProvider.currentOutlet;
    if (currentOutlet != null && !_catalogPreloaded) {
      debugPrint('🚀 LoginScreen: Preloading catalog for outlet: ${currentOutlet.name}');
      _catalogPreloaded = true;
      
      // Load catalog in background (non-blocking)
      catalogProvider.loadCatalog(currentOutlet.id).then((_) {
        debugPrint('✅ LoginScreen: Catalog preloaded successfully');
      }).catchError((e) {
        debugPrint('❌ LoginScreen: Catalog preload failed - $e');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LoginProvider(),
      child: _StaffLoginContent(onLoginSuccess: widget.onLoginSuccess),
    );
  }
}

class _StaffLoginContent extends StatelessWidget {
  final VoidCallback onLoginSuccess;

  const _StaffLoginContent({required this.onLoginSuccess});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableHeight = constraints.maxHeight;
            final availableWidth = constraints.maxWidth;
            final isLandscape = availableWidth > availableHeight;
            
            // Calculate responsive sizes with tighter constraints
            final logoSize = (availableHeight * 0.07).clamp(40.0, 70.0);
            final verticalPadding = (availableHeight * 0.015).clamp(8.0, 16.0);
            final horizontalPadding = (availableWidth * 0.05).clamp(16.0, 40.0);
            final headerSpacing = (availableHeight * 0.015).clamp(8.0, 16.0);
            
            return Center(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: isLandscape ? 600 : 450,
                  maxHeight: availableHeight,
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: verticalPadding,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      flex: 0,
                      child: _buildHeader(context, logoSize),
                    ),
                    SizedBox(height: headerSpacing),
                    Flexible(
                      flex: 1,
                      child: _buildLoginCard(context, availableHeight),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, double logoSize) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final titleFontSize = (logoSize * 0.5).clamp(20.0, 32.0);
    final subtitleFontSize = (logoSize * 0.3).clamp(14.0, 20.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: logoSize,
          height: logoSize,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Icon(
            Icons.point_of_sale,
            size: logoSize * 0.6,
            color: colorScheme.primary,
          ),
        ),
        SizedBox(height: logoSize * 0.1),
        Text(
          'FlowTill',
          style: theme.textTheme.headlineLarge?.copyWith(
            fontSize: titleFontSize,
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: logoSize * 0.05),
        Text(
          'Staff Login',
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: subtitleFontSize,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard(BuildContext context, double availableHeight) {
    final theme = Theme.of(context);
    final cardPadding = (availableHeight * 0.02).clamp(10.0, 20.0);
    final elementSpacing = (availableHeight * 0.01).clamp(6.0, 12.0);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Padding(
        padding: EdgeInsets.all(cardPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _OutletSelector(),
            SizedBox(height: elementSpacing),
            Text(
              'Enter your 4 digit PIN',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: elementSpacing),
            const _PinDisplay(),
            SizedBox(height: elementSpacing * 0.5),
            const _ErrorMessage(),
            SizedBox(height: elementSpacing * 0.3),
            const _LoadingIndicator(),
            SizedBox(height: elementSpacing),
            Flexible(child: _NumericKeypad(availableHeight: availableHeight)),
          ],
        ),
      ),
    );
  }
}

/// Outlet selector dropdown with comprehensive error handling
class _OutletSelector extends StatefulWidget {
  const _OutletSelector();

  @override
  State<_OutletSelector> createState() => _OutletSelectorState();
}

class _OutletSelectorState extends State<_OutletSelector> {
  String? _previousOutletId;

  @override
  Widget build(BuildContext context) {
    final outletProvider = context.watch<OutletProvider>();
    final catalogProvider = context.read<CatalogProvider>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Loading state
    if (outletProvider.isLoading) {
      return Container(
        height: 56,
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outline),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            const SizedBox(width: AppSpacing.md),
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              'Loading outlets...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    // Error state
    if (outletProvider.hasError) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: colorScheme.error),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: colorScheme.error, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Failed to Load Outlets',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onErrorContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              outletProvider.errorMessage ?? 'Unknown error',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => outletProvider.refresh(),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.error,
                  side: BorderSide(color: colorScheme.error),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Empty state
    if (!outletProvider.hasOutlets) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: colorScheme.outline),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: colorScheme.secondary, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'No Outlets Found',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Please add outlets using the Supabase panel before logging in.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSecondaryContainer,
              ),
            ),
          ],
        ),
      );
    }

    // Success state - show dropdown
    return DropdownButtonFormField<String>(
      value: outletProvider.currentOutlet?.id,
      decoration: InputDecoration(
        labelText: 'Select Outlet',
        prefixIcon: const Icon(Icons.store),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
      ),
      items: outletProvider.outlets.map((outlet) {
        return DropdownMenuItem(
          value: outlet.id,
          child: Text(outlet.name),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          final outlet = outletProvider.outlets.firstWhere((o) => o.id == value);
          outletProvider.setCurrentOutlet(outlet);
          
          // Reload catalog when outlet changes
          if (_previousOutletId != value) {
            debugPrint('🔄 LoginScreen: Outlet changed, reloading catalog...');
            _previousOutletId = value;
            catalogProvider.loadCatalog(value);
          }
        }
      },
    );
  }
}

/// PIN display with obscured circles/dots
class _PinDisplay extends StatefulWidget {
  const _PinDisplay();

  @override
  State<_PinDisplay> createState() => _PinDisplayState();
}

class _PinDisplayState extends State<_PinDisplay> with SingleTickerProviderStateMixin {
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 10)
      .chain(CurveTween(curve: Curves.elasticIn))
      .animate(_shakeController);
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loginProvider = context.watch<LoginProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    // Trigger shake animation when error occurs
    if (loginProvider.shouldShake) {
      _shakeController.forward(from: 0);
    }

    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) => Transform.translate(
        offset: Offset(_shakeAnimation.value, 0),
        child: child,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(4, (index) {
          final isFilled = index < loginProvider.pinLength;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isFilled ? colorScheme.primary : Colors.transparent,
              border: Border.all(
                color: isFilled ? colorScheme.primary : colorScheme.outline,
                width: 2,
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Error message display area
class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage();

  @override
  Widget build(BuildContext context) {
    final loginProvider = context.watch<LoginProvider>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SizedBox(
      height: 16,
      child: loginProvider.errorMessage.isNotEmpty
        ? Text(
            loginProvider.errorMessage,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: colorScheme.error,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          )
        : null,
    );
  }
}

/// Loading indicator shown during authentication
class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    final loginProvider = context.watch<LoginProvider>();

    return SizedBox(
      height: 18,
      child: loginProvider.isLoading
        ? const Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        : null,
    );
  }
}

/// Numeric keypad (3x4 grid) - Now fully responsive
class _NumericKeypad extends StatelessWidget {
  final double availableHeight;
  
  const _NumericKeypad({required this.availableHeight});

  @override
  Widget build(BuildContext context) {
    final loginProvider = context.watch<LoginProvider>();
    final outletProvider = context.watch<OutletProvider>();
    final staffProvider = context.read<StaffProvider>();
    
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate button size based on available space with better constraints
        final maxWidth = constraints.maxWidth;
        final maxHeight = constraints.maxHeight;
        
        // Calculate ideal button size from both width and height
        final widthBasedSize = ((maxWidth / 3) - 16).clamp(50.0, 100.0);
        final heightBasedSize = ((maxHeight / 4.5) - 8).clamp(50.0, 100.0);
        
        // Use the smaller of the two to ensure it fits
        final buttonSize = widthBasedSize < heightBasedSize ? widthBasedSize : heightBasedSize;
        final spacing = (buttonSize * 0.12).clamp(4.0, 12.0);

        return Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildKeypadRow(context, ['1', '2', '3'], buttonSize, loginProvider),
            SizedBox(height: spacing),
            _buildKeypadRow(context, ['4', '5', '6'], buttonSize, loginProvider),
            SizedBox(height: spacing),
            _buildKeypadRow(context, ['7', '8', '9'], buttonSize, loginProvider),
            SizedBox(height: spacing),
            _buildKeypadRow(
              context,
              ['C', '0', '⌫'],
              buttonSize,
              loginProvider,
              onClear: () => loginProvider.clear(),
              onBackspace: () => loginProvider.backspace(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildKeypadRow(
    BuildContext context,
    List<String> keys,
    double buttonSize,
    LoginProvider loginProvider, {
    VoidCallback? onClear,
    VoidCallback? onBackspace,
  }) {
    final outletProvider = context.read<OutletProvider>();
    final staffProvider = context.read<StaffProvider>();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: keys.map((key) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: _KeypadButton(
            label: key,
            size: buttonSize,
            onPressed: () async {
              if (key == 'C') {
                onClear?.call();
              } else if (key == '⌫') {
                onBackspace?.call();
              } else {
                // Add digit
                loginProvider.addDigit(key);
                
                // Auto-submit when 4 digits entered
                if (loginProvider.pinLength == 4) {
                  final currentOutletId = outletProvider.currentOutlet?.id ?? '';
                  if (currentOutletId.isEmpty) {
                    loginProvider.setError('No outlet selected');
                    return;
                  }
                  
                  // Call loginWithPin
                  final success = await loginProvider.loginWithPin(currentOutletId);
                  
                  if (success && context.mounted) {
                    // Set the authenticated staff in StaffProvider
                    final authenticatedStaff = loginProvider.authenticatedStaff;
                    if (authenticatedStaff != null) {
                      staffProvider.setCurrentStaff(authenticatedStaff);
                      
                      // Reset catalog navigation to root on login
                      final catalogProvider = context.read<CatalogProvider>();
                      debugPrint('🔄 Login: Resetting catalog navigation to top level');
                      catalogProvider.resetNavigation();
                      
                      // Restore the staff's parked order (if exists)
                      final orderProvider = context.read<OrderProvider>();
                      final restored = orderProvider.restoreOrderForStaff(authenticatedStaff.id);
                      
                      if (!restored) {
                        // No parked order, update the current order's staff ID
                        orderProvider.updateStaffId(authenticatedStaff.id);
                      }
                      
                      // Find the StaffLoginScreen ancestor and call onLoginSuccess
                      // This will use go_router's context.go('/') navigation
                      final loginScreen = context.findAncestorWidgetOfExactType<StaffLoginScreen>();
                      if (loginScreen != null) {
                        loginScreen.onLoginSuccess();
                      }
                    } else {
                      loginProvider.setError('Authentication error. Please try again.');
                    }
                  }
                }
              }
            },
            isDisabled: loginProvider.isLoading,
          ),
        );
      }).toList(),
    );
  }
}

/// Individual keypad button
class _KeypadButton extends StatelessWidget {
  final String label;
  final double size;
  final VoidCallback onPressed;
  final bool isDisabled;

  const _KeypadButton({
    required this.label,
    required this.size,
    required this.onPressed,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSpecial = label == 'C' || label == '⌫';
    
    // Scale font size with button size
    final fontSize = (size * 0.35).clamp(20.0, 32.0);

    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: isSpecial 
          ? colorScheme.surfaceContainerHighest 
          : colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: isDisabled ? null : onPressed,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: isSpecial 
                  ? colorScheme.onSurfaceVariant 
                  : colorScheme.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
