from pydantic import BaseModel, EmailStr, Field
from typing import Optional
from uuid import UUID
from datetime import datetime


# ── Register ─────────────────────────────────────────────────────────────────
class RegisterRequest(BaseModel):
    full_name:  str       = Field(..., min_length=2, max_length=255)
    email:      EmailStr
    password:   str       = Field(..., min_length=6, max_length=128)
    student_id: Optional[str] = Field(None, max_length=20)
    university: Optional[str] = None
    major:      Optional[str] = None


# ── Login ─────────────────────────────────────────────────────────────────────
class LoginRequest(BaseModel):
    email:    EmailStr
    password: str


# ── Token Response ────────────────────────────────────────────────────────────
class TokenResponse(BaseModel):
    access_token:  str
    refresh_token: str
    token_type:    str = "bearer"
    user:          "UserResponse"


# ── Refresh ───────────────────────────────────────────────────────────────────
class RefreshRequest(BaseModel):
    refresh_token: str


class AccessTokenResponse(BaseModel):
    access_token: str
    token_type:   str = "bearer"


# ── User profile ──────────────────────────────────────────────────────────────
class UserResponse(BaseModel):
    id:         UUID
    email:      str
    full_name:  str
    role:       str
    student_id: Optional[str] = None
    university: Optional[str] = None
    major:      Optional[str] = None
    avatar_url: Optional[str] = None
    is_active:  bool
    created_at: datetime

    model_config = {"from_attributes": True}


# Fix forward reference
TokenResponse.model_rebuild()
