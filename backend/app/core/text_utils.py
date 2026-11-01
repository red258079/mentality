import unicodedata
import re
from typing import Optional


def normalize_vietnamese_text(text: Optional[str]) -> str:
    """
    Normalizes Vietnamese text for accent-insensitive, case-insensitive comparison and search.
    - Converts to lower case
    - Decomposes combined diacritics (NFD) and strips them
    - Replaces 'đ' and 'Đ' with 'd'
    - Normalizes multiple spaces into a single space
    """
    if not text:
        return ""
    
    # Custom replacement for Vietnamese d-with-stroke
    cleaned = text.replace("đ", "d").replace("Đ", "D")
    
    # NFD decomposition separates base characters and combining diacritical marks
    decomposed = unicodedata.normalize("NFD", cleaned)
    
    # Strip combining diacritical marks (Unicode category 'Mn')
    without_marks = "".join(char for char in decomposed if unicodedata.category(char) != "Mn")
    
    # Lowercase and collapse consecutive whitespaces
    lowered = without_marks.lower().strip()
    return re.sub(r"\s+", " ", lowered)


def is_accent_insensitive_match(pattern: str, target: str) -> bool:
    """
    Checks whether target contains pattern in an accent-insensitive and case-insensitive manner.
    """
    norm_pattern = normalize_vietnamese_text(pattern)
    norm_target = normalize_vietnamese_text(target)
    if not norm_pattern:
        return True
    return norm_pattern in norm_target
