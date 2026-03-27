-- Migration: Add pin_code column to roles table
-- This column stores the shared PIN code for all employees with this role.
-- Employees use their unique key + role PIN to log in.

ALTER TABLE roles ADD COLUMN IF NOT EXISTS pin_code TEXT DEFAULT '';
