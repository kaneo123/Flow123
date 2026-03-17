-- Migration: Add RPC function to fetch table schema information
-- Purpose: Support schema sync service to mirror Supabase table structure to local SQLite

-- Create function to get table columns with their data types
-- This function queries PostgreSQL information_schema to return column metadata
CREATE OR REPLACE FUNCTION get_table_columns(table_name_param text)
RETURNS TABLE (
  column_name text,
  data_type text
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Query information_schema to get column definitions
  -- Filter for public schema only
  RETURN QUERY
  SELECT 
    c.column_name::text,
    c.data_type::text
  FROM information_schema.columns c
  WHERE c.table_schema = 'public'
    AND c.table_name = table_name_param
  ORDER BY c.ordinal_position;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_table_columns(text) TO authenticated;
GRANT EXECUTE ON FUNCTION get_table_columns(text) TO anon;

-- Comment for documentation
COMMENT ON FUNCTION get_table_columns(text) IS 'Returns column names and data types for a given table in the public schema. Used by schema sync service to mirror database structure to local SQLite.';
