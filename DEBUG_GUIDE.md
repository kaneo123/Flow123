# Enhanced Debugging Guide for Product Flow

## Overview
Enhanced debugging has been added throughout the product data flow to trace the `isCarvery` field and stock information from database to UI.

## What Was Added

### 1. **Product Service** (`lib/services/product_service.dart`)
- Logs raw JSON from Supabase for each product
- Shows the `is_carvery` field value and type from database
- Confirms parsed `isCarvery` value in Product object
- Lists all carvery products found after parsing

### 2. **Catalog Provider** (`lib/providers/catalog_provider.dart`)
- Counts carvery products after loading from service
- Lists all carvery products with their details
- Traces products as they're grouped into categories
- Shows carvery products in the current display list
- Tracks how many products are shown before/after filtering

### 3. **Stock Service** (`lib/services/stock_service.dart`)
- Counts carvery products being processed
- Shows stock tracking mode for each carvery product (basic vs enhanced)
- Displays recipe components and portion calculations for enhanced mode
- Summarizes which carvery products have stock info and which don't

### 4. **Product Grid Panel** (`lib/widgets/till/product_grid_panel.dart`)
- Shows product count before and after stock filtering
- Lists carvery products with their stock status
- Logs when products are hidden due to out-of-stock + auto-hide

### 5. **Product Button** (`lib/widgets/till/product_button.dart`)
- Logs when carvery products are being rendered
- Shows availability and disabled state

## How to Debug via ADB

### 1. Connect Your Device
```bash
adb pair <device-ip>:port
adb connect <device-ip>:port
```

### 2. Start Watching Logs
```bash
adb logcat | grep -E "🛍️|📦|🔍|🥩|🗂️|🎨"
```

Or to see ALL debug prints:
```bash
adb logcat | grep "flutter:"
```

### 3. What to Look For

#### **When Products Load:**
Look for these sequences:

```
🛍️ ProductService: Fetching products for outlet...
📦 ProductService: Received X products from Supabase
🔍 ProductService._fromSupabaseJson: Parsing product
   ID: <product-id>
   Name: <product-name>
   is_carvery raw: true (type: bool)
   is_carvery parsed: true
   ✅ Product object created - isCarvery field: true

🔎 ProductService: Products with isCarvery=true:
   ✓ Roast Beef (id) - isCarvery: true
```

#### **When Catalog Loads:**
```
🔍 CatalogProvider: Loaded X products
🔍 CatalogProvider: Products with isCarvery=true: 3
🔍 CatalogProvider: Carvery products:
   ✓ Roast Beef (id)
     - categoryId: xxx
     - price: £X.XX
     - trackStock: true
```

#### **When Stock Loads:**
```
📦 StockService: X carvery products to process
   🥩 Roast Beef (id) - trackStock: true, linkedInventory: null
   🥩 Roast Beef: Enhanced mode with 1 components
      - Beef Joint: 5000 avail, need 250 per portion → 20 portions
      → Min portions: 20
📊 StockService: 3/3 carvery products have stock info
```

#### **When Displaying Products:**
```
🗂️ CatalogProvider.getCurrentProductsForDisplay: Category xxx
   Direct products: 10
   🥩 Carvery products in display: 3
      - Roast Beef (id)

🗂️ ProductGridPanel._buildProductGrid: Got 10 products for display
   🥩 Carvery products before filtering: 3
      - Roast Beef (isCarvery=true, trackStock=true, autoHide=false)
        Stock: tracked=true, outOfStock=false
   🥩 Carvery products after filtering: 3
   📊 Final product count for display: 10
```

#### **When Rendering:**
```
🎨 ProductButton.build: Rendering carvery product
   Name: Roast Beef
   ID: xxx
   isCarvery: true
   Price: £X.XX
   isAvailable: true
   isDisabled: false
```

## Common Issues to Look For

### Issue 1: isCarvery not in database
**Symptoms:**
```
🔍 ProductService._fromSupabaseJson: Parsing product
   is_carvery raw: null
   is_carvery parsed: false
```
**Solution:** Check your Supabase `products` table schema

### Issue 2: Products parsed but not showing
**Symptoms:**
```
🔍 CatalogProvider: Products with isCarvery=true: 3
...
🗂️ ProductGridPanel._buildProductGrid: Got 0 products for display
```
**Solution:** Check category navigation - might not be in the right category

### Issue 3: Products filtered out
**Symptoms:**
```
🥩 Carvery products before filtering: 3
⚠️ Hiding out-of-stock product: Roast Beef
🥩 Carvery products after filtering: 2
```
**Solution:** Product is out of stock and has `autoHideWhenOutOfStock=true`

### Issue 4: Stock info missing
**Symptoms:**
```
⚠️ StockService: Carvery products WITHOUT stock info:
   - Roast Beef (id)
```
**Solution:** Product needs either `linkedInventoryItemId` OR a recipe with components

## Quick Test Checklist

1. ✅ Products load from Supabase with `is_carvery` field
2. ✅ `isCarvery` field parsed correctly to Product object
3. ✅ Carvery products appear in catalog provider's product list
4. ✅ Carvery products grouped into correct categories
5. ✅ Stock info loaded for carvery products (if trackStock=true)
6. ✅ Carvery products appear in `getCurrentProductsForDisplay()`
7. ✅ Carvery products survive filtering (not hidden)
8. ✅ ProductButton renders for carvery products
9. ✅ Carvery products visible in UI

## Emoji Legend
- 🛍️ Product Service operations
- 📦 Stock Service operations
- 🔍 Data parsing and inspection
- 🥩 Carvery-specific logs
- 🗂️ Catalog/Category operations
- 🎨 UI rendering
- ✅ Success
- ⚠️ Warning
- ❌ Error
