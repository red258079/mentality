from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker
from sqlalchemy.orm import declarative_base
from app.core.config import settings

# Chuẩn hoá URL kết nối cho asyncpg và Supabase Pooler
db_url = settings.DATABASE_URL
if db_url.startswith("postgresql://"):
    db_url = db_url.replace("postgresql://", "postgresql+asyncpg://", 1)
if "sslmode=require" in db_url:
    db_url = db_url.replace("sslmode=require", "ssl=require")

# Khi kết nối qua Supabase Connection Pooler (Supavisor / PgBouncer cổng 5432 hoặc 6543),
# cần tắt statement cache để tránh xung đột prepared statements giữa các phiên kết nối.
connect_args = {}
if "pooler.supabase.com" in db_url or ":6543" in db_url:
    connect_args["statement_cache_size"] = 0

engine = create_async_engine(
    db_url,
    echo=False,  # Tắt echo query log để tối ưu throughput I/O cho Python event loop
    connect_args=connect_args,
    pool_pre_ping=True,
    pool_recycle=300,
    pool_size=10,
    max_overflow=20,
    pool_timeout=30,
)

AsyncSessionLocal = async_sessionmaker(
    engine,
    expire_on_commit=False
)

Base = declarative_base()

async def get_db():
    async with AsyncSessionLocal() as session:
        try:
            yield session
        finally:
            await session.close()

async def create_tables():
    """
    Kiểm tra kết nối database khi server khởi động.
    """
    from sqlalchemy import text
    try:
        async with engine.begin() as conn:
            await conn.execute(text("""
                CREATE TABLE IF NOT EXISTS user_feature_onboardings (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                    feature_key VARCHAR(50) NOT NULL,
                    completed BOOLEAN NOT NULL DEFAULT TRUE,
                    completed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                    CONSTRAINT uq_user_feature_onboarding UNIQUE (user_id, feature_key)
                )
            """))
            await conn.execute(text("""
                CREATE INDEX IF NOT EXISTS idx_user_feature_onboarding_user ON user_feature_onboardings (user_id)
            """))
            result = await conn.execute(text("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public'"))
            count = result.scalar()
            print(f"[OK] Ket noi PostgreSQL thanh cong - {count} bang dang hoat dong trong database.")
    except Exception as e:
        print(f"[WARN] Ket noi database gap loi luc khoi dong: {e}")
