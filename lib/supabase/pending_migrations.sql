-- ============================================
-- APP VERSIONS TABLE
-- Tracks version requirements for all platforms
-- ============================================

CREATE TABLE IF NOT EXISTS app_versions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  platform TEXT NOT NULL UNIQUE, -- 'windows' | 'android' | 'ios' | 'web'
  latest_version TEXT NOT NULL, -- Latest available version (e.g., '1.2.3+45')
  minimum_version TEXT NOT NULL, -- Minimum required version to run app
  release_notes TEXT, -- What's new in this version
  updated_at TIMESTAMPTZ DEFAULT now(),
  
  CONSTRAINT valid_platform CHECK (platform IN ('windows', 'android', 'ios', 'web'))
);

-- Index for fast lookups by platform
CREATE INDEX IF NOT EXISTS idx_app_versions_platform ON app_versions(platform);

-- Enable RLS
ALTER TABLE app_versions ENABLE ROW LEVEL SECURITY;

-- Allow anonymous read access to version info (anon users need to check version)
DROP POLICY IF EXISTS "Allow anonymous read access to app versions" ON app_versions;
CREATE POLICY "Allow anonymous read access to app versions"
  ON app_versions FOR SELECT
  TO anon
  USING (true);

-- Only authenticated users with service role can insert/update version info
-- (This would be managed by admins in BackOffice)
DROP POLICY IF EXISTS "Allow authenticated users to manage app versions" ON app_versions;
CREATE POLICY "Allow authenticated users to manage app versions"
  ON app_versions FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Sample seed data (optional - you can modify versions as needed)
INSERT INTO app_versions (platform, latest_version, minimum_version, release_notes)
VALUES 
  ('windows', '1.0.0+1', '1.0.0+1', 'Initial release'),
  ('android', '1.0.0+1', '1.0.0+1', 'Initial release'),
  ('ios', '1.0.0+1', '1.0.0+1', 'Initial release'),
  ('web', '1.0.0+1', '1.0.0+1', 'Initial release')
ON CONFLICT (platform) DO NOTHING;

-- ============================================
-- END OF APP VERSIONS MIGRATION
-- ============================================

-- ============================================
-- PRODUCTS: CARVERY FLAG FOR SEPARATE TICKETS
-- ============================================

ALTER TABLE products
  ADD COLUMN IF NOT EXISTS is_carvery BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN products.is_carvery IS 'When true, print each unit on its own Order Away ticket';
