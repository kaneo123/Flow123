-- ================================================================
-- Supabase SQL Migration: Refund System with Inventory Restoration
-- ================================================================
-- This migration adds support for refund transactions and inventory restoration
-- 
-- Changes:
-- 1. Add 'refund' to payment_method constraint in transactions table
-- 2. Document refund reason tracking in transaction metadata
--
-- Execute this SQL in your Supabase SQL Editor
-- ================================================================

-- 1. Drop the existing payment_method check constraint
ALTER TABLE public.transactions
  DROP CONSTRAINT IF EXISTS transactions_payment_method_check;

-- 2. Recreate the constraint with 'refund' added
ALTER TABLE public.transactions
  ADD CONSTRAINT transactions_payment_method_check 
  CHECK (payment_method IN ('cash', 'card', 'digital_wallet', 'discount', 'voucher', 'loyalty', 'refund'));

-- ================================================================
-- DOCUMENTATION: How Refunds Work
-- ================================================================
-- 
-- REFUND TRANSACTION STRUCTURE:
-- - payment_method: 'refund'
-- - amount_paid: negative value (e.g., -12.50 for £12.50 refund)
-- - payment_status: 'completed'
-- 
-- METADATA STRUCTURE (stored in 'meta' JSONB column):
-- {
--   "reason": "Order Never Made",  // One of: Order Never Made, Price Error, Quality Issue, Customer Complaint, Wrong Item, Other
--   "restore_inventory": true      // Boolean - whether to restore inventory
-- }
-- 
-- REFUND REASON TYPES:
-- - "Order Never Made" → Automatically restores inventory (items never prepared)
-- - "Price Error" → Does NOT restore inventory (customer received items)
-- - "Quality Issue" → Does NOT restore inventory (items were made but defective)
-- - "Customer Complaint" → Does NOT restore inventory (items were given to customer)
-- - "Wrong Item" → Does NOT restore inventory (wrong items were prepared)
-- - "Other" → Manual selection for inventory restoration
-- 
-- INVENTORY RESTORATION:
-- When restore_inventory = true:
-- - For products with linked_product_id: Increments inventory_items.current_qty
-- - For products with inventory_item_id: Increments inventory_items.current_qty directly
-- - Logs inventory restoration in debug console
-- 
-- STAFF PERMISSIONS:
-- - Only staff with roles.level >= 2 can process refunds
-- - Level 1 (Staff) cannot see refund button
-- - Level 2+ (Senior Staff, Supervisor, Manager, Owner) can refund
-- 
-- ================================================================

-- Verify the constraint was updated successfully
SELECT conname, pg_get_constraintdef(oid) 
FROM pg_constraint 
WHERE conname = 'transactions_payment_method_check';

-- ================================================================
-- END OF MIGRATION
-- ================================================================
