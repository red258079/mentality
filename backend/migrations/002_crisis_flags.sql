-- Migration 002: Crisis Flags Table
-- Idempotent, safe for existing tables and data.
-- Does NOT store any message text from the user. Only metadata: user_id, tier, source, status, timestamps, and admin note.

CREATE TABLE IF NOT EXISTS crisis_flags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    tier VARCHAR(20) NOT NULL, -- 'explicit' or 'ambiguous'
    source VARCHAR(50) NOT NULL DEFAULT 'chat',
    status VARCHAR(20) NOT NULL DEFAULT 'new', -- 'new', 'contacted', 'resolved'
    admin_note TEXT,
    handled_by UUID REFERENCES users(id) ON DELETE SET NULL,
    handled_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_crisis_flags_user_id ON crisis_flags(user_id);
CREATE INDEX IF NOT EXISTS idx_crisis_flags_status ON crisis_flags(status);
CREATE INDEX IF NOT EXISTS idx_crisis_flags_created_at ON crisis_flags(created_at DESC);
