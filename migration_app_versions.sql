-- ═══════════════════════════════════════════════════════════════
-- TakEsep: App Versions table for in-app update notifications
-- Run this in Supabase SQL Editor
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS app_versions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  platform TEXT NOT NULL,             -- 'windows', 'android', 'ios', 'macos'
  version TEXT NOT NULL,              -- '1.0.2'
  build_number INT NOT NULL,          -- 2
  download_url TEXT,                  -- direct download link (Google Drive, etc.)
  release_notes TEXT,                 -- 'Исправления ошибок, новые карточки'
  force_update BOOLEAN DEFAULT false, -- if true, user can't skip
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Allow authenticated users to read (for update check)
ALTER TABLE app_versions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow read for authenticated users"
  ON app_versions
  FOR SELECT
  TO authenticated
  USING (true);

-- ═══════════════════════════════════════════════════════════════
-- Insert your first version record (update download_url later!)
-- ═══════════════════════════════════════════════════════════════

INSERT INTO app_versions (platform, version, build_number, download_url, release_notes)
VALUES
  ('windows', '1.0.1', 1, '', 'Первый релиз'),
  ('android', '1.0.1', 1, '', 'Первый релиз');

-- ═══════════════════════════════════════════════════════════════
-- HOW TO PUBLISH AN UPDATE:
-- 1. Update version in pubspec.yaml (e.g., 1.0.2+2)
-- 2. Update kAppVersion and kAppBuildNumber in update_service.dart
-- 3. Build: flutter build windows --release && flutter build apk --release
-- 4. Upload to Google Drive, get sharing link
-- 5. Insert new row:
--
-- INSERT INTO app_versions (platform, version, build_number, download_url, release_notes)
-- VALUES ('windows', '1.0.2', 2, 'https://drive.google.com/...', 'Новые карточки, исправления');
--
-- INSERT INTO app_versions (platform, version, build_number, download_url, release_notes)
-- VALUES ('android', '1.0.2', 2, 'https://drive.google.com/...', 'Новые карточки, исправления');
-- ═══════════════════════════════════════════════════════════════
