-- FlowTill EPOS Database Schema

-- Outlets table
CREATE TABLE IF NOT EXISTS outlets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  address TEXT NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  settings JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Create index for outlet lookups
CREATE INDEX IF NOT EXISTS idx_outlets_is_active ON outlets(is_active);

-- Tax rates table
CREATE TABLE IF NOT EXISTS tax_rates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  rate DECIMAL(5,4) NOT NULL CHECK (rate >= 0 AND rate <= 1),
  is_default BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Ensure only one default tax rate
CREATE UNIQUE INDEX IF NOT EXISTS idx_tax_rates_single_default ON tax_rates(is_default) WHERE is_default = true;

-- Roles table
CREATE TABLE IF NOT EXISTS roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES outlets(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  is_default BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  level INTEGER NOT NULL DEFAULT 1,
  CONSTRAINT roles_outlet_name_unique UNIQUE (outlet_id, name)
);

-- Create index for role lookups
CREATE INDEX IF NOT EXISTS idx_roles_outlet ON roles(outlet_id);

-- Staff table (without auth.users FK for now)
CREATE TABLE IF NOT EXISTS staff (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES outlets(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  role_id UUID REFERENCES roles(id) ON DELETE SET NULL,
  pin_code TEXT NOT NULL,
  active BOOLEAN NOT NULL DEFAULT true,
  last_login_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT staff_pin_unique_per_outlet UNIQUE (outlet_id, pin_code),
  CONSTRAINT staff_outlet_id_fkey FOREIGN KEY (outlet_id) REFERENCES outlets(id) ON DELETE CASCADE,
  CONSTRAINT staff_role_id_fkey FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE SET NULL
);

-- Create indexes for staff lookups
CREATE INDEX IF NOT EXISTS idx_staff_outlet ON staff(outlet_id);
CREATE INDEX IF NOT EXISTS idx_staff_outlet_role ON staff(outlet_id, role_id);

-- Categories table
CREATE TABLE IF NOT EXISTS categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES outlets(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  display_order INTEGER NOT NULL DEFAULT 0,
  color TEXT NOT NULL DEFAULT '#64748B',
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Create indexes for category lookups
CREATE INDEX IF NOT EXISTS idx_categories_outlet_id ON categories(outlet_id);
CREATE INDEX IF NOT EXISTS idx_categories_display_order ON categories(outlet_id, display_order);

-- Products table
CREATE TABLE IF NOT EXISTS products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES outlets(id) ON DELETE CASCADE,
  category_id UUID NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
  tax_rate_id UUID NOT NULL REFERENCES tax_rates(id),
  name TEXT NOT NULL,
  price DECIMAL(10,2) NOT NULL CHECK (price >= 0),
  image_url TEXT,
  sku TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  is_carvery BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Create indexes for product lookups
CREATE INDEX IF NOT EXISTS idx_products_outlet_id ON products(outlet_id);
CREATE INDEX IF NOT EXISTS idx_products_category_id ON products(category_id);
CREATE INDEX IF NOT EXISTS idx_products_sku ON products(sku);
CREATE INDEX IF NOT EXISTS idx_products_is_active ON products(outlet_id, is_active);

-- Orders table
CREATE TABLE IF NOT EXISTS orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES outlets(id) ON DELETE CASCADE,
  staff_id UUID REFERENCES staff(id) ON DELETE SET NULL,
  discount_amount DECIMAL(10,2) NOT NULL DEFAULT 0 CHECK (discount_amount >= 0),
  service_charge_rate DECIMAL(5,4) NOT NULL DEFAULT 0 CHECK (service_charge_rate >= 0 AND service_charge_rate <= 1),
  table_number TEXT,
  subtotal DECIMAL(10,2) NOT NULL DEFAULT 0,
  tax_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
  total DECIMAL(10,2) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Create indexes for order lookups
CREATE INDEX IF NOT EXISTS idx_orders_outlet_id ON orders(outlet_id);
CREATE INDEX IF NOT EXISTS idx_orders_staff_id ON orders(staff_id);
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at DESC);

-- Order items table
CREATE TABLE IF NOT EXISTS order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES products(id),
  product_name TEXT NOT NULL,
  product_price DECIMAL(10,2) NOT NULL,
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  tax_rate DECIMAL(5,4) NOT NULL,
  modifiers JSONB DEFAULT '[]'::jsonb,
  subtotal DECIMAL(10,2) NOT NULL,
  tax_amount DECIMAL(10,2) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Create indexes for order item lookups
CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_product_id ON order_items(product_id);

-- Updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at triggers to tables
CREATE TRIGGER update_outlets_updated_at BEFORE UPDATE ON outlets
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_tax_rates_updated_at BEFORE UPDATE ON tax_rates
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_staff_updated_at BEFORE UPDATE ON staff
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_categories_updated_at BEFORE UPDATE ON categories
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_products_updated_at BEFORE UPDATE ON products
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Till Adjustments table
-- Tracks cash adjustments (petty cash taken out, money removed from till, or float added in)
CREATE TABLE IF NOT EXISTS till_adjustments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES outlets(id) ON DELETE CASCADE,
  staff_id UUID NOT NULL REFERENCES staff(id) ON DELETE SET NULL,
  timestamp TIMESTAMPTZ NOT NULL DEFAULT now(),
  amount DECIMAL(10,2) NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('removal', 'addition')),
  reason TEXT NOT NULL,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Create indexes for till adjustment lookups
CREATE INDEX IF NOT EXISTS idx_till_adjustments_outlet_id ON till_adjustments(outlet_id);
CREATE INDEX IF NOT EXISTS idx_till_adjustments_timestamp ON till_adjustments(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_till_adjustments_outlet_timestamp ON till_adjustments(outlet_id, timestamp DESC);

-- Trading Days table
-- Tracks trading day sessions with opening/closing information
CREATE TABLE IF NOT EXISTS trading_days (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES outlets(id) ON DELETE CASCADE,
  trading_date DATE NOT NULL,
  opened_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  opened_by_staff_id UUID NOT NULL REFERENCES staff(id) ON DELETE SET NULL,
  opening_float_amount DECIMAL(10,2) NOT NULL DEFAULT 0 CHECK (opening_float_amount >= 0),
  opening_float_source TEXT NOT NULL CHECK (opening_float_source IN ('carry_forward', 'manual', 'zero')),
  
  -- Closing fields (nullable until end of day)
  closed_at TIMESTAMPTZ,
  closed_by_staff_id UUID REFERENCES staff(id) ON DELETE SET NULL,
  closing_cash_counted DECIMAL(10,2) CHECK (closing_cash_counted >= 0),
  cash_variance DECIMAL(10,2),
  carry_forward_cash DECIMAL(10,2) CHECK (carry_forward_cash >= 0),
  is_carry_forward BOOLEAN,
  
  -- System totals (calculated from orders/transactions)
  total_cash_sales DECIMAL(10,2) DEFAULT 0,
  total_card_sales DECIMAL(10,2) DEFAULT 0,
  total_sales DECIMAL(10,2) DEFAULT 0
);

-- Create indexes for trading day lookups
CREATE INDEX IF NOT EXISTS idx_trading_days_outlet_id ON trading_days(outlet_id);
CREATE INDEX IF NOT EXISTS idx_trading_days_trading_date ON trading_days(trading_date DESC);
CREATE INDEX IF NOT EXISTS idx_trading_days_outlet_date ON trading_days(outlet_id, trading_date DESC);
CREATE INDEX IF NOT EXISTS idx_trading_days_open_status ON trading_days(outlet_id, closed_at) WHERE closed_at IS NULL;
