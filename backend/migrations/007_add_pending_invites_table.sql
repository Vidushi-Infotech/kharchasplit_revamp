-- Migration: Add pending_group_invites table for WATI WhatsApp invites
-- Version: 007
-- Description: Stores pending invitations for non-registered users

-- =====================================================
-- PENDING GROUP INVITES TABLE
-- =====================================================
-- Stores invitations for users who haven't registered yet
-- When they register, they are automatically added to the group

CREATE TABLE IF NOT EXISTS pending_group_invites (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    phone_number VARCHAR(20) NOT NULL,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255),
    invited_by UUID NOT NULL REFERENCES users(id),

    -- WATI tracking
    wati_message_id VARCHAR(255),
    wati_status VARCHAR(50) DEFAULT 'pending', -- pending, sent, delivered, read, failed
    wati_sent_at TIMESTAMP WITH TIME ZONE,
    wati_error TEXT,

    -- Invite tracking
    invite_count INTEGER DEFAULT 1,
    last_invited_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- Prevent duplicate invites for same phone in same group
    UNIQUE(group_id, phone_number)
);

CREATE INDEX idx_pending_invites_group ON pending_group_invites(group_id);
CREATE INDEX idx_pending_invites_phone ON pending_group_invites(phone_number);
CREATE INDEX idx_pending_invites_invited_by ON pending_group_invites(invited_by);
CREATE INDEX idx_pending_invites_status ON pending_group_invites(wati_status);

-- Add trigger for updated_at
CREATE TRIGGER update_pending_group_invites_updated_at
    BEFORE UPDATE ON pending_group_invites
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE pending_group_invites IS 'Pending group invitations for non-registered users via WATI WhatsApp';
