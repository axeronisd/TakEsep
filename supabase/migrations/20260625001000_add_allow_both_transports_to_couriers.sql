-- Migration 045 / 20260625001000: Add allow_both_transports column to couriers table

ALTER TABLE couriers ADD COLUMN IF NOT EXISTS allow_both_transports BOOLEAN NOT NULL DEFAULT false;
