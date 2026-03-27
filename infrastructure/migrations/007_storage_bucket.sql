-- Create the product_images storage bucket
-- Run this in Supabase SQL Editor

-- Create bucket if it doesn't exist
INSERT INTO storage.buckets (id, name, public)
VALUES ('product_images', 'product_images', true)
ON CONFLICT (id) DO NOTHING;

-- Allow anon to upload to the bucket
CREATE POLICY IF NOT EXISTS "anon_upload_product_images"
ON storage.objects FOR INSERT TO anon
WITH CHECK (bucket_id = 'product_images');

-- Allow anyone to read from the bucket (public images)
CREATE POLICY IF NOT EXISTS "public_read_product_images"
ON storage.objects FOR SELECT TO anon
USING (bucket_id = 'product_images');

-- Allow anon to delete from the bucket
CREATE POLICY IF NOT EXISTS "anon_delete_product_images"
ON storage.objects FOR DELETE TO anon
USING (bucket_id = 'product_images');
