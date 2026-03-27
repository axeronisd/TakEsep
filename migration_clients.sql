-- SQL Migration to support Clients Analytics and Debt Tracking
-- 1. Add columns to 'sales' table for client assignment and partial payments
ALTER TABLE sales ADD COLUMN IF NOT EXISTS client_id TEXT;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS client_name TEXT;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS received_amount DECIMAL;

-- 2. Add properties to 'clients' table to track debt and lifetime metrics
ALTER TABLE clients ADD COLUMN IF NOT EXISTS total_spent DECIMAL DEFAULT 0;
ALTER TABLE clients ADD COLUMN IF NOT EXISTS debt DECIMAL DEFAULT 0;
ALTER TABLE clients ADD COLUMN IF NOT EXISTS purchases_count INT DEFAULT 0;

-- Execute this script in your Supabase SQL Editor.
