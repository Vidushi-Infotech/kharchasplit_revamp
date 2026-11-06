-- Migration: Add placeholder user support
-- Version: 008
-- Description: Allows creating placeholder users for non-registered invites
-- These users can be added to groups and expenses before they register

-- Add is_placeholder column to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_placeholder BOOLEAN DEFAULT FALSE;

-- Add index for faster lookup of placeholder users
CREATE INDEX IF NOT EXISTS idx_users_is_placeholder ON users(is_placeholder) WHERE is_placeholder = TRUE;

-- Add index for phone number lookup (for merging placeholder when user registers)
CREATE INDEX IF NOT EXISTS idx_users_phone_placeholder ON users(phone_number, is_placeholder);

COMMENT ON COLUMN users.is_placeholder IS 'True if this is a placeholder user created from invite, pending registration';
