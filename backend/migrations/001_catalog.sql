-- Migration 001: Normalized Catalog for Universities and Companies
-- Idempotent, safe for existing tables and data.
-- Does not drop or modify existing text columns (users.university, intern_profiles.company_name).

-- 1. Create universities table
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

-- 2. Create companies table
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

-- 3. Add foreign keys to users and intern_profiles (nullable, non-destructive)
ALTER TABLE users ADD COLUMN IF NOT EXISTS university_id UUID REFERENCES universities(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_users_university_id ON users (university_id);

ALTER TABLE intern_profiles ADD COLUMN IF NOT EXISTS company_id UUID REFERENCES companies(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_intern_profiles_company_id ON intern_profiles (company_id);

-- 4. Enable Row Level Security (RLS) on new catalog tables
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

-- 5. Seed partner companies (excluding the in-memory 'custom' entry)
INSERT INTO companies (code, name, short_name, latitude, longitude, radius_meters, workplace_type, is_approved)
VALUES
('lg_display_hp',   'LG Display Hải Phòng',                  'LG Display',   20.8865, 106.5821, 600,  'factory_locker', true),
('samsung_sevt_tn', 'Samsung Electronics Thái Nguyên (SEVT)', 'Samsung SEVT', 21.4650, 105.8690, 800,  'factory_locker', true),
('samsung_sdv_bn',  'Samsung Display Bắc Ninh (SDV)',        'Samsung SDV',  21.2035, 105.9754, 800,  'factory_locker', true),
('fpt_software_hl', 'FPT Software Hòa Lạc (F-Ville)',         'FPT Software', 21.0131, 105.5273, 500,  'office',         true),
('vinfast_hp',      'Tổ hợp Nhà máy VinFast Hải Phòng',      'VinFast',      20.8350, 106.9320, 1000, 'factory_locker', true)
ON CONFLICT (code) DO NOTHING;

-- 6. Seed initial universities (3 existing in current data + starter list)
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

-- 7. Backfill users.university_id only for BDU and HUST
-- (Leaves 'Dai hoc Cong Nghiep', 'Test Uni' and NULL untouched and unassigned. Does NOT backfill company_id).

UPDATE users
SET university_id = (SELECT id FROM universities WHERE code = 'BDU')
WHERE university_id IS NULL
  AND university IN ('Trường Đại Học Bình Dương', 'Đại Học Bình Dương', 'Đại học Bình Dương');

UPDATE users
SET university_id = (SELECT id FROM universities WHERE code = 'HUST')
WHERE university_id IS NULL
  AND university IN ('Dai hoc Bach Khoa Ha Noi', 'Đại học Bách Khoa Hà Nội', 'ĐH Bách Khoa Hà Nội');
