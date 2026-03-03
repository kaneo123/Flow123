-- Migration: Change table_number to text to support custom names
-- Description: Changes table_number from integer to text to allow both numbers and custom names (e.g., "1", "John's Tab", "VIP Room")
-- Date: 2025-01-XX

-- Change table_number column type from integer to text
ALTER TABLE outlet_tables 
ALTER COLUMN table_number TYPE TEXT USING table_number::TEXT;

-- Remove the separate table_name column if it exists (reverting previous approach)
ALTER TABLE outlet_tables 
DROP COLUMN IF EXISTS table_name;

-- Add comment to explain the column
COMMENT ON COLUMN outlet_tables.table_number IS 'Table number or custom name (e.g., "1", "John''s Tab", "VIP Room")';
