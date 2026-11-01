from pydantic import BaseModel, Field, field_validator
from typing import Optional, Literal
from uuid import UUID
from datetime import datetime


class UniversityResponse(BaseModel):
    id: UUID
    code: str
    name: str
    short_name: Optional[str] = None
    city: Optional[str] = None
    is_approved: bool
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class CompanyResponse(BaseModel):
    id: UUID
    code: str
    name: str
    short_name: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    radius_meters: int = 500
    workplace_type: str = "factory_locker"
    is_approved: bool
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class CustomCatalogRequest(BaseModel):
    entity_type: Literal["university", "company"] = Field(..., description="Loại đơn vị: 'university' hoặc 'company'")
    name: str = Field(..., min_length=2, max_length=120, description="Tên đầy đủ của trường hoặc công ty (2-120 ký tự)")
    short_name: Optional[str] = Field(None, max_length=100, description="Tên viết tắt hoặc tên ngắn gọn")
    city: Optional[str] = Field(None, max_length=100, description="Tỉnh/Thành phố (dành cho trường học)")
    address: Optional[str] = Field(None, max_length=255, description="Địa chỉ công ty (nếu có)")
    workplace_type: Optional[str] = Field("factory_locker", max_length=50, description="Loại hình môi trường làm việc")

    @field_validator("name")
    @classmethod
    def validate_name(cls, v: str) -> str:
        trimmed = v.strip()
        if len(trimmed) < 2 or len(trimmed) > 120:
            raise ValueError("Tên đơn vị phải có độ dài từ 2 đến 120 ký tự sau khi cắt khoảng trắng thừa.")
        return trimmed

    @field_validator("short_name", "city", "address")
    @classmethod
    def clean_optional_strings(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            v_strip = v.strip()
            return v_strip if v_strip else None
        return None


class AdminCatalogReviewRequest(BaseModel):
    entity_type: Literal["university", "company"] = Field(...)
    entity_id: UUID = Field(...)
    action: Literal["approve", "merge", "reject"] = Field(...)
    target_canonical_id: Optional[UUID] = Field(None, description="ID đơn vị chuẩn hóa nếu chọn thao tác merge")


# ── Catalog Items for Mobile Picker ───────────────────────────────────────────
class UniversityCatalogItem(BaseModel):
    id: UUID
    name: str
    short_name: Optional[str] = None
    city: Optional[str] = None

    class Config:
        from_attributes = True


class CompanyCatalogItem(BaseModel):
    id: UUID
    name: str
    short_name: Optional[str] = None

    class Config:
        from_attributes = True


# ── Profile Catalog Update Request & Response ────────────────────────────────
class UpdateProfileCatalogRequest(BaseModel):
    university_id: Optional[UUID] = None
    company_id: Optional[UUID] = None
    other_university_name: Optional[str] = None
    other_company_name: Optional[str] = None


class CatalogEntitySummary(BaseModel):
    id: UUID
    name: str
    is_pending: bool

    class Config:
        from_attributes = True


class ProfileCatalogUpdateResponse(BaseModel):
    university: Optional[CatalogEntitySummary] = None
    company: Optional[CatalogEntitySummary] = None

