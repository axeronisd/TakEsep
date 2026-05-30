-- ═══════════════════════════════════════════════════════════════════
-- Diagnostic Script: Check Supabase Realtime Status
-- Run this in Supabase Dashboard → SQL Editor to verify Realtime is working
-- ═══════════════════════════════════════════════════════════════════

-- 1. Check if Realtime publication exists
SELECT 
    pubname as publication_name,
    pubinsert as insert_enabled,
    pubupdate as update_enabled,
    pubdelete as delete_enabled
FROM pg_publication 
WHERE pubname = 'supabase_realtime';

-- 2. Check which tables are in the Realtime publication
SELECT 
    schemaname,
    tablename
FROM pg_publication_tables 
WHERE pubname = 'supabase_realtime'
ORDER BY schemaname, tablename;

-- 3. Check RLS policies for key tables
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename IN ('products', 'sales', 'arrivals', 'transfers', 'audits')
ORDER BY tablename, policyname;

-- 4. Test if Realtime is working by checking publication status
-- This should show the realtime publication and its tables
SELECT * FROM pg_publication_tables WHERE pubname = 'supabase_realtime';

-- 5. Check if triggers exist for updated_at
SELECT 
    trigger_name,
    event_object_table,
    action_statement
FROM information_schema.triggers
WHERE trigger_name LIKE '%updated_at%'
AND event_object_table IN ('products', 'sales', 'arrivals', 'transfers', 'audits');
