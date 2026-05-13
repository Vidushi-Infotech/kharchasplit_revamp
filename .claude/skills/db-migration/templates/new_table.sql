-- Migration: <description>
-- Version: NNN
-- Description: <what this enables, why now>

-- =====================================================
-- <TABLE_NAME> TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS <table_name> (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    created_by UUID NOT NULL REFERENCES users(id),

    -- Domain fields
    -- name VARCHAR(255) NOT NULL,
    -- amount DECIMAL(15, 2) NOT NULL CHECK (amount >= 0),
    -- currency VARCHAR(3) DEFAULT 'INR',
    -- status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'archived')),

    -- Audit
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    deleted_at TIMESTAMP WITH TIME ZONE
);

-- =====================================================
-- INDEXES
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_<table_name>_group ON <table_name>(group_id);
CREATE INDEX IF NOT EXISTS idx_<table_name>_created_by ON <table_name>(created_by);
CREATE INDEX IF NOT EXISTS idx_<table_name>_deleted ON <table_name>(deleted_at);

-- =====================================================
-- updated_at TRIGGER
-- =====================================================
DROP TRIGGER IF EXISTS update_<table_name>_updated_at ON <table_name>;
CREATE TRIGGER update_<table_name>_updated_at
    BEFORE UPDATE ON <table_name>
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- COMMENTS (optional but recommended for non-obvious tables)
-- =====================================================
COMMENT ON TABLE <table_name> IS '<one-line description of purpose>';
-- COMMENT ON COLUMN <table_name>.status IS 'active = visible to user; archived = hidden but kept for audits';
