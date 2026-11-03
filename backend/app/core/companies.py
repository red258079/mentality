from typing import List, Dict, Any, Optional

DEFAULT_COMPANIES: List[Dict[str, Any]] = [
    {
        "id": "lg_display_hp",
        "name": "LG Display Hải Phòng",
        "short_name": "LG Display",
        "address": "Lô E, KCN Tràng Duệ, An Dương, Hải Phòng",
        "latitude": 20.8865,
        "longitude": 106.5821,
        "radius_meters": 600,
        "workplace_type": "factory_locker",
        "workplace_type_label": "Nhà máy phòng sạch (Cất điện thoại tủ đồ)",
        "available_shifts": [
            {"id": "day_12h", "label": "Ca ngày (08:00 – 20:00)", "start_time": "08:00", "end_time": "20:00", "is_night": False},
            {"id": "night_12h", "label": "Ca đêm (20:00 – 08:00)", "start_time": "20:00", "end_time": "08:00", "is_night": True},
        ],
        "default_shift": "day_12h"
    },
    {
        "id": "samsung_sevt_tn",
        "name": "Samsung Electronics Thái Nguyên (SEVT)",
        "short_name": "Samsung SEVT",
        "address": "KCN Yên Bình, Phổ Yên, Thái Nguyên",
        "latitude": 21.4650,
        "longitude": 105.8690,
        "radius_meters": 800,
        "workplace_type": "factory_locker",
        "workplace_type_label": "Nhà máy sản xuất (Cất điện thoại tủ đồ)",
        "available_shifts": [
            {"id": "day_12h", "label": "Ca ngày (08:00 – 20:00)", "start_time": "08:00", "end_time": "20:00", "is_night": False},
            {"id": "night_12h", "label": "Ca đêm (20:00 – 08:00)", "start_time": "20:00", "end_time": "08:00", "is_night": True},
        ],
        "default_shift": "day_12h"
    },
    {
        "id": "samsung_sdv_bn",
        "name": "Samsung Display Bắc Ninh (SDV)",
        "short_name": "Samsung SDV",
        "address": "KCN Yên Phong, Yên Phong, Bắc Ninh",
        "latitude": 21.2035,
        "longitude": 105.9754,
        "radius_meters": 800,
        "workplace_type": "factory_locker",
        "workplace_type_label": "Nhà máy sản xuất (Cất điện thoại tủ đồ)",
        "available_shifts": [
            {"id": "day_12h", "label": "Ca ngày (08:00 – 20:00)", "start_time": "08:00", "end_time": "20:00", "is_night": False},
            {"id": "night_12h", "label": "Ca đêm (20:00 – 08:00)", "start_time": "20:00", "end_time": "08:00", "is_night": True},
        ],
        "default_shift": "day_12h"
    },
    {
        "id": "fpt_software_hl",
        "name": "FPT Software Hòa Lạc (F-Ville)",
        "short_name": "FPT Software",
        "address": "Khu Công nghệ cao Hòa Lạc, Thạch Thất, Hà Nội",
        "latitude": 21.0131,
        "longitude": 105.5273,
        "radius_meters": 500,
        "workplace_type": "office",
        "workplace_type_label": "Văn phòng / Doanh nghiệp CNTT (Được dùng điện thoại)",
        "available_shifts": [
            {"id": "office_8h", "label": "Ca hành chính (08:30 – 17:30)", "start_time": "08:30", "end_time": "17:30", "is_night": False},
        ],
        "default_shift": "office_8h"
    },
    {
        "id": "vinfast_hp",
        "name": "Tổ hợp Nhà máy VinFast Hải Phòng",
        "short_name": "VinFast",
        "address": "KCN Đình Vũ - Cát Hải, Cát Hải, Hải Phòng",
        "latitude": 20.8350,
        "longitude": 106.9320,
        "radius_meters": 1000,
        "workplace_type": "factory_locker",
        "workplace_type_label": "Nhà máy lắp ráp (Cất điện thoại tủ đồ)",
        "available_shifts": [
            {"id": "day_12h", "label": "Ca ngày (08:00 – 20:00)", "start_time": "08:00", "end_time": "20:00", "is_night": False},
            {"id": "night_12h", "label": "Ca đêm (20:00 – 08:00)", "start_time": "20:00", "end_time": "08:00", "is_night": True},
        ],
        "default_shift": "day_12h"
    },
    {
        "id": "custom",
        "name": "Công ty khác (Tự định vị / Văn phòng)",
        "short_name": "Công ty khác",
        "address": "Tùy chỉnh theo sinh viên",
        "latitude": None,
        "longitude": None,
        "radius_meters": 300,
        "workplace_type": "custom",
        "workplace_type_label": "Tự thiết lập tọa độ và ca làm",
        "available_shifts": [
            {"id": "office_8h", "label": "Ca hành chính (08:00 – 17:00)", "start_time": "08:00", "end_time": "17:00", "is_night": False},
            {"id": "day_12h", "label": "Ca ngày (08:00 – 20:00)", "start_time": "08:00", "end_time": "20:00", "is_night": False},
            {"id": "night_12h", "label": "Ca đêm (20:00 – 08:00)", "start_time": "20:00", "end_time": "08:00", "is_night": True},
        ],
        "default_shift": "office_8h"
    }
]


def find_company_by_name(name: Optional[str]) -> Optional[Dict[str, Any]]:
    if not name or not name.strip():
        return None
    name_clean = name.strip().lower()
    for c in DEFAULT_COMPANIES:
        if (
            c["name"].lower() == name_clean
            or c["short_name"].lower() == name_clean
            or c["id"].lower() == name_clean
        ):
            return c
    return None
