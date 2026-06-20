-- Allow select access to app_versions table for anonymous users so the landing page can read current versions.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_policies
        WHERE tablename = 'app_versions' AND policyname = 'Allow read for anonymous users'
    ) THEN
        CREATE POLICY "Allow read for anonymous users"
          ON app_versions
          FOR SELECT
          TO anon, authenticated
          USING (true);
    END IF;
END $$;
