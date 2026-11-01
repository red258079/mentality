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
    password_hash   TEXT,
    auth_provider   VARCHAR(50) DEFAULT 'local',
    google_id       VARCHAR(255) UNIQUE,
    role            user_role NOT NULL DEFAULT 'student',
    full_name       VARCHAR(255) NOT NULL,
    student_id      VARCHAR(20) UNIQUE,
    university_id   UUID,
    university      VARCHAR(255),
    major           VARCHAR(255),
    avatar_url      TEXT,
    fcm_token       TEXT,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_login_at   TIMESTAMPTZ,
    otp_code        VARCHAR(6),
    otp_expires_at  TIMESTAMPTZ
);
CREATE INDEX idx_users_email         ON users (email);
CREATE INDEX idx_users_role          ON users (role);
CREATE INDEX idx_users_student_id    ON users (student_id);

-- 2. CATALOG TABLES (UNIVERSITIES & COMPANIES)
CREATE TABLE IF NOT EXISTS universities (
    id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code                 VARCHAR(50) UNIQUE NOT NULL,
    name                 VARCHAR(255) NOT NULL,
    short_name           VARCHAR(100),
    city                 VARCHAR(100),
    is_approved          BOOLEAN NOT NULL DEFAULT TRUE,
    submitted_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_universities_code ON universities (code);
CREATE INDEX IF NOT EXISTS idx_universities_approved ON universities (is_approved);

ALTER TABLE users ADD CONSTRAINT fk_users_university_id
    FOREIGN KEY (university_id) REFERENCES universities(id) ON DELETE SET NULL;
CREATE INDEX idx_users_university_id ON users (university_id);

CREATE TABLE IF NOT EXISTS companies (
    id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code                 VARCHAR(50) UNIQUE NOT NULL,
    name                 VARCHAR(255) NOT NULL,
    short_name           VARCHAR(100),
    latitude             DOUBLE PRECISION,
    longitude            DOUBLE PRECISION,
    radius_meters        INTEGER NOT NULL DEFAULT 500,
    workplace_type       VARCHAR(50) NOT NULL DEFAULT 'factory_locker',
    is_approved          BOOLEAN NOT NULL DEFAULT TRUE,
    submitted_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_companies_code ON companies (code);
CREATE INDEX IF NOT EXISTS idx_companies_approved ON companies (is_approved);

-- 3. INTERN PROFILES
CREATE TABLE intern_profiles (
    id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id                UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    company_id             UUID REFERENCES companies(id) ON DELETE SET NULL,
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
CREATE INDEX idx_intern_profiles_company_id ON intern_profiles (company_id);

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
    shift_type        TEXT,
    physical_symptoms TEXT[] DEFAULT '{}',
    note              TEXT,
    ai_sentiment      VARCHAR(20),
    ai_keywords       TEXT[],
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_journal_user_date UNIQUE (user_id, journal_date)
);
ALTER TABLE journals ADD COLUMN IF NOT EXISTS shift_type text;
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

-- 16. USER FEATURE ONBOARDINGS (Contextual Coach Marks status)
CREATE TABLE IF NOT EXISTS user_feature_onboardings (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    feature_key  VARCHAR(50) NOT NULL,
    completed    BOOLEAN NOT NULL DEFAULT TRUE,
    completed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_user_feature_onboarding UNIQUE (user_id, feature_key)
);
CREATE INDEX IF NOT EXISTS idx_user_feature_onboarding_user ON user_feature_onboardings (user_id);

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
('first_checkin',  'Ngày đầu tiên!',    'Bạn đã thực hiện lượt điểm danh đầu tiên.',  'emoji_events',          '{"type": "checkin_count", "value": 1}'),
('streak_3',       'Chuỗi 3 ngày',      'Điểm danh liên tục 3 ngày.',                 'local_fire_department', '{"type": "streak", "value": 3}'),
('streak_7',       'Chuỗi 7 ngày',      'Điểm danh liên tục 7 ngày.',                 'whatshot',              '{"type": "streak", "value": 7}'),
('streak_30',      'Chiến binh 30 ngày','Điểm danh liên tục 30 ngày!',                'military_tech',         '{"type": "streak", "value": 30}'),
('first_journal',  'Thấu cảm nội tâm',  'Viết trang nhật ký cảm xúc đầu tiên.',       'book',                  '{"type": "journal_count", "value": 1}'),
('task_prep_done', 'Sẵn sàng lên đường!','Hoàn thành tất cả nhiệm vụ chặng Chuẩn bị.','backpack',             '{"type": "phase_complete", "value": "preparation"}'),
('first_chat',     'Bạn đồng hành AI',  'Trò chuyện lần đầu cùng trợ lý Enigma AI.',  'smart_toy',             '{"type": "chat_count", "value": 1}');

INSERT INTO tasks (phase, pillar, title, description, duration_minutes, unlock_day, sort_order) VALUES
('preparation', 'mental',   'Đọc cẩm nang "Hành trang LG Display"',              'Tìm hiểu trước về văn hóa công ty, quy định 5S và các vật dụng cần thiết mang theo khi đi làm.', 15, 0, 1),
('preparation', 'physical', 'Chuẩn bị đồ dùng cá nhân y tế cơ bản',             'Chuẩn bị urgo, thuốc nhỏ mắt, thuốc tiêu hóa và các loại thuốc cơ bản để sẵn sàng cho môi trường mới.', 10, 0, 2),
('preparation', 'sleep',    'Tập ngủ sớm trước 23:30',                          'Điều chỉnh nhịp sinh học trước khi chính thức đi làm để không bị mệt mỏi trong những ngày đầu.', 0, 0, 3),
('preparation', 'social',   'Kết nối nhóm sinh viên cùng đợt',                  'Tham gia group Zalo/Facebook của đợt thực tập để trao đổi thông tin và tìm bạn đồng hành.', 10, 0, 4),
('preparation', 'career',   'Xác định mục tiêu thực tập',                       'Viết ra 3 điều bạn muốn học được sau 3 tháng tới (kỹ năng cứng, mềm, mối quan hệ).', 15, 0, 5),
('adaptation',  'mental',   'Tập hít thở 4-4-4-4: Vượt qua bỡ ngỡ ngày đầu',    'Tập hít thở chậm rãi trong 3 phút để giảm căng thẳng khi tiếp xúc với môi trường sản xuất quy mô lớn.', 3, 1, 10),
('adaptation',  'sleep',    'Làm quen nhịp ca kíp: Không uống cà phê chiều',    'Tránh uống cà phê hoặc nước tăng lực sau 15h để đảm bảo có thể ngủ sâu vào ban đêm.', 0, 2, 11),
('adaptation',  'physical', 'Giãn cơ vai gáy sau ca làm',                       'Thực hiện 3 động tác xoay cổ và căng vai gáy để tránh nhức mỏi.', 5, 3, 12),
('adaptation',  'social',   'Ăn trưa cùng một đồng nghiệp mới',                 'Mở rộng giao tiếp, hỏi han về kinh nghiệm làm việc của các anh chị đi trước.', 30, 5, 13),
('adaptation',  'career',   'Đánh giá tuần đầu: Những bài học đã tích lũy',      'Ghi lại các quy trình cơ bản và thao tác máy móc bạn đã được hướng dẫn.', 15, 7, 14),
('adaptation',  'mental',   'Điểm danh cảm xúc: Nhận diện áp lực ca kíp',        'Sử dụng nhật ký để viết ra những khó khăn đang gặp phải (đứng lâu, không quen việc...).', 10, 10, 15),
('adaptation',  'physical', 'Ngâm chân nước ấm',                                'Giúp dãn mạch máu vùng bàn chân, xua tan cảm giác mỏi nhức do đứng làm việc lâu.', 15, 12, 16),
('adaptation',  'sleep',    'Tắt màn hình 30p trước khi ngủ',                   'Giảm tiếp xúc ánh sáng xanh để não bộ thư giãn.', 30, 15, 17),
('adaptation',  'social',   'Chia sẻ một khó khăn với quản lý/nhóm trưởng',     'Đừng ngại hỏi hoặc chia sẻ nếu bạn đang gặp bế tắc trong thao tác công việc.', 15, 20, 18),
('adaptation',  'career',   'Đánh giá tháng 1: Bạn đã làm được gì?',            'Nhìn lại 1 tháng vừa qua, tự thưởng cho bản thân vì đã nỗ lực thích nghi.', 15, 30, 19),
('sustain',     'physical', 'Tập thể dục nhẹ 15 phút mỗi ngày',                 'Duy trì thói quen vận động để tăng sức bền cho những tháng tiếp theo.', 15, 31, 20),
('sustain',     'mental',   'Quản lý tài chính: Cắt giảm chi phí thừa',         'Đọc cẩm nang về quản lý chi tiêu và lập quỹ phòng hờ.', 10, 40, 21),
('sustain',     'sleep',    'Xây dựng thói quen ngủ cố định (kể cả ngày nghỉ)', 'Giúp cơ thể không bị rối loạn nhịp sinh học giữa các ca làm việc.', 0, 45, 22),
('sustain',     'career',   'Tìm hiểu một quy trình làm việc nâng cao',         'Hỏi quản lý hoặc tài liệu công ty về nguyên lý hoạt động sâu hơn của máy móc bạn đang phụ trách.', 20, 50, 23),
('sustain',     'social',   'Tổ chức một buổi đi chơi nhỏ cùng phòng trọ/nhóm', 'Tái tạo năng lượng và thắt chặt tình cảm anh em.', 120, 60, 24),
('sustain',     'mental',   'Kiểm soát và phòng ngừa kiệt sức',                 'Thực hành bài kiểm tra mức độ căng thẳng để xem bạn có đang quá sức không.', 5, 75, 25),
('sustain',     'career',   'Cập nhật hồ sơ xin việc (CV) với kinh nghiệm thực tập','Ghi lại những thành tích, số liệu và kỹ năng bạn đã tích lũy được trong 3 tháng qua.', 30, 85, 26),
('sustain',     'social',   'Nói lời cảm ơn và giữ liên lạc',                   'Cảm ơn những người đã hướng dẫn bạn và xin thông tin liên lạc để duy trì kết nối đồng nghiệp.', 15, 90, 27);

-- 4. RLS POLICIES FOR CATALOG TABLES
ALTER TABLE universities ENABLE ROW LEVEL SECURITY;
ALTER TABLE companies ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'universities' AND policyname = 'universities_read_approved_policy'
    ) THEN
        CREATE POLICY universities_read_approved_policy ON universities
            FOR SELECT USING (is_approved = true);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'companies' AND policyname = 'companies_read_approved_policy'
    ) THEN
        CREATE POLICY companies_read_approved_policy ON companies
            FOR SELECT USING (is_approved = true);
    END IF;
END $$;

-- 5. SEED CATALOG (COMPANIES & UNIVERSITIES)
INSERT INTO companies (code, name, short_name, latitude, longitude, radius_meters, workplace_type, is_approved)
VALUES
('lg_display_hp',   'LG Display Hải Phòng',                  'LG Display',   20.8865, 106.5821, 600,  'factory_locker', true),
('samsung_sevt_tn', 'Samsung Electronics Thái Nguyên (SEVT)', 'Samsung SEVT', 21.4650, 105.8690, 800,  'factory_locker', true),
('samsung_sdv_bn',  'Samsung Display Bắc Ninh (SDV)',        'Samsung SDV',  21.2035, 105.9754, 800,  'factory_locker', true),
('fpt_software_hl', 'FPT Software Hòa Lạc (F-Ville)',         'FPT Software', 21.0131, 105.5273, 500,  'office',         true),
('vinfast_hp',      'Tổ hợp Nhà máy VinFast Hải Phòng',      'VinFast',      20.8350, 106.9320, 1000, 'factory_locker', true)
ON CONFLICT (code) DO NOTHING;

INSERT INTO universities (code, name, short_name, city, is_approved)
VALUES
('BDU',       'Trường Đại học Bình Dương',                 'ĐH Bình Dương',           'Bình Dương',      true),
('HUST',      'Đại học Bách Khoa Hà Nội',                  'ĐH Bách Khoa Hà Nội',     'Hà Nội',          true),
('HAUI',      'Trường Đại học Công nghiệp Hà Nội',         'ĐH Công nghiệp Hà Nội',   'Hà Nội',          true),
('PTIT',      'Học viện Công nghệ Bưu chính Viễn thông',   'Học viện CNBCVT',         'Hà Nội',          true),
('UTC',       'Trường Đại học Giao thông Vận tải',         'ĐH Giao thông Vận tải',   'Hà Nội',          true),
('NEU',       'Trường Đại học Kinh tế Quốc dân',           'ĐH Kinh tế Quốc dân',     'Hà Nội',          true),
('PHENIKAA',  'Trường Đại học Phenikaa',                   'ĐH Phenikaa',             'Hà Nội',          true),
('VNU_UET',   'Trường Đại học Công nghệ - ĐHQGHN',         'ĐH Công nghệ (UET)',      'Hà Nội',          true),
('HOU',       'Trường Đại học Mở Hà Nội',                  'ĐH Mở Hà Nội',            'Hà Nội',          true),
('IUH',       'Trường Đại học Công nghiệp TP.HCM',         'ĐH Công nghiệp TP.HCM',   'TP. Hồ Chí Minh', true)
ON CONFLICT (code) DO NOTHING;

-- 6. BACKFILL EXISTING MATCHES (Leaves 'Dai hoc Cong Nghiep', 'Test Uni' and NULL unassigned)
UPDATE users
SET university_id = (SELECT id FROM universities WHERE code = 'BDU')
WHERE university_id IS NULL
  AND university IN ('Trường Đại Học Bình Dương', 'Đại Học Bình Dương', 'Đại học Bình Dương');

UPDATE users
SET university_id = (SELECT id FROM universities WHERE code = 'HUST')
WHERE university_id IS NULL
  AND university IN ('Dai hoc Bach Khoa Ha Noi', 'Đại học Bách Khoa Hà Nội', 'ĐH Bách Khoa Hà Nội');

