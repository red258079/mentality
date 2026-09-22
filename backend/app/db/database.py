from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker
from sqlalchemy.orm import declarative_base
from app.core.config import settings

engine = create_async_engine(
    settings.DATABASE_URL,
    echo=settings.DEBUG,
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

    QUAN TRỌNG: Các bảng được tạo thông qua schema.sql (chạy setup_db.ps1)
    và quản lý migrations bằng Alembic.
    KHÔNG dùng Base.metadata.create_all() vì schema.sql có các tính năng
    PostgreSQL-native (ENUM types, triggers, GENERATED columns) mà
    SQLAlchemy create_all không thể tái tạo chính xác.
    """
    from sqlalchemy import text
    async with engine.begin() as conn:
        result = await conn.execute(text("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public'"))
        count = result.scalar()
        print(f"✅ Kết nối PostgreSQL thành công — {count} bảng đang hoạt động trong enigma_db")

