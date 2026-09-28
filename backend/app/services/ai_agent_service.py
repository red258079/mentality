import re
from typing import List, Dict, Any, Optional
from dataclasses import dataclass, asdict


@dataclass
class RiskAssessmentResult:
    level: str  # "GREEN", "YELLOW", "RED"
    reasons: List[str]
    trigger_emergency: bool
    recommended_actions: List[str]


# High risk anxiety / crisis keywords
HIGH_RISK_KEYWORDS = [
    "kiệt sức tột cùng", "muốn bỏ cuộc", "bất an tột cùng",
    "không thể chịu nổi", "không muốn sống", "tuyệt vọng", "trầm cảm nặng"
]

MODERATE_RISK_KEYWORDS = [
    "căng thẳng", "mệt mỏi", "đau vai gáy", "đau lưng", "mất ngủ", "áp lực ca đêm"
]


class AIAgentService:
    @staticmethod
    def evaluate_psychological_risk(
        stress_level: int,
        sleep_hours: float,
        note_text: Optional[str] = None,
        physical_symptoms: Optional[List[str]] = None,
        stress_history_last_3_days: Optional[List[int]] = None
    ) -> RiskAssessmentResult:
        """
        AI Agent Psychological Risk Screening Algorithm (PHQ-2/GAD-7 & PSS-10 adaptation).
        Evaluates Green, Yellow, Red risk levels and triggers emergency protocol if needed.
        """
        reasons = []
        recs = []
        note_text_lower = (note_text or "").lower()

        # Check high risk keywords
        has_high_risk_keyword = any(kw in note_text_lower for kw in HIGH_RISK_KEYWORDS)

        # Check consecutive high stress (stress_level >= 4 for 3+ days or stress_level == 5 for 2+ days)
        history = stress_history_last_3_days or [stress_level]
        consecutive_high_stress = len(history) >= 2 and all(s >= 4 for s in history)
        extreme_stress = stress_level == 5

        # --- RED RISK EVALUATION ---
        if has_high_risk_keyword or (extreme_stress and consecutive_high_stress):
            if has_high_risk_keyword:
                reasons.append("Phát hiện từ khóa nguy cơ tâm lý cao trong nhật ký sinh viên.")
            if extreme_stress:
                reasons.append("Mức độ căng thẳng đạt đỉnh (5/5) kéo dài.")

            recs.extend([
                "Kích hoạt Cảnh báo Khẩn cấp Crisis Banner trên ứng dụng sinh viên.",
                "Cung cấp số điện thoại đường dây nóng hỗ trợ tâm lý 111 và Cấp cứu Y tế 115.",
                "Gửi thông báo ưu tiên hỗ trợ tới Cố vấn học tập / Phòng Y tế trường."
            ])

            return RiskAssessmentResult(
                level="RED",
                reasons=reasons,
                trigger_emergency=True,
                recommended_actions=recs
            )

        # --- YELLOW RISK EVALUATION ---
        is_moderate_stress = stress_level >= 3
        is_sleep_deprived = sleep_hours < 6.0
        has_physical_symptoms = bool(physical_symptoms and len(physical_symptoms) > 0)
        has_moderate_keyword = any(kw in note_text_lower for kw in MODERATE_RISK_KEYWORDS)

        if is_moderate_stress or is_sleep_deprived or has_physical_symptoms or has_moderate_keyword:
            if is_moderate_stress:
                reasons.append(f"Mức độ stress tăng cao ({stress_level}/5).")
            if is_sleep_deprived:
                reasons.append(f"Thiếu ngủ nghiêm trọng (chỉ ngủ {sleep_hours}h).")
            if has_physical_symptoms:
                reasons.append(f"Có triệu chứng thể chất ca làm: {', '.join(physical_symptoms or [])}.")

            recs.extend([
                "Thực hiện bài tập Hít thở Box Breathing 4-4-4-4 trong 3 phút.",
                "Tập 3 động tác giãn cơ cổ vai gáy giải tỏa áp lực ca đứng.",
                "Điều chỉnh nhiệt độ phòng ngủ 22-24°C và tắt màn hình 30p trước khi ngủ."
            ])

            return RiskAssessmentResult(
                level="YELLOW",
                reasons=reasons,
                trigger_emergency=False,
                recommended_actions=recs
            )

        # --- GREEN RISK (NORMAL) ---
        reasons.append("Trạng thái sinh hoạt và tâm lý ổn định.")
        recs.append("Duy trì chuỗi ngày điểm danh Streak và thực hiện bài tập gacha động viên.")

        return RiskAssessmentResult(
            level="GREEN",
            reasons=reasons,
            trigger_emergency=False,
            recommended_actions=recs
        )

    @staticmethod
    def get_agent_tool_definitions() -> List[Dict[str, Any]]:
        """
        Gemini Function Calling Tool schemas.
        Allows Gemini AI Model to call tools autonomously when data is missing.
        """
        return [
            {
                "name": "fetch_student_life_metrics",
                "description": "Lấy dữ liệu sinh hoạt thực tế của sinh viên (giờ ngủ ca gần nhất, ca làm ngày/đêm, điểm thể chất/tâm lý).",
                "parameters": {
                    "type": "OBJECT",
                    "properties": {
                        "user_id": {"type": "STRING", "description": "ID duy nhất của sinh viên"},
                        "days_limit": {"type": "INTEGER", "description": "Số ngày tra cứu lịch sử (mặc định 7)"}
                    },
                    "required": ["user_id"]
                }
            },
            {
                "name": "fetch_recent_journals",
                "description": "Đọc các bản ghi nhật ký cảm xúc và triệu chứng đau mỏi ca đứng của sinh viên trong 3 ngày qua.",
                "parameters": {
                    "type": "OBJECT",
                    "properties": {
                        "user_id": {"type": "STRING", "description": "ID duy nhất của sinh viên"}
                    },
                    "required": ["user_id"]
                }
            },
            {
                "name": "search_medical_mental_guidelines",
                "description": "Tra cứu tài liệu quy trình hỗ trợ tâm lý & sơ cứu y khoa chuẩn khi cẩm nang công ty thiếu thông tin.",
                "parameters": {
                    "type": "OBJECT",
                    "properties": {
                        "query_topic": {"type": "STRING", "description": "Chủ đề cần tra cứu (ví dụ: hoảng sợ, mất ngủ ca đêm, đau lưng)"}
                    },
                    "required": ["query_topic"]
                }
            },
            {
                "name": "trigger_crisis_emergency_alert",
                "description": "Kích hoạt cảnh báo hỗ trợ tâm lý khẩn cấp khi phát hiện sinh viên ở mức nguy cơ cao (Red Risk).",
                "parameters": {
                    "type": "OBJECT",
                    "properties": {
                        "user_id": {"type": "STRING", "description": "ID duy nhất của sinh viên"},
                        "risk_reason": {"type": "STRING", "description": "Lý do kích hoạt cảnh báo khẩn cấp"}
                    },
                    "required": ["user_id", "risk_reason"]
                }
            }
        ]
