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

# ── Google Auth ──────────────────────────────────────────────────────────────
class GoogleAuthRequest(BaseModel):
    id_token: str
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
    id:                    UUID
    email:                 str
    full_name:             str
    role:                  str
    student_id:            Optional[str] = None
    university_id:         Optional[UUID] = None
    university:            Optional[str] = None
    university_name:       Optional[str] = None
    university_is_pending: Optional[bool] = None
    company_id:            Optional[UUID] = None
    company_name:          Optional[str] = None
    company_is_pending:    Optional[bool] = None
    is_pending:            Optional[bool] = None
    major:                 Optional[str] = None
    avatar_url:            Optional[str] = None
    is_active:             bool
    created_at:            datetime

    model_config = {"from_attributes": True}


# ── Forgot Password ───────────────────────────────────────────────────────────
class ForgotPasswordRequest(BaseModel):
    email: EmailStr


# ── Reset Password ────────────────────────────────────────────────────────────
class ResetPasswordRequest(BaseModel):
    email:        EmailStr
    otp:          str       = Field(..., min_length=6, max_length=6, pattern=r'^\d{6}$')
    new_password: str       = Field(..., min_length=6, max_length=128)


# ── Update Profile ─────────────────────────────────────────────────────────
class UpdateProfileRequest(BaseModel):
    full_name:             Optional[str] = Field(None, min_length=2, max_length=255)
    student_id:            Optional[str] = Field(None, max_length=20)
    university_id:         Optional[UUID] = None
    university:            Optional[str] = None
    company_id:            Optional[UUID] = None
    other_university_name: Optional[str] = None
    other_company_name:    Optional[str] = None
    major:                 Optional[str] = None
    avatar_url:            Optional[str] = None



# ── Change Password ─────────────────────────────────────────────────────────
class ChangePasswordRequest(BaseModel):
    old_password: str
    new_password: str = Field(..., min_length=6, max_length=128)


# Fix forward reference
TokenResponse.model_rebuild()
