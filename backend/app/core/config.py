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

