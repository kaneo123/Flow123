# EPOS Till System Architecture

## Overview
A full-featured EPOS (Electronic Point of Sale) Till interface with product grid on the left (60%) and order panel on the right (40%). Touch-optimized for Android tablets and Windows touchscreens with Supabase backend integration.

## Key Features
- **Product Grid (Left 60%)**: Category tabs + responsive product grid (3-5 columns)
- **Order Panel (Right 40%)**: Current order with item modifications, quantity controls, pricing
- **Top App Bar**: Outlet selector, search bar, staff login, settings, sync status
- **Bottom Action Bar**: Checkout, Park Sale, Clear Sale, Table Selection
- **Responsive Layout**: Mobile (stacked), Tablet (split), Desktop (extended split)
- **Supabase Integration**: Products, categories, outlets, tax rates, staff data
- **MVVM Pattern**: UI → Provider → Service architecture

## Database Schema (Supabase)

### Tables Required:
1. **outlets** - Store locations/registers
   - id, name, address, is_active, settings (JSONB)
   
2. **categories** - Product categories
   - id, outlet_id, name, display_order, color, is_active
   
3. **products** - Products/menu items
   - id, outlet_id, category_id, name, price, image_url, sku, tax_rate_id, is_active
   
4. **tax_rates** - VAT/Tax configurations
   - id, name, rate (decimal), is_default
   
5. **staff** - Staff accounts
   - id, name, email, pin_code, role, outlet_id, is_active

6. **sales** - Completed transactions (placeholder for future)
   - id, outlet_id, staff_id, items (JSONB), total, tax, discount, payment_type, timestamp

## Directory Structure

```
lib/
├── models/
│   ├── outlet.dart
│   ├── category.dart
│   ├── product.dart
│   ├── tax_rate.dart
│   ├── staff.dart
│   ├── order_item.dart
│   └── order.dart
├── services/
│   ├── local_storage_service.dart (temporary storage)
│   ├── outlet_service.dart
│   ├── category_service.dart
│   ├── product_service.dart
│   ├── tax_rate_service.dart
│   ├── staff_service.dart
│   └── order_service.dart
├── providers/
│   ├── navigation_provider.dart
│   ├── outlet_provider.dart
│   ├── product_provider.dart
│   ├── order_provider.dart
│   ├── staff_provider.dart
│   └── login_provider.dart
├── screens/
│   ├── staff_login_screen.dart
│   ├── till_screen.dart
│   └── dashboard_screen.dart
├── widgets/
│   ├── till/
│   │   ├── top_app_bar.dart
│   │   ├── outlet_selector.dart
│   │   ├── search_bar_widget.dart
│   │   ├── staff_button.dart
│   │   ├── sync_indicator.dart
│   │   ├── product_grid_panel.dart
│   │   ├── category_tabs.dart
│   │   ├── product_button.dart
│   │   ├── order_panel.dart
│   │   ├── order_item_tile.dart
│   │   ├── order_summary.dart
│   │   └── bottom_action_bar.dart
│   └── common/
│       └── custom_button.dart
└── main.dart
```

## Color Theme
- **Primary Accent**: Emerald green (#10B981) for success actions (Checkout)
- **Secondary**: Slate blue (#64748B) for neutral actions
- **Error/Warning**: Amber (#F59E0B) for warnings, Red (#EF4444) for errors
- **Background**: Light cream (#FAFAF9) for main, white for panels
- **Text**: Charcoal (#1F2937) primary, Gray (#6B7280) secondary

## Implementation Steps

### Phase 1: Setup & Data Models
1. ✅ Add dependencies: provider, supabase_flutter
2. ✅ Create all data models with toJson/fromJson
3. ✅ Implement SupabaseService singleton
4. ✅ Create all service classes

### Phase 2: Providers & State Management
5. ✅ Create OutletProvider (current outlet, outlet list)
6. ✅ Create ProductProvider (categories, products by category)
7. ✅ Create OrderProvider (current order, add/remove items, calculate totals)
8. ✅ Create StaffProvider (current staff, login/logout)

### Phase 3: UI Components (Reusable Widgets)
9. ✅ Build TopAppBar with outlet selector, search, staff button, sync indicator
10. ✅ Build ProductGridPanel with CategoryTabs and ProductButton grid
11. ✅ Build OrderPanel with OrderItemTile list and OrderSummary
12. ✅ Build BottomActionBar with action buttons

### Phase 4: Main Screen Assembly
13. ✅ Create TillScreen with responsive layout:
    - Desktop/Tablet: Row with 60/40 split
    - Mobile: Column with scrollable product grid + sticky order panel
14. ✅ Wire up all providers to main.dart

### Phase 5: Business Logic
15. ✅ Implement outlet switching → reload categories/products
16. ✅ Implement product search across all products
17. ✅ Implement order calculations (subtotal, tax, service charge, discounts, total)
18. ✅ Implement quantity increment/decrement
19. ✅ Implement park/clear sale functionality

### Phase 6: Placeholders & Future Features
20. ✅ Add placeholder dialogs for:
    - Staff login/logout
    - Payment types
    - Discount application
    - Table selection (restaurant mode)
21. ✅ Add sync status indicator (online/offline detection)
22. ✅ Add comments for printer integration points

### Phase 7: Testing & Polish
23. ✅ Test responsive layouts on different screen sizes
24. ✅ Compile project and fix all Dart errors
25. ✅ Final UI polish and animations

## Responsive Breakpoints
- **Mobile**: < 600px width → Stacked layout
- **Tablet**: 600-1200px → Split view (50/50 or 60/40)
- **Desktop**: > 1200px → Extended split view (60/40)

## Authentication & Navigation (Latest)

### Staff Login System
- **Login Screen**: Full-screen PIN entry page shown on app launch
- **PIN Entry**: 4-6 digit numeric keypad (3x4 grid layout)
- **Security**: PINs stored in staff table, validated against outlet
- **Flow**: Login → Till Screen → Logout → Login
- **Features**:
  - Obscured PIN display with animated dots
  - Shake animation on invalid PIN
  - Error messaging
  - Auto-submit when 6 digits entered
  - Touch-optimized buttons (80-120px)
  - Responsive for portrait & landscape

### Simplified Navigation Menu
The navigation has been streamlined to include only:
1. **Till** - Main EPOS interface (default home page)
2. **Settings** - App configuration (placeholder)
3. **Logout** - Staff logout functionality (redirects to login)

### Collapsible Side Rail
- **Desktop/Large Screens (≥1024px)**:
  - Expanded mode: 280px width with full menu (icons + labels + header info)
  - Collapsed mode: 72px width with icons only
  - Toggle button at bottom of rail to collapse/expand
- **Mobile/Tablet (<1024px)**:
  - Standard drawer that slides over content
  - Hamburger menu icon in top app bar
  - No collapse feature on mobile

### Sample Staff Credentials
For testing purposes, sample staff accounts are auto-created:
- **Manager**: PIN 1234 (John Manager)
- **Cashier**: PIN 5678 (Sarah Cashier)

## Future Enhancements (Placeholders)
- Printer integration (USB/LAN/Bluetooth)
- Payment terminal integration
- Customer loyalty program
- Offline mode with local SQLite sync
- Receipt printing
- Sales reports
- Inventory management
- Staff management screens
- Multi-currency support
