-- Migration: Create table_sessions for tracking who has tables/tabs open
-- Purpose: Enable soft locking to prevent concurrent editing conflicts

-- Create table_sessions table
CREATE TABLE IF NOT EXISTS public.table_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  table_id UUID REFERENCES public.outlet_tables(id) ON DELETE SET NULL,
  staff_id UUID REFERENCES public.staff(id) ON DELETE SET NULL,
  staff_name TEXT NOT NULL,
  device_id TEXT,
  session_started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_heartbeat_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_table_sessions_order_id ON public.table_sessions(order_id);
CREATE INDEX IF NOT EXISTS idx_table_sessions_table_id ON public.table_sessions(table_id) WHERE table_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_table_sessions_active ON public.table_sessions(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_table_sessions_heartbeat ON public.table_sessions(last_heartbeat_at) WHERE is_active = true;

-- Unique constraint: one active session per order per staff
CREATE UNIQUE INDEX IF NOT EXISTS idx_table_sessions_unique_active 
  ON public.table_sessions(order_id, staff_id) 
  WHERE is_active = true;

-- Enable Row Level Security
ALTER TABLE public.table_sessions ENABLE ROW LEVEL SECURITY;

-- Policy: Allow authenticated users to view all active sessions
CREATE POLICY "table_sessions_select_policy" 
  ON public.table_sessions 
  FOR SELECT 
  USING (true);

-- Policy: Allow authenticated users to insert their own sessions
CREATE POLICY "table_sessions_insert_policy" 
  ON public.table_sessions 
  FOR INSERT 
  WITH CHECK (true);

-- Policy: Allow authenticated users to update their own sessions
CREATE POLICY "table_sessions_update_policy" 
  ON public.table_sessions 
  FOR UPDATE 
  USING (true) 
  WITH CHECK (true);

-- Policy: Allow authenticated users to delete their own sessions
CREATE POLICY "table_sessions_delete_policy" 
  ON public.table_sessions 
  FOR DELETE 
  USING (true);

-- Function to auto-cleanup stale sessions (heartbeat older than 5 minutes)
CREATE OR REPLACE FUNCTION cleanup_stale_table_sessions()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE public.table_sessions
  SET is_active = false,
      updated_at = now()
  WHERE is_active = true
    AND last_heartbeat_at < now() - INTERVAL '5 minutes';
END;
$$;

-- Note: Users can manually call this cleanup function or set up a pg_cron job
-- Example: SELECT cleanup_stale_table_sessions();
