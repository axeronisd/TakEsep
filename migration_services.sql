-- SQL Migration for TakEsep Services and Sale Items
-- Run this script in the Supabase SQL Editor

-- 1. Add image_url to services table
ALTER TABLE services ADD COLUMN IF NOT EXISTS image_url TEXT;

-- 2. Add new columns to sale_items table
ALTER TABLE sale_items ADD COLUMN IF NOT EXISTS item_type TEXT DEFAULT 'product';
ALTER TABLE sale_items ADD COLUMN IF NOT EXISTS executor_id TEXT;
ALTER TABLE sale_items ADD COLUMN IF NOT EXISTS executor_name TEXT;

-- 3. Create a public storage bucket for images if it doesn't exist
-- Note: You might need to create the bucket 'images' manually in the "Storage" section 
-- of your Supabase dashboard and set it to "Public". The SQL below attempts to create it.
INSERT INTO storage.buckets (id, name, public) 
VALUES ('images', 'images', true)
ON CONFLICT (id) DO NOTHING;

-- 4. Allow public read access to the 'images' bucket
CREATE POLICY "Public Access" 
ON storage.objects FOR SELECT 
USING ( bucket_id = 'images' );

-- 5. Allow authenticated users to upload images
CREATE POLICY "Auth Upload" 
ON storage.objects FOR INSERT 
WITH CHECK ( bucket_id = 'images' AND auth.role() = 'authenticated' );

-- 6. Allow authenticated users to update/delete their images
CREATE POLICY "Auth Update" 
ON storage.objects FOR UPDATE 
USING ( bucket_id = 'images' AND auth.role() = 'authenticated' );

CREATE POLICY "Auth Delete" 
ON storage.objects FOR DELETE 
USING ( bucket_id = 'images' AND auth.role() = 'authenticated' );
