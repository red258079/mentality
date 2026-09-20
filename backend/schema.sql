-- Enigma Database Schema (PostgreSQL 18)
-- ASCII only - no Vietnamese characters to avoid encoding issues

CREATE TYPE user_role AS ENUM ('student', 'admin');
CREATE TYPE intern_phase AS ENUM ('preparation', 'adaptation', 'sustain');
CREATE TYPE pillar_type AS ENUM ('sleep', 'physical', 'mental', 'social', 'career');
CREATE TYPE article_status AS ENUM ('draft', 'pending_review', 'published', 'rejected');
CREATE TYPE notification_type AS ENUM ('reminder_checkin', 'reminder_journal', 'new_article', 'task_unlock', 'streak_warning', 'system');

-- 1. USERS
CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email           VARCHAR(255) UNIQUE NOT NULL,
    password_hash   TEXT NOT NULL,
    role            user_role NOT NULL DEFAULT 'student',
    full_name       VARCHAR(255) NOT NULL,
    student_id      VARCHAR(20) UNIQUE,
    university      VARCHAR(255),
    major           VARCHAR(255),
    avatar_url      TEXT,
    fcm_token       TEXT,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_login_at   TIMESTAMPTZ
);
CREATE INDEX idx_users_email      ON users (email);
CREATE INDEX idx_users_role       ON users (role);
CREATE INDEX idx_users_student_id ON users (student_id);

-- 2. INTERN PROFILES
CREATE TABLE intern_profiles (
    id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id                UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    company_name           VARCHAR(255) DEFAULT 'LG Display',
    department             VARCHAR(255),
    intern_start_date      DATE,
    intern_end_date        DATE,
    current_phase          intern_phase DEFAULT 'preparation',
    initial_sleep_score    SMALLINT CHECK (initial_sleep_score BETWEEN 0 AND 100),
    initial_physical_score SMALLINT CHECK (initial_physical_score BETWEEN 0 AND 100),
    initial_mental_score   SMALLINT CHECK (initial_mental_score BETWEEN 0 AND 100),
    initial_social_score   SMALLINT CHECK (initial_social_score BETWEEN 0 AND 100),
    initial_career_score   SMALLINT CHECK (initial_career_score BETWEEN 0 AND 100),
    created_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at             TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. DAILY CHECKINS + GACHA
CREATE TABLE daily_checkins (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    checkin_date   DATE NOT NULL,
    gacha_message  TEXT NOT NULL,
    gacha_category VARCHAR(50),
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_checkin_user_date UNIQUE (user_id, checkin_date)
);
CREATE INDEX idx_checkins_user_date ON daily_checkins (user_id, checkin_date DESC);

-- 4. STREAKS
CREATE TABLE user_streaks (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id           UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    current_streak    INT NOT NULL DEFAULT 0,
    longest_streak    INT NOT NULL DEFAULT 0,
    last_checkin_date DATE,
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 5. JOURNALS
CREATE TABLE journals (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    journal_date      DATE NOT NULL,
    stress_level      SMALLINT NOT NULL CHECK (stress_level BETWEEN 1 AND 5),
    sleep_hours       NUMERIC(3,1) NOT NULL CHECK (sleep_hours BETWEEN 0 AND 24),
    physical_symptoms TEXT[] DEFAULT '{}',
    note              TEXT,
    ai_sentiment      VARCHAR(20),
    ai_keywords       TEXT[],
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_journal_user_date UNIQUE (user_id, journal_date)
);
CREATE INDEX idx_journals_user_date ON journals (user_id, journal_date DESC);

-- 6. TASKS MASTER LIST
CREATE TABLE tasks (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phase            intern_phase NOT NULL,
    pillar           pillar_type NOT NULL,
    title            VARCHAR(500) NOT NULL,
    description      TEXT NOT NULL,
    duration_minutes INT DEFAULT 0,
    unlock_day       INT NOT NULL DEFAULT 0,
    is_active        BOOLEAN DEFAULT TRUE,
    sort_order       INT DEFAULT 0,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_tasks_phase  ON tasks (phase);
CREATE INDEX idx_tasks_pillar ON tasks (pillar);

-- 7. USER TASK PROGRESS
CREATE TABLE user_task_progress (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    task_id      UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    is_completed BOOLEAN NOT NULL DEFAULT FALSE,
    is_locked    BOOLEAN NOT NULL DEFAULT TRUE,
    completed_at TIMESTAMPTZ,
    CONSTRAINT uq_user_task UNIQUE (user_id, task_id)
);
CREATE INDEX idx_task_progress_user ON user_task_progress (user_id);

-- 8. WELLBEING ASSESSMENTS
CREATE TABLE wellbeing_assessments (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    sleep_score     SMALLINT NOT NULL CHECK (sleep_score BETWEEN 0 AND 100),
    physical_score  SMALLINT NOT NULL CHECK (physical_score BETWEEN 0 AND 100),
    mental_score    SMALLINT NOT NULL CHECK (mental_score BETWEEN 0 AND 100),
    social_score    SMALLINT NOT NULL CHECK (social_score BETWEEN 0 AND 100),
    career_score    SMALLINT NOT NULL CHECK (career_score BETWEEN 0 AND 100),
    total_score     SMALLINT GENERATED ALWAYS AS (
        (sleep_score + physical_score + mental_score + social_score + career_score) / 5
    ) STORED,
    assessment_type VARCHAR(20) DEFAULT 'periodic',
    raw_answers     JSONB,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_assessments_user ON wellbeing_assessments (user_id, created_at DESC);

-- 9. HANDBOOK ARTICLES
CREATE TABLE handbook_articles (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title            VARCHAR(500) NOT NULL,
    summary          TEXT,
    content          TEXT NOT NULL,
    category         VARCHAR(100) NOT NULL,
    author_name      VARCHAR(255),
    author_id        UUID REFERENCES users(id) ON DELETE SET NULL,
    status           article_status NOT NULL DEFAULT 'pending_review',
    reviewed_by      UUID REFERENCES users(id) ON DELETE SET NULL,
    reviewed_at      TIMESTAMPTZ,
    rejection_reason TEXT,
    helpful_count    INT NOT NULL DEFAULT 0,
    view_count       INT NOT NULL DEFAULT 0,
    tags             TEXT[] DEFAULT '{}',
    chroma_id        TEXT UNIQUE,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_articles_status   ON handbook_articles (status);
CREATE INDEX idx_articles_category ON handbook_articles (category);
CREATE INDEX idx_articles_tags     ON handbook_articles USING GIN (tags);

-- 10. CHAT SESSIONS
CREATE TABLE chat_sessions (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title      VARCHAR(255),
    is_active  BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_sessions_user ON chat_sessions (user_id, updated_at DESC);

-- 11. CHAT MESSAGES
CREATE TABLE chat_messages (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id  UUID NOT NULL REFERENCES chat_sessions(id) ON DELETE CASCADE,
    is_user     BOOLEAN NOT NULL,
    content     TEXT NOT NULL,
    rag_sources JSONB,
    feedback    SMALLINT CHECK (feedback IN (-1, 1)),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_messages_session ON chat_messages (session_id, created_at ASC);

-- 12. ACHIEVEMENTS DEFINITION
CREATE TABLE achievements (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code             VARCHAR(50) UNIQUE NOT NULL,
    title            VARCHAR(255) NOT NULL,
    description      TEXT NOT NULL,
    icon_code        VARCHAR(50),
    unlock_condition JSONB NOT NULL,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 13. USER ACHIEVEMENTS
CREATE TABLE user_achievements (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    achievement_id UUID NOT NULL REFERENCES achievements(id) ON DELETE CASCADE,
    unlocked_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_user_achievement UNIQUE (user_id, achievement_id)
);
CREATE INDEX idx_user_achievements_user ON user_achievements (user_id);

-- 14. NOTIFICATION LOGS (Firebase FCM)
CREATE TABLE notification_logs (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id        UUID REFERENCES users(id) ON DELETE SET NULL,
    type           notification_type NOT NULL,
    title          VARCHAR(255) NOT NULL,
    body           TEXT NOT NULL,
    is_sent        BOOLEAN DEFAULT FALSE,
    sent_at        TIMESTAMPTZ,
    fcm_message_id TEXT,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_notif_user ON notification_logs (user_id, created_at DESC);

-- 15. REFRESH TOKENS
CREATE TABLE refresh_tokens (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash  TEXT NOT NULL UNIQUE,
    device_info TEXT,
    expires_at  TIMESTAMPTZ NOT NULL,
    is_revoked  BOOLEAN DEFAULT FALSE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_refresh_tokens_user ON refresh_tokens (user_id);

-- AUTO-UPDATE updated_at TRIGGER
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated_at
    BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_intern_profiles_updated_at
    BEFORE UPDATE ON intern_profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_articles_updated_at
    BEFORE UPDATE ON handbook_articles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_sessions_updated_at
    BEFORE UPDATE ON chat_sessions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- SEED DATA
INSERT INTO users (email, password_hash, role, full_name)
VALUES ('admin@enigma.edu.vn', 'REPLACE_WITH_BCRYPT_HASH', 'admin', 'Admin He Thong');

INSERT INTO achievements (code, title, description, icon_code, unlock_condition) VALUES
('first_checkin',  'First Day!',       'You checked in for the first time.',          'emoji_events',          '{"type": "checkin_count", "value": 1}'),
('streak_3',       'Streak 3 Days',    'Checked in 3 days in a row.',                 'local_fire_department', '{"type": "streak", "value": 3}'),
('streak_7',       'Streak 7 Days',    'Checked in 7 days in a row.',                 'whatshot',              '{"type": "streak", "value": 7}'),
('streak_30',      'Champion 30 Days', 'Checked in 30 consecutive days!',             'military_tech',         '{"type": "streak", "value": 30}'),
('first_journal',  'Inner Explorer',   'Wrote your first emotion journal.',           'book',                  '{"type": "journal_count", "value": 1}'),
('task_prep_done', 'Ready to Go!',     'Completed all Preparation phase tasks.',      'backpack',              '{"type": "phase_complete", "value": "preparation"}'),
('first_chat',     'AI Friend',        'Had your first conversation with Enigma AI.', 'smart_toy',             '{"type": "chat_count", "value": 1}');

INSERT INTO tasks (phase, pillar, title, description, duration_minutes, unlock_day, sort_order) VALUES
('preparation', 'mental',   'Read the LG Display handbook',              'Learn about company culture, 5S rules and what to bring.', 15, 0, 1),
('preparation', 'physical', 'Prepare a basic first aid kit',             'Prepare bandages, eye drops, digestive medicine for the new environment.', 10, 0, 2),
('preparation', 'sleep',    'Practice sleeping before 11:30 PM',        'Adjust your biological clock before starting work.', 0, 0, 3),
('preparation', 'social',   'Join the intern group chat',                'Join the Zalo/Facebook group of your intern batch.', 10, 0, 4),
('preparation', 'career',   'Define your internship goals',              'Write down 3 things you want to learn in the next 3 months.', 15, 0, 5),
('adaptation',  'mental',   'Box Breathing: Overcome first-day anxiety', 'Practice 4-4-4-4 breathing for 3 minutes to reduce stress.', 3, 1, 10),
('adaptation',  'sleep',    'No caffeine after 3 PM',                   'Avoid coffee/energy drinks after 3 PM to sleep better at night.', 0, 2, 11),
('adaptation',  'physical', 'Neck and shoulder stretch after shift',     'Do 3 neck rotation and shoulder stretching moves.', 5, 3, 12),
('adaptation',  'social',   'Have lunch with a new colleague',           'Expand communication and ask senior staff about their experience.', 30, 5, 13),
('adaptation',  'career',   'First week review: What did I learn?',      'Write down basic processes and machine operations you were taught.', 15, 7, 14),
('adaptation',  'mental',   'Emotion check-in: Identify pressure',      'Use your journal to write down current difficulties.', 10, 10, 15),
('adaptation',  'physical', 'Warm foot soak before bed',                'Helps relax blood vessels and relieve fatigue from standing all day.', 15, 12, 16),
('adaptation',  'sleep',    'Turn off screens 30 min before bed',        'Reduce blue light exposure to help the brain relax.', 30, 15, 17),
('adaptation',  'social',   'Share a difficulty with your team leader',  'Do not hesitate to ask if you are stuck on a work operation.', 15, 20, 18),
('adaptation',  'career',   'Month 1 review: What did I achieve?',       'Look back at the past month and reward yourself for adapting.', 15, 30, 19),
('sustain',     'physical', 'Light exercise 15 minutes daily',          'Maintain exercise habits to build endurance for the coming months.', 15, 31, 20),
('sustain',     'mental',   'Financial management: Cut unnecessary costs','Read a guide on budgeting and build an emergency fund.', 10, 40, 21),
('sustain',     'sleep',    'Keep a fixed sleep schedule (even weekends)','Prevents your body from getting confused between shifts.', 0, 45, 22),
('sustain',     'career',   'Study an advanced work process',            'Ask your manager about deeper principles of the equipment you operate.', 20, 50, 23),
('sustain',     'social',   'Organize a small outing with your group',   'Recharge energy and strengthen team bonds.', 120, 60, 24),
('sustain',     'mental',   'Burnout check',                             'Practice a stress assessment test to see if you are overloaded.', 5, 75, 25),
('sustain',     'career',   'Update your CV with internship experience', 'Document your achievements and skills gained over 3 months.', 30, 85, 26),
('sustain',     'social',   'Say thank you and stay connected',          'Thank those who guided you and get their contact info.', 15, 90, 27);
