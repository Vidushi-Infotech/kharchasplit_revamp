-- Migration 014: ensure users.password_hash exists.
-- The initial schema file (001) declared this column, but a number of dev
-- databases were provisioned from an earlier copy of 001 that didn't have it.
-- Idempotent.

ALTER TABLE users
    ADD COLUMN IF NOT EXISTS password_hash VARCHAR(255);
