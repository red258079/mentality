from fastapi import APIRouter, Depends, HTTPException, status, Header
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Optional

from app.db.database import get_db
from app.schemas.auth import (
    RegisterRequest, LoginRequest, TokenResponse,
    RefreshRequest, AccessTokenResponse, UserResponse,
)
from app.services import user_service
from app.core.security import verify_password

router = APIRouter()


# ── POST /auth/register ───────────────────────────────────────────────────────
@router.post(
    "/register",
    response_model=TokenResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Đăng ký tài khoản sinh viên mới",
)
async def register(
    payload: RegisterRequest,
    db: AsyncSession = Depends(get_db),
):
    # Check email uniqueness
    existing = await user_service.get_user_by_email(db, payload.email)
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email này đã được sử dụng. Vui lòng chọn email khác.",
        )

    user = await user_service.create_user(db, payload)
    tokens = await user_service.create_token_pair(db, user)

    return TokenResponse(
        access_token  = tokens["access_token"],
        refresh_token = tokens["refresh_token"],
        user          = UserResponse.model_validate(user),
    )


# ── POST /auth/login ──────────────────────────────────────────────────────────
@router.post(
    "/login",
    response_model=TokenResponse,
    summary="Đăng nhập, nhận JWT token",
)
async def login(
    payload: LoginRequest,
    db: AsyncSession = Depends(get_db),
):
    user = await user_service.get_user_by_email(db, payload.email)

    if user is None or not verify_password(payload.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email hoặc mật khẩu không đúng.",
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Tài khoản đã bị khóa. Liên hệ quản trị viên.",
        )

    tokens = await user_service.create_token_pair(db, user)

    return TokenResponse(
        access_token  = tokens["access_token"],
        refresh_token = tokens["refresh_token"],
        user          = UserResponse.model_validate(user),
    )


# ── POST /auth/refresh ────────────────────────────────────────────────────────
@router.post(
    "/refresh",
    response_model=AccessTokenResponse,
    summary="Gia hạn access token bằng refresh token",
)
async def refresh_token(
    payload: RefreshRequest,
    db: AsyncSession = Depends(get_db),
):
    result = await user_service.rotate_refresh_token(db, payload.refresh_token)
    if result is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token không hợp lệ hoặc đã hết hạn.",
        )
    return AccessTokenResponse(access_token=result["access_token"])


# ── GET /auth/me ──────────────────────────────────────────────────────────────
@router.get(
    "/me",
    response_model=UserResponse,
    summary="Lấy thông tin sinh viên đang đăng nhập",
)
async def get_me(
    authorization: Optional[str] = Header(None),
    db: AsyncSession = Depends(get_db),
):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Chưa xác thực.")

    token = authorization.split(" ", 1)[1]
    user = await user_service.get_current_user(db, token)
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token không hợp lệ hoặc đã hết hạn.")

    return UserResponse.model_validate(user)


# ── POST /auth/logout ─────────────────────────────────────────────────────────
@router.post(
    "/logout",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Đăng xuất (thu hồi refresh token)",
)
async def logout(
    payload: RefreshRequest,
    db: AsyncSession = Depends(get_db),
):
    await user_service.revoke_refresh_token(db, payload.refresh_token)
    return None
