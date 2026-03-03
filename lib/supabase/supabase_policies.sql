-- FlowTill EPOS Security Policies

-- Enable Row Level Security on all tables
ALTER TABLE outlets ENABLE ROW LEVEL SECURITY;
ALTER TABLE tax_rates ENABLE ROW LEVEL SECURITY;
ALTER TABLE roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;

-- Outlets policies
CREATE POLICY "Allow authenticated users to view outlets"
  ON outlets FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Allow authenticated users to insert outlets"
  ON outlets FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Allow authenticated users to update outlets"
  ON outlets FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Allow authenticated users to delete outlets"
  ON outlets FOR DELETE
  TO authenticated
  USING (true);

-- Tax rates policies
CREATE POLICY "Allow authenticated users to view tax rates"
  ON tax_rates FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Allow authenticated users to insert tax rates"
  ON tax_rates FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Allow authenticated users to update tax rates"
  ON tax_rates FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Allow authenticated users to delete tax rates"
  ON tax_rates FOR DELETE
  TO authenticated
  USING (true);

-- Roles policies
CREATE POLICY "Allow authenticated users to view roles"
  ON roles FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Allow authenticated users to insert roles"
  ON roles FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Allow authenticated users to update roles"
  ON roles FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Allow authenticated users to delete roles"
  ON roles FOR DELETE
  TO authenticated
  USING (true);

-- Staff policies
CREATE POLICY "Allow authenticated users to view staff"
  ON staff FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Allow authenticated users to insert staff"
  ON staff FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Allow authenticated users to update staff"
  ON staff FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Allow authenticated users to delete staff"
  ON staff FOR DELETE
  TO authenticated
  USING (true);

-- Categories policies
CREATE POLICY "Allow authenticated users to view categories"
  ON categories FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Allow authenticated users to insert categories"
  ON categories FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Allow authenticated users to update categories"
  ON categories FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Allow authenticated users to delete categories"
  ON categories FOR DELETE
  TO authenticated
  USING (true);

-- Products policies
CREATE POLICY "Allow authenticated users to view products"
  ON products FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Allow authenticated users to insert products"
  ON products FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Allow authenticated users to update products"
  ON products FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Allow authenticated users to delete products"
  ON products FOR DELETE
  TO authenticated
  USING (true);

-- Orders policies
CREATE POLICY "Allow authenticated users to view orders"
  ON orders FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Allow authenticated users to insert orders"
  ON orders FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Allow authenticated users to update orders"
  ON orders FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Allow authenticated users to delete orders"
  ON orders FOR DELETE
  TO authenticated
  USING (true);

-- Order items policies
CREATE POLICY "Allow authenticated users to view order items"
  ON order_items FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Allow authenticated users to insert order items"
  ON order_items FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Allow authenticated users to update order items"
  ON order_items FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Allow authenticated users to delete order items"
  ON order_items FOR DELETE
  TO authenticated
  USING (true);

-- Enable Row Level Security for till_adjustments
ALTER TABLE till_adjustments ENABLE ROW LEVEL SECURITY;

-- Till adjustments policies
CREATE POLICY "Allow authenticated users to view till adjustments"
  ON till_adjustments FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Allow authenticated users to insert till adjustments"
  ON till_adjustments FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Allow authenticated users to update till adjustments"
  ON till_adjustments FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Allow authenticated users to delete till adjustments"
  ON till_adjustments FOR DELETE
  TO authenticated
  USING (true);

-- Enable Row Level Security for trading_days
ALTER TABLE trading_days ENABLE ROW LEVEL SECURITY;

-- Trading days policies
CREATE POLICY "Allow authenticated users to view trading days"
  ON trading_days FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Allow authenticated users to insert trading days"
  ON trading_days FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Allow authenticated users to update trading days"
  ON trading_days FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Allow authenticated users to delete trading days"
  ON trading_days FOR DELETE
  TO authenticated
  USING (true);
