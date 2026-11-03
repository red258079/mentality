-- Migration 003: Privacy and Retention
-- Idempotent, safe for existing tables and data.
-- Does NOT touch crisis_flags tables.

-- 1. Add allow_training_use column to users table (default FALSE)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' AND column_name = 'allow_training_use'
    ) THEN
        ALTER TABLE users ADD COLUMN allow_training_use BOOLEAN NOT NULL DEFAULT FALSE;
    END IF;
END $$;

-- 2. Create handbook_missing_topics table for aggregated no-info tracking
-- Stores ONLY (topic, date, count) - NO user_id, NO message text
CREATE TABLE IF NOT EXISTS handbook_missing_topics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    topic VARCHAR(50) NOT NULL,
    recorded_date DATE NOT NULL DEFAULT CURRENT_DATE,
    count INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_topic_date UNIQUE (topic, recorded_date)
);

CREATE INDEX IF NOT EXISTS idx_missing_topics_topic ON handbook_missing_topics(topic);
CREATE INDEX IF NOT EXISTS idx_missing_topics_date ON handbook_missing_topics(recorded_date DESC);

