from pydantic_settings import BaseSettings
from typing import List


class Settings(BaseSettings):
    # App
    APP_NAME: str = "Enigma API"
    DEBUG: bool = True

    # Database
    DATABASE_URL: str = "postgresql+asyncpg://postgres:258079@localhost:5432/enigma_db"

    # JWT
    SECRET_KEY: str = "CHANGE_THIS_TO_A_RANDOM_SECRET_KEY_IN_PRODUCTION"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    # Google Gemini
    GEMINI_API_KEY: str = ""

    # Groq AI LPU
    GROQ_API_KEY: str = ""

    # Crisis contacts shown in the fixed crisis message of the AI chat.
    # Every value below MUST be verified and filled in (via .env) before production.
    # Values that still start with "[CẦN ĐIỀN" are reported as unfilled at startup.
    CRISIS_CONTACT_MENTOR: str = "[CẦN ĐIỀN: tên + SĐT người phụ trách/mentor thực tập]"
    CRISIS_CONTACT_SCHOOL_COUNSELING: str = "[CẦN ĐIỀN: phòng tư vấn tâm lý của trường – SĐT/email]"
    CRISIS_CONTACT_COMPANY_CLINIC: str = "[CẦN ĐIỀN: trạm y tế công ty – SĐT/vị trí]"
    CRISIS_CONTACT_EMERGENCY: str = "115"
    CRISIS_FOLLOWUP_HOURS: str = "[CẦN ĐIỀN: giờ làm việc có người theo dõi, ví dụ 8:00–17:00, thứ 2–thứ 6]"
    # Within this window a new explicit-crisis message does not create a duplicate flag
    # and receives a short follow-up instead of the full fixed message.
    CRISIS_FLAG_DEDUP_HOURS: int = 6

    # Chat retention period in days (default 90 days)
    CHAT_RETENTION_DAYS: int = 90

    # Google OAuth
    GOOGLE_CLIENT_ID: str = "36729513984-esqq4r98jnm3utb4grbj6gu6if5l6cqi.apps.googleusercontent.com"
    GOOGLE_ANDROID_CLIENT_ID: str = "36729513984-esqq4r98jnm3utb4grbj6gu6if5l6cqi.apps.googleusercontent.com"

    # Firebase (path to service account JSON)
    FIREBASE_CREDENTIALS_PATH: str = "firebase_credentials.json"

    # ── SMTP Email (Gmail App Password) ──────────────────────────────────────
    # Hướng dẫn lấy App Password Gmail:
    # 1. myaccount.google.com → Bảo mật → Xác minh 2 bước (phải bật)
    # 2. Bảo mật → App passwords → Tạo mới → Đặt tên "Enigma" → Copy 16 ký tự
    SMTP_HOST: str     = "smtp.gmail.com"
    SMTP_PORT: int     = 587
    SMTP_USER: str     = ""          # Điền Gmail của bạn vào .env: SMTP_USER=abc@gmail.com
    SMTP_PASSWORD: str = ""          # Điền App Password 16 ký tự: SMTP_PASSWORD=xxxx xxxx xxxx xxxx
    SMTP_FROM_NAME: str = "Enigma – Hỗ trợ tâm lý"

    # CORS - allow Flutter app
    CORS_ORIGINS: List[str] = [
        "http://localhost",
        "http://localhost:3000",
        "http://10.0.2.2",        # Android emulator → host machine
        "*",
    ]

    class Config:
        env_file = ".env"


settings = Settings()

