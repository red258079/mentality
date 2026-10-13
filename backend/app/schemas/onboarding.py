from pydantic import BaseModel
from typing import List, Optional

class OnboardingStatusResponse(BaseModel):
    completed_features: List[str]

class UpdateOnboardingRequest(BaseModel):
    feature_key: str
    completed: bool = True
