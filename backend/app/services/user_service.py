from typing import Optional
from datetime import datetime, timedelta, timezone
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
import secrets
import logging

from app.db.models.user import User
from app.db.models.intern_profile import InternProfile
from app.db.models.refresh_token import RefreshToken
from app.core.security import (
    hash_password, verify_password,
    create_access_token, decode_access_token,
    generate_refresh_token, hash_token, refresh_token_expires_at,
)
from app.schemas.auth import RegisterRequest
from app.services.email_service import send_otp_email

logger = logging.getLogger(__name__)


# ── User CRUD ─────────────────────────────────────────────────────────────────

async def get_user_by_email(db: AsyncSession, email: str) -> Optional[User]:
    result = await db.execute(select(User).where(User.email == email))
    return result.scalar_one_or_none()


async def get_user_by_id(db: AsyncSession, user_id) -> Optional[User]:
    result = await db.execute(select(User).where(User.id == user_id))
    return result.scalar_one_or_none()


async def create_user(db: AsyncSession, data: RegisterRequest) -> User:
    user = User(
        email         = data.email,
        password_hash = hash_password(data.password),
        full_name     = data.full_name,
        student_id    = data.student_id or None,
        university    = data.university,
        major         = data.major,
    )
    db.add(user)
    await db.flush()  # get user.id before commit

    # Auto-create intern profile
    profile = InternProfile(user_id=user.id)
    db.add(profile)

    await db.commit()
    await db.refresh(user)
    return user


# ── Token pair generation ─────────────────────────────────────────────────────

async def create_token_pair(db: AsyncSession, user: User, device_info: str = None) -> dict:
    """Create access_token + refresh_token, persist refresh in DB."""
    access_token  = create_access_token({"sub": str(user.id), "role": user.role})
    raw_refresh   = generate_refresh_token()
    token_hash    = hash_token(raw_refresh)

    rt = RefreshToken(
        user_id     = user.id,
        token_hash  = token_hash,
        device_info = device_info,
        expires_at  = refresh_token_expires_at(),
    )
    db.add(rt)
    await db.commit()

    return {
        "access_token":  access_token,
        "refresh_token": raw_refresh,
    }


# ── Refresh token flow ────────────────────────────────────────────────────────

async def rotate_refresh_token(
    db: AsyncSession, raw_token: str
) -> Optional[dict]:
    """Verify, revoke old refresh token, issue new token pair. Returns None if invalid."""
    token_hash = hash_token(raw_token)
    result = await db.execute(
        select(RefreshToken).where(
            RefreshToken.token_hash == token_hash,
            RefreshToken.is_revoked == False,
        )
    )
    rt: Optional[RefreshToken] = result.scalar_one_or_none()

    if rt is None:
        return None  # token not found or already revoked

    if rt.expires_at.replace(tzinfo=timezone.utc) < datetime.now(timezone.utc):
        return None  # token expired

    # Revoke old token (rotation strategy)
    rt.is_revoked = True
    await db.flush()

    user = await get_user_by_id(db, rt.user_id)
    if user is None or not user.is_active:
        return None

    return await create_token_pair(db, user)


# ── Revoke refresh token (logout) ─────────────────────────────────────────────

async def revoke_refresh_token(db: AsyncSession, raw_token: str) -> bool:
    token_hash = hash_token(raw_token)
    result = await db.execute(
        select(RefreshToken).where(RefreshToken.token_hash == token_hash)
    )
    rt: Optional[RefreshToken] = result.scalar_one_or_none()
    if rt:
        rt.is_revoked = True
        await db.commit()
        return True
    return False


# ── Authenticate (get_current_user dependency) ────────────────────────────────

async def get_current_user(db: AsyncSession, token: str) -> Optional[User]:
    payload = decode_access_token(token)
    if payload is None:
        return None
    user_id = payload.get("sub")
    if user_id is None:
        return None
    return await get_user_by_id(db, user_id)


from fastapi import BackgroundTasks

async def generate_otp_for_user(
    db: AsyncSession, email: str, background_tasks: Optional[BackgroundTasks] = None
) -> bool:
    """
    Tạo OTP 6 số, lưu vào DB, gửi email trong background task.
    Trả True nếu email tồn tại, False nếu không.
    """
    user = await get_user_by_email(db, email)
    if user is None or not user.is_active:
        return False

    # Tạo OTP ngẫu nhiên 6 chữ số an toàn
    otp_code = str(secrets.randbelow(1_000_000)).zfill(6)

    # Lưu vào DB, hết hạn sau 5 phút
    user.otp_code       = otp_code
    user.otp_expires_at = datetime.now(timezone.utc) + timedelta(minutes=5)
    await db.commit()

    # Gửi email trong background task để API trả về ngay lập tức cho client
    if background_tasks:
        background_tasks.add_task(
            send_otp_email,
            to_email=user.email,
            otp_code=otp_code,
            recipient_name=user.full_name or "bạn",
        )
    else:
        await send_otp_email(
            to_email=user.email,
            otp_code=otp_code,
            recipient_name=user.full_name or "bạn",
        )

    return True


# ── Reset Password: Verify OTP & Update Password ──────────────────────────────

async def reset_password_with_otp(
    db: AsyncSession, email: str, otp: str, new_password: str
) -> bool:
    """
    Kiểm tra OTP hợp lệ → đổi mật khẩu → xóa OTP (one-time use).
    Trả True nếu thành công, False nếu OTP sai/hết hạn/email không tồn tại.
    """
    user = await get_user_by_email(db, email)
    if user is None or not user.is_active:
        return False

    # Kiểm tra OTP có tồn tại
    if user.otp_code is None or user.otp_expires_at is None:
        return False  # Chưa tạo OTP hoặc đã dùng rồi

    # So sánh OTP (constant-time để tránh timing attack)
    if not secrets.compare_digest(user.otp_code, otp):
        return False  # OTP sai

    # Kiểm tra hết hạn (normalize timezone)
    now     = datetime.now(timezone.utc)
    expires = user.otp_expires_at
    if expires.tzinfo is None:
        expires = expires.replace(tzinfo=timezone.utc)
    if now > expires:
        return False  # OTP đã hết hạn (quá 5 phút)

    # Cập nhật mật khẩu mới + xóa OTP ngay (one-time use)
    user.password_hash  = hash_password(new_password)
    user.otp_code       = None
    user.otp_expires_at = None

    await db.commit()
    return True

