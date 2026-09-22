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
