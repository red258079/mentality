"""
Function Calling Service - AI Agent Tool Executor
"""
import json
import logging
from datetime import date, timedelta
from typing import Any, Dict, List, Optional

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc

logger = logging.getLogger(__name__)

TOOL_DEFINITIONS = [
    {
        "name": "fetch_student_life_metrics",
        "description": "Lay du lieu sinh hoat thuc te cua sinh vien bao gom: gio ngu trung binh, muc stress, xu huong 7 ngay gan nhat.",
        "parameters": {
            "type": "object",
            "properties": {
                "user_id": {"type": "string", "description": "UUID duy nhat cua sinh vien"},
                "days_limit": {"type": "integer", "description": "So ngay lich su can lay (mac dinh 7)", "default": 7}
            },
            "required": ["user_id"]
        }
    },
    {
        "name": "fetch_recent_journals",
        "description": "Doc lich su nhat ky cam xuc, trieu chung the chat cua sinh vien trong N ngay gan nhat.",
        "parameters": {
            "type": "object",
            "properties": {
                "user_id": {"type": "string", "description": "UUID duy nhat cua sinh vien"},
                "days_limit": {"type": "integer", "description": "So ngay nhat ky can lay (mac dinh 3)", "default": 3}
            },
            "required": ["user_id"]
        }
    },
    {
        "name": "search_medical_mental_guidelines",
        "description": "Tra cuu huong dan cham soc suc khoe tam than va y khoa khi cam nang cong ty khong co du thong tin.",
        "parameters": {
            "type": "object",
            "properties": {
                "query_topic": {"type": "string", "description": "Chu de can tra cuu"},
                "severity": {"type": "string", "enum": ["mild", "moderate", "severe"], "default": "mild"}
            },
            "required": ["query_topic"]
        }
    },
    {
        "name": "trigger_crisis_emergency_alert",
        "description": "Kich hoat giao thuc canh bao khan cap khi phat hien sinh vien co nguy co tam ly cao (RED level).",
        "parameters": {
            "type": "object",
            "properties": {
                "user_id": {"type": "string", "description": "UUID sinh vien"},
                "risk_reason": {"type": "string", "description": "Ly do kich hoat canh bao"},
                "risk_level": {"type": "string", "enum": ["RED", "YELLOW"]}
            },
            "required": ["user_id", "risk_reason", "risk_level"]
        }
    },
    {
        "name": "get_daily_life_log_summary",
        "description": "Lay tom tat nhat ky sinh hoat hang ngay: streak diem danh, gio ngu, stress hom nay.",
        "parameters": {
            "type": "object",
            "properties": {
                "user_id": {"type": "string", "description": "UUID sinh vien"}
            },
            "required": ["user_id"]
        }
    }
]

MEDICAL_GUIDELINES_KB: Dict[str, Dict[str, Any]] = {
    "hoang loan": {
        "title": "Xu ly con hoang loan (Panic Attack)",
        "steps": [
            "1. Ngoi hoac nam xuong noi an toan, tha long co the.",
            "2. Thuc hien Box Breathing: Hit 4s - Giu 4s - Tho ra 4s - Giu 4s.",
            "3. Nhin xung quanh va dat ten 5 vat ban thay (ky thuat grounding 5-4-3-2-1).",
            "4. Noi chuyen voi ai do ban tin tuong hoac goi Hotline 1800 599 920.",
        ],
        "hotline": "1800 599 920",
        "severity_threshold": "moderate"
    },
    "mat ngu ca dem": {
        "title": "Phuc hoi giac ngu sau ca dem",
        "steps": [
            "1. Deo kinh chan anh sang xanh khi ve nha ban ngay.",
            "2. Giu phong toi hoan toan bang rem day, nhiet do 22-24 do C.",
            "3. Khong dung thiet bi dien tu 30 phut truoc khi ngu.",
            "4. Ngam chan nuoc am 15 phut de kich hoat giai phong Melatonin.",
            "5. Tranh caffeine trong 6 gio truoc khi ngu.",
        ],
        "hotline": None,
        "severity_threshold": "mild"
    },
    "dau lung man tinh": {
        "title": "Giam dau lung do dung lau",
        "steps": [
            "1. Thuc hien bai keo gian lung duoi 2 phut moi 2 gio.",
            "2. Dieu chinh tu the dung: vai thang, bung hop nhe, trong luong deu 2 chan.",
            "3. Biet lot giay chong moi ESD neu co the.",
            "4. Bo sung 2L nuoc/ngay de duy tri do dan hoi dia dem.",
            "5. Tham khao y kien bac si neu dau keo dai hon 2 tuan.",
        ],
        "hotline": None,
        "severity_threshold": "mild"
    },
    "cang thang post-thuc tap": {
        "title": "Hoi chung kiet suc hau thuc tap (Post-Intern Burnout)",
        "steps": [
            "1. Nhin nhan va chap nhan cam xuc kiet suc la phan ung binh thuong.",
            "2. Lap ke hoach phuc hoi tuan: ngu du giac, tap the duc nhe.",
            "3. Ket noi lai voi ban be, gia dinh - tranh co lap xa hoi.",
            "4. Viet nhat ky cam xuc hang ngay de theo doi tien trinh hoi phuc.",
            "5. Tim kiem ho tro tam ly chuyen nghiep neu trieu chung keo dai.",
        ],
        "hotline": "111",
        "severity_threshold": "moderate"
    },
    "roi loan nhip sinh hoc": {
        "title": "Dieu chinh nhip sinh hoc sau ca dem/doi ca",
        "steps": [
            "1. Phoi nang 15-20 phut vao buoi sang de reset dong ho sinh hoc.",
            "2. An uong theo lich co dinh, tranh an khuya sau 22h.",
            "3. Tranh ngu trua qua 20 phut de khong anh huong giac ngu dem.",
            "4. Dung melatonin lieu thap (0.5-1mg) sau khi tham khao bac si.",
        ],
        "hotline": None,
        "severity_threshold": "mild"
    }
}


def _match_guideline_topic(query_topic: str) -> Optional[Dict[str, Any]]:
    topic_lower = query_topic.lower()
    best_match = None
    best_score = 0
    for key, value in MEDICAL_GUIDELINES_KB.items():
        key_words = set(key.lower().split())
        query_words = set(topic_lower.split())
        score = len(key_words & query_words)
        if key in topic_lower:
            score += 3
        if score > best_score:
            best_score = score
            best_match = value
    return best_match if best_score > 0 else None


class FunctionCallingService:
    """Dich vu thuc thi Function Calling cho AI Agent."""

    @staticmethod
    def get_tool_definitions() -> List[Dict[str, Any]]:
        return TOOL_DEFINITIONS

    @staticmethod
    async def execute_tool(
        tool_name: str,
        tool_args: Dict[str, Any],
        db: Optional[AsyncSession] = None
    ) -> Dict[str, Any]:
        logger.info(f"[FunctionCalling] Executing tool: {tool_name}")
        executor_map = {
            "fetch_student_life_metrics": FunctionCallingService._fetch_student_life_metrics,
            "fetch_recent_journals": FunctionCallingService._fetch_recent_journals,
            "search_medical_mental_guidelines": FunctionCallingService._search_medical_mental_guidelines,
            "trigger_crisis_emergency_alert": FunctionCallingService._trigger_crisis_emergency_alert,
            "get_daily_life_log_summary": FunctionCallingService._get_daily_life_log_summary,
        }
        if tool_name not in executor_map:
            return {"error": f"Tool '{tool_name}' khong ton tai."}
        try:
            result = await executor_map[tool_name](tool_args, db)
            return result
        except Exception as e:
            logger.error(f"[FunctionCalling] Tool {tool_name} failed: {e}")
            return {"error": str(e), "tool_name": tool_name}

    @staticmethod
    async def _fetch_student_life_metrics(args: Dict[str, Any], db: Optional[AsyncSession]) -> Dict[str, Any]:
        user_id = args.get("user_id")
        days_limit = min(int(args.get("days_limit", 7)), 30)
        if not db or not user_id:
            return {"status": "no_data", "avg_sleep_hours": 7.0, "avg_stress_level": 2, "total_entries": 0}
        try:
            from app.db.models.journal import Journal
            since_date = date.today() - timedelta(days=days_limit)
            result = await db.execute(
                select(Journal).where(Journal.user_id == user_id, Journal.journal_date >= since_date).order_by(desc(Journal.journal_date))
            )
            journals = list(result.scalars().all())
            if not journals:
                return {"status": "no_data", "user_id": str(user_id), "total_entries": 0}
            avg_sleep = sum(float(j.sleep_hours) for j in journals) / len(journals)
            avg_stress = sum(j.stress_level for j in journals) / len(journals)
            all_symptoms = []
            for j in journals:
                if j.physical_symptoms:
                    all_symptoms.extend(j.physical_symptoms)
            stress_values = [j.stress_level for j in journals]
            recent_stress = stress_values[:3] if len(stress_values) >= 3 else stress_values
            older_stress = stress_values[-3:] if len(stress_values) >= 6 else []
            trend = "stable"
            if older_stress:
                if sum(recent_stress)/len(recent_stress) > sum(older_stress)/len(older_stress) + 0.5:
                    trend = "worsening"
                elif sum(recent_stress)/len(recent_stress) < sum(older_stress)/len(older_stress) - 0.5:
                    trend = "improving"
            return {
                "status": "ok", "user_id": str(user_id), "days_analyzed": days_limit,
                "total_entries": len(journals), "avg_sleep_hours": round(avg_sleep, 1),
                "avg_stress_level": round(avg_stress, 1), "stress_trend": trend,
                "common_symptoms": list(set(all_symptoms))[:5],
                "latest_date": str(journals[0].journal_date)
            }
        except Exception as e:
            return {"status": "error", "message": str(e)}

    @staticmethod
    async def _fetch_recent_journals(args: Dict[str, Any], db: Optional[AsyncSession]) -> Dict[str, Any]:
        user_id = args.get("user_id")
        days_limit = min(int(args.get("days_limit", 3)), 14)
        if not db or not user_id:
            return {"status": "no_data", "journals": []}
        try:
            from app.db.models.journal import Journal
            since_date = date.today() - timedelta(days=days_limit)
            result = await db.execute(
                select(Journal).where(Journal.user_id == user_id, Journal.journal_date >= since_date).order_by(desc(Journal.journal_date))
            )
            journals = list(result.scalars().all())
            journal_data = [
                {
                    "date": str(j.journal_date), "stress_level": j.stress_level,
                    "sleep_hours": float(j.sleep_hours), "symptoms": j.physical_symptoms or [],
                    "sentiment": j.ai_sentiment,
                    "note_preview": ((j.note or "")[:150] + "...") if j.note and len(j.note) > 150 else j.note
                }
                for j in journals
            ]
            return {"status": "ok", "user_id": str(user_id), "journals": journal_data, "total_count": len(journal_data)}
        except Exception as e:
            return {"status": "error", "message": str(e), "journals": []}

    @staticmethod
    async def _search_medical_mental_guidelines(args: Dict[str, Any], db: Optional[AsyncSession]) -> Dict[str, Any]:
        query_topic = args.get("query_topic", "")
        severity = args.get("severity", "mild")
        matched = _match_guideline_topic(query_topic)
        if matched:
            return {
                "status": "found", "source": "Enigma Medical Knowledge Base",
                "topic": query_topic, "severity": severity, "guideline": matched,
                "disclaimer": "Thong tin chi mang tinh tham khao. Neu trieu chung nghiem trong, hay tham van bac si hoac goi 111."
            }
        return {
            "status": "generic", "source": "Enigma General Health Guide",
            "topic": query_topic, "severity": severity,
            "guideline": {
                "title": f"Huong dan chung ve {query_topic}",
                "steps": [
                    "1. Theo doi va ghi lai trieu chung hang ngay trong nhat ky.",
                    "2. Dam bao ngu du 7-8 tieng va an uong dieu do.",
                    "3. Thuc hanh ky thuat tho Box Breathing 4-4-4-4 khi cang thang.",
                    "4. Chia se tinh trang voi nguoi than hoac ban be tin tuong.",
                    "5. Tham khao y kien chuyen gia y te neu trieu chung keo dai.",
                ],
                "hotline": "111" if severity in ["moderate", "severe"] else None
            },
            "disclaimer": "Enigma khong thay the chan doan y khoa chuyen nghiep. Hay lien he bac si hoac Hotline 111."
        }

    @staticmethod
    async def _trigger_crisis_emergency_alert(args: Dict[str, Any], db: Optional[AsyncSession]) -> Dict[str, Any]:
        user_id = args.get("user_id")
        risk_reason = args.get("risk_reason", "")
        risk_level = args.get("risk_level", "RED")
        logger.critical(f"[CRISIS ALERT] User {user_id} | Level: {risk_level} | Reason: {risk_reason}")
        contacts = {
            "RED": {
                "hotlines": ["111 (Tu van Quoc gia)", "115 (Cap cuu Y te)"],
                "message": "CANH BAO KHAN CAP: He thong phat hien nguy co tam ly cao. Lien he ngay duong day ho tro.",
                "actions": ["Goi Hotline Tu van Tam ly: 111", "Lien he Phong Y te truong", "Bao nguoi than biet tinh trang cua ban"]
            },
            "YELLOW": {
                "hotlines": ["111 (Tu van Ho tro)"],
                "message": "Enigma nhan thay ban dang trai qua giai doan kho khan. Chung toi o day cung ban.",
                "actions": ["Thuc hanh Box Breathing 4-4-4-4 trong 5 phut", "Lien he nguoi than", "Goi Hotline 111 neu can"]
            }
        }
        contact_info = contacts.get(risk_level, contacts["YELLOW"])
        return {
            "status": "alert_triggered", "user_id": str(user_id),
            "risk_level": risk_level, "risk_reason": risk_reason,
            "alert_message": contact_info["message"],
            "emergency_contacts": contact_info["hotlines"],
            "recommended_actions": contact_info["actions"],
            "timestamp": str(date.today())
        }

    @staticmethod
    async def _get_daily_life_log_summary(args: Dict[str, Any], db: Optional[AsyncSession]) -> Dict[str, Any]:
        user_id = args.get("user_id")
        if not db or not user_id:
            return {"status": "no_data"}
        try:
            from app.db.models.checkin import DailyCheckin, UserStreak
            from app.db.models.journal import Journal
            today = date.today()
            checkin_res = await db.execute(select(DailyCheckin).where(DailyCheckin.user_id == user_id, DailyCheckin.checkin_date == today))
            checkin = checkin_res.scalar_one_or_none()
            streak_res = await db.execute(select(UserStreak).where(UserStreak.user_id == user_id))
            streak = streak_res.scalar_one_or_none()
            journal_res = await db.execute(select(Journal).where(Journal.user_id == user_id, Journal.journal_date == today))
            journal = journal_res.scalar_one_or_none()
            return {
                "status": "ok", "user_id": str(user_id), "date": str(today),
                "checkin": {
                    "has_checked_in": checkin is not None,
                    "gacha_message": checkin.gacha_message if checkin else None
                },
                "streak": {
                    "current_streak": streak.current_streak if streak else 0,
                    "longest_streak": streak.longest_streak if streak else 0
                },
                "journal_today": {
                    "has_journal": journal is not None,
                    "stress_level": journal.stress_level if journal else None,
                    "sleep_hours": float(journal.sleep_hours) if journal else None,
                    "sentiment": journal.ai_sentiment if journal else None
                }
            }
        except Exception as e:
            return {"status": "error", "message": str(e)}

    @staticmethod
    def format_tool_results_as_context(tool_results: List[Dict[str, Any]]) -> str:
        if not tool_results:
            return ""
        lines = ["========= DU LIEU BO SUNG TU FUNCTION CALLING ========="]
        for i, result in enumerate(tool_results, 1):
            tool_name = result.get("_tool_name", f"Tool {i}")
            lines.append(f"\n[Ket qua Tool {i}: {tool_name}]")
            for k, v in result.items():
                if k.startswith("_"):
                    continue
                if isinstance(v, (dict, list)):
                    lines.append(f"  {k}: {json.dumps(v, ensure_ascii=False)}")
                else:
                    lines.append(f"  {k}: {v}")
        return "\n".join(lines)
