import logging
import asyncio
from datetime import datetime, timezone, timedelta
from typing import List, Dict, Any, Optional
import google.generativeai as genai
import httpx
from sqlalchemy import select, desc
from uuid import UUID

from app.core.config import settings
from app.services.vector_store_service import VectorStoreService
from app.services.ai_agent_service import AIAgentService, RiskAssessmentResult
from app.services.ai_guardrails import (
    route_message,
    detect_crisis,
    wrap_user_message,
    safety_policy_block,
    check_output,
    StreamingOutputGuard,
    build_fixed_crisis_message,
    build_crisis_followup,
    build_ambiguous_checkin,
    build_injection_refusal,
    build_off_topic_refusal,
    classify_query_type,
    wrap_document_chunk,
    validate_citations,
    classify_missing_topic,
    CRISIS_MESSAGE_MARKER,
    NO_INFO_PREFIX,
    SAFE_MEDICAL_FALLBACK,
    STAGE_CRISIS,
    STAGE_INJECTION,
    STAGE_OFF_TOPIC,
    STAGE_LLM,
    TIER_EXPLICIT,
    TIER_AMBIGUOUS,
    INTENT_GREETING,
    INTENT_CLOSING,
    INTENT_DOMAIN,
)

logger = logging.getLogger(__name__)

# Danh sách Model Groq AI LPU siêu tốc
GROQ_MODELS = [
    "openai/gpt-oss-120b",
    "openai/gpt-oss-20b",
]

# Danh sách Model Gemini ưu tiên theo độ tin cậy và hạn mức (Failover Cascade)
GEMINI_MODELS = [
    "gemini-3.5-flash",
    "gemini-3.8-flash",
    "gemini-flash-latest",
]


class AdvancedRAGService:
    """
    Kiến trúc RAG Đa tầng có Bảo vệ An toàn (Safety-Guarded Multi-Tier RAG Architecture):
    1. Crisis Check FIRST: 3 tiers (explicit -> fixed message + admin flag; ambiguous -> gentle checkin; ordinary stress).
    2. Prompt Injection Check: Regex ranh giới từ, loại bỏ bypass/jailbreak, bọc <student_message>.
    3. Scope Policy: Mặc định ALLOW (kể cả áp lực tiền bạc, gia đình, tình cảm); chỉ từ chối coding, giải bài tập hộ, chính trị, đầu tư, giải trí.
    4. RAG Grounding & Fallback: Bám cẩm nang; nếu không có thông tin thì nói rõ "chưa có thông tin trong cẩm nang".
    5. Output Check: Kiểm tra đơn thuốc, liều lượng (mg/viên) và chẩn đoán khẳng định trước khi trả cho sinh viên.
    """

    @staticmethod
    def classify_intent(query: str) -> str:
        """Giữ tương thích ngược với các caller cũ."""
        decision = route_message(query)
        return decision.intent

    @staticmethod
    def expand_query(query: str) -> List[str]:
        """Làm giàu từ khóa ngữ nghĩa tìm kiếm vector (Query Expansion)."""
        queries = [query]
        clean_q = query.lower()

        topic_mappings = [
            (["đau chân", "giày", "esd", "mỏi chân", "gót chân", "bàn chân"], "kinh nghiệm giảm đau chân khi mang giày bảo hộ ESD ca đứng"),
            (["ngủ", "ca đêm", "mất ngủ", "đổi ca", "nhịp sinh học", "uể oải"], "bí quyết cân bằng nhịp sinh học và giấc ngủ khi đổi ca làm việc"),
            (["stress", "thở", "căng thẳng", "áp lực", "lo lắng", "sợ", "hoảng"], "kỹ thuật hít thở Box Breathing 4-4-4-4 giảm căng thẳng tức thì"),
            (["vai gáy", "cổ", "mỏi vai", "đau lưng", "giãn cơ", "đứng lâu"], "chăm sóc thể chất và bài tập giãn cơ cổ vai gáy ca đứng"),
            (["phòng", "ktx", "trọ", "bạn cùng phòng", "ở ghép", "tiếng ồn"], "kỹ năng xử lý bất đồng bạn cùng phòng ký túc xá và đổi phòng trọ"),
            (["5s", "an toàn", "quy tắc", "bảo hộ", "nội quy", "quần áo"], "quy tắc 5S và an toàn lao động tại nhà máy LG Display"),
            (["lương", "phụ cấp", "hợp đồng", "nghỉ phép", "đổi ca", "quyền lợi"], "cẩm nang tìm hiểu hợp đồng, phụ cấp và an toàn lao động thực tập sinh"),
            (["phq", "phq4", "phq-4", "sàng lọc", "tâm thần", "trầm cảm", "lo âu", "gad", "gad-7"], "quy trình sàng lọc sức khỏe tâm thần chuẩn y khoa PHQ-4 và phân tầng can thiệp"),
        ]

        for keywords, expansion in topic_mappings:
            if any(k in clean_q for k in keywords):
                queries.append(expansion)
                break

        return queries

    @staticmethod
    async def _has_recent_crisis_flag(db, user_id: str, hours: int = 6) -> bool:
        """Kiểm tra xem sinh viên đã có cảnh báo khủng hoảng gần đây chưa để tránh duplicate flag."""
        if not db or not user_id:
            return False
        try:
            from app.db.models.crisis_flag import CrisisFlag
            from uuid import UUID as PyUUID

            uid = PyUUID(str(user_id)) if not isinstance(user_id, PyUUID) else user_id
            cutoff = datetime.now(timezone.utc) - timedelta(hours=hours)
            stmt = select(CrisisFlag.id).where(
                CrisisFlag.user_id == uid,
                CrisisFlag.created_at >= cutoff
            ).limit(1)
            res = await db.execute(stmt)
            return res.scalar_one_or_none() is not None
        except Exception as e:
            logger.warning(f"[Guardrails] Không thể kiểm tra crisis_flag gần đây: {e}")
            return False

    @staticmethod
    async def _flag_crisis_for_admin(db, user_id: str, tier: str = TIER_EXPLICIT) -> bool:
        """Ghi nhận cờ cảnh báo khủng hoảng vào database (chỉ metadata, KHÔNG lưu nội dung tin nhắn)."""
        if not db or not user_id:
            return False
        try:
            from app.db.models.crisis_flag import CrisisFlag
            from uuid import UUID as PyUUID

            uid = PyUUID(str(user_id)) if not isinstance(user_id, PyUUID) else user_id
            flag = CrisisFlag(
                user_id=uid,
                tier=tier,
                source="chat",
                status="new"
            )
            db.add(flag)
            await db.flush()
            logger.critical(f"[CRISIS FLAG] Đã ghi nhận cờ khủng hoảng cho user {user_id} (tier={tier})")
            return True
        except Exception as e:
            logger.error(f"[CRISIS FLAG] Không thể lưu crisis_flag: {e}")
            return False

    @staticmethod
    async def _record_missing_topic(db, query: str):
        """Ghi nhận chủ đề cẩm nang còn thiếu vào bảng handbook_missing_topics (chỉ đếm, không lưu tin nhắn, không lưu user_id)."""
        if not db:
            return
        try:
            from datetime import date
            from app.db.models.handbook_missing_topic import HandbookMissingTopic
            from sqlalchemy.dialects.postgresql import insert as pg_insert

            topic = classify_missing_topic(query)
            today = date.today()

            stmt = pg_insert(HandbookMissingTopic).values(
                topic=topic,
                recorded_date=today,
                count=1
            ).on_conflict_do_update(
                constraint='uq_topic_date',
                set_={'count': HandbookMissingTopic.count + 1}
            )
            await db.execute(stmt)
            await db.commit()
            logger.info(f"[Topic Tracking] Da ghi nhan thieu thong tin cho chu de: {topic}")
        except Exception as e:
            logger.warning(f"[Topic Tracking] Khong the ghi nhan missing topic: {e}")

    @staticmethod
    def _evaluate_real_risk(
        stress_level: int = 2,
        recent_symptoms: Optional[List[str]] = None,
        default_reason: str = "Đã đánh giá thông qua luồng an toàn."
    ) -> Dict[str, Any]:
        reasons = []
        level = "GREEN"
        if stress_level >= 4:
            level = "YELLOW"
            reasons.append(f"Mức độ căng thẳng được ghi nhận ở mức cao ({stress_level}/5).")
        if recent_symptoms:
            reasons.append(f"Triệu chứng gần đây: {', '.join(recent_symptoms)}")
            critical_symptoms = ["mất ngủ", "kiệt sức", "hoảng loạn", "đau ngực", "khó thở", "chóng mặt", "ngất xỉu"]
            if any(any(cs in sym.lower() for cs in critical_symptoms) for sym in recent_symptoms):
                level = "YELLOW"
        if not reasons:
            reasons.append(default_reason)

        actions = []
        if level == "YELLOW":
            actions.append("Khuyến khích nghỉ ngơi và trao đổi với Quản lý/Y tế công ty nếu cần.")

        return {
            "level": level,
            "reasons": reasons,
            "trigger_emergency": False,
            "recommended_actions": actions,
        }

    @staticmethod
    async def generate_advanced_rag_response(
        query: str,
        user_name: str = "Sinh viên",
        intern_phase: str = "adaptation",
        stress_level: int = 2,
        sleep_hours: Optional[float] = None,
        recent_symptoms: Optional[List[str]] = None,
        top_k: int = 3,
        user_id: Optional[str] = None,
        db=None,
        enable_function_calling: bool = False
    ) -> Dict[str, Any]:
        """Điều phối toàn bộ quy trình RAG tuân thủ triệt để Guardrails."""

        # ─── BƯỚC 1: ĐIỀU PHỐI TUẦN TỰ (Order: Crisis -> Injection -> Scope) ───
        decision = route_message(query, stress_level=stress_level)

        # ── 1.A: XỬ LÝ KHỦNG HOẢNG (CRISIS PATH - KHÔNG GỌI LLM TỰ DO) ────────
        if decision.stage == STAGE_CRISIS:
            tier = decision.crisis.tier

            if tier == TIER_EXPLICIT:
                # Kiểm tra xem đã có cảnh báo gần đây chưa
                has_recent = await AdvancedRAGService._has_recent_crisis_flag(db, user_id, hours=settings.CRISIS_FLAG_DEDUP_HOURS)
                if not has_recent:
                    await AdvancedRAGService._flag_crisis_for_admin(db, user_id, tier=TIER_EXPLICIT)
                    content = build_fixed_crisis_message()
                else:
                    # Tránh lặp lại nguyên văn tin nhắn dài vô tận
                    content = build_crisis_followup(turn_index=1)

                return {
                    "content": content,
                    "rag_sources": [],
                    "crag_status": "CORRECT",
                    "expanded_queries": [query],
                    "intent": "CRISIS",
                    "function_calls_made": [],
                    "risk_assessment": {
                        "level": "RED",
                        "reasons": list(decision.crisis.signals) or ["Phát hiện tín hiệu khủng hoảng nghiêm trọng."],
                        "trigger_emergency": True,
                        "recommended_actions": [
                            f"Liên hệ ngay Cấp cứu {settings.CRISIS_CONTACT_EMERGENCY} nếu nguy cấp.",
                            f"Liên hệ người phụ trách: {settings.CRISIS_CONTACT_MENTOR}.",
                            "Ở cạnh người thân hoặc bạn bè tin cậy."
                        ]
                    }
                }

            elif tier == TIER_AMBIGUOUS:
                # Nhóm mơ hồ: Đặt câu hỏi trực diện, ân cần; KHÔNG cắm cờ admin
                content = build_ambiguous_checkin(turn_index=0, third_party=decision.crisis.third_party)
                return {
                    "content": content,
                    "rag_sources": [],
                    "crag_status": "CORRECT",
                    "expanded_queries": [query],
                    "intent": "CRISIS_AMBIGUOUS",
                    "function_calls_made": [],
                    "risk_assessment": {
                        "level": "YELLOW",
                        "reasons": list(decision.crisis.signals) or ["Phát hiện trạng thái bế tắc hoặc lo âu cao."],
                        "trigger_emergency": False,
                        "recommended_actions": [
                            "Hỏi thăm an toàn trực tiếp.",
                            "Lắng nghe và khuyến khích chia sẻ thêm."
                        ]
                    }
                }

        # ── 1.B: XỬ LÝ INJECTION / JAILBREAK ──────────────────────────────────
        if decision.stage == STAGE_INJECTION:
            return {
                "content": build_injection_refusal(),
                "rag_sources": [],
                "crag_status": "CORRECT",
                "expanded_queries": [query],
                "intent": "INJECTION_BLOCKED",
                "function_calls_made": [],
                "risk_assessment": {
                    "level": "GREEN",
                    "reasons": ["Yêu cầu vượt quyền hoặc can thiệp hệ thống bị từ chối."],
                    "trigger_emergency": False,
                    "recommended_actions": []
                }
            }

        # ── 1.C: XỬ LÝ NGOÀI PHẠM VI (OFF-TOPIC) ──────────────────────────────
        if decision.stage == STAGE_OFF_TOPIC:
            category = decision.off_topic_category or "general"
            return {
                "content": build_off_topic_refusal(category),
                "rag_sources": [],
                "crag_status": "CORRECT",
                "expanded_queries": [query],
                "intent": "OFF_TOPIC",
                "function_calls_made": [],
                "risk_assessment": {
                    "level": "GREEN",
                    "reasons": [f"Yêu cầu thuộc nhóm ngoài phạm vi: {category}"],
                    "trigger_emergency": False,
                    "recommended_actions": []
                }
            }

        # ─── BƯỚC 2: RAG RETRIEVAL & GROUNDING ────────────────────────────────
        intent = decision.intent
        rag_sources = []
        context_texts = []
        crag_status = "CORRECT"
        query_type = classify_query_type(query)

        if intent == INTENT_DOMAIN:
            expanded_queries = AdvancedRAGService.expand_query(query)
            all_chunks = []
            seen_chunk_texts = set()

            for target in expanded_queries:
                results = VectorStoreService.search_similar_chunks(target, top_k=top_k)
                for res in results:
                    chunk_text = res.get("chunk", "")
                    if chunk_text and chunk_text not in seen_chunk_texts:
                        seen_chunk_texts.add(chunk_text)
                        all_chunks.append(res)

            all_chunks.sort(key=lambda x: x.get("similarity", 0.0), reverse=True)
            top_chunks = [c for c in all_chunks if c.get("similarity", 0.0) >= 0.40][:top_k]

            if not top_chunks:
                crag_status = "NO_INFO"
                # Ghi nhận chủ đề thiếu thông tin
                await AdvancedRAGService._record_missing_topic(db, query)

                # NẾU LÀ CÂU HỎI SỰ THẬT/QUY ĐỊNH (FACTUAL):
                # Tuyệt đối không gọi LLM để tránh bịa số liệu/quy định.
                if query_type == "factual":
                    fixed_no_info = (
                        f"Chào {user_name}! {NO_INFO_PREFIX}\n\n"
                        "Về các quy định, nội quy hoặc chế độ cụ thể này, bạn vui lòng liên hệ trực tiếp "
                        "với Anh/Chị Quản lý ca (Leader/Mentor) hoặc Phòng Nhân sự/Phòng Đào tạo của trường để có thông tin chính xác nhất.\n\n"
                        "Nếu bạn đang gặp khó khăn hoặc lo lắng về ca làm, mình vẫn luôn ở đây để lắng nghe và hỗ trợ bạn nhé!"
                    )
                    return {
                        "content": fixed_no_info,
                        "rag_sources": [],
                        "crag_status": "NO_INFO",
                        "expanded_queries": expanded_queries,
                        "intent": "NO_INFO_FALLBACK",
                        "function_calls_made": [],
                        "risk_assessment": AdvancedRAGService._evaluate_real_risk(
                            stress_level=stress_level,
                            recent_symptoms=recent_symptoms,
                            default_reason="Câu hỏi sự thật nhưng cẩm nang chưa có tài liệu."
                        )
                    }

            for idx, item in enumerate(top_chunks, 1):
                meta = item.get("metadata", {})
                title = meta.get("title", "Cẩm nang thực tập")
                category = meta.get("category", "general")
                article_id = meta.get("article_id", "h0")
                similarity = item.get("similarity", 0.0)

                # Bọc chunk trong thẻ <document> an toàn đã escape closing tags
                doc_block = wrap_document_chunk(
                    chunk_index=idx,
                    title=title,
                    category=category,
                    content=item['chunk']
                )
                context_texts.append(f"[Nguồn {idx}: {title}]\n{doc_block}")
                rag_sources.append({
                    "article_id": article_id,
                    "title": title,
                    "category": category,
                    "similarity_score": similarity
                })
        else:
            expanded_queries = [query]

        context_str = "\n\n".join(context_texts) if context_texts else f"{NO_INFO_PREFIX}"

        # ─── BƯỚC 3: XÂY DỰNG SYSTEM PROMPT VỚI SAFETY POLICY ──────────────────
        safety_block = safety_policy_block()

        if intent == INTENT_GREETING:
            system_prompt = f"""Bạn là Enigma AI — Trợ lý Đồng hành Tâm lý & Sức khỏe Thực tập tại LG Display.
Nhiệm vụ: Chào hỏi bạn {user_name} một cách ấm áp, thân thiện (dùng emoji sinh động), giới thiệu ngắn gọn khả năng hỗ trợ (giải đáp ca kíp, đau mỏi ca đứng, cẩm nang 5S, bài tập thư giãn) và hỏi thăm tình hình hôm nay của bạn ấy.

{safety_block}"""
        elif intent == INTENT_CLOSING:
            system_prompt = f"""Bạn là Enigma AI — Trợ lý Thực tập LG Display.
Nhiệm vụ: Cảm ơn bạn {user_name}, gửi lời chúc bạn có một ca làm việc an toàn, nhiều năng lượng và nhắc bạn luôn có Enigma bên cạnh khi cần hỗ trợ.

{safety_block}"""
        else:
            sleep_info = f"{sleep_hours}h" if sleep_hours is not None else "Chưa có dữ liệu (chưa rõ)"
            if sleep_hours is None:
                sleep_instruction = f"• DỮ LIỆU GIẤC NGỦ: Hiện tại hệ thống CHƯA CÓ dữ liệu giấc ngủ ca gần nhất của bạn {user_name} (chưa rõ). Tuyệt đối KHÔNG tự giả định bạn ấy đã ngủ đủ 7 tiếng. Nếu sinh viên nhắc đến mệt mỏi, uể oải, ca kíp hay sức khỏe, hãy ân cần hỏi thăm xem ca vừa rồi bạn ấy ngủ được khoảng mấy tiếng."
            else:
                sleep_instruction = f"• DỮ LIỆU GIẤC NGỦ: Ca gần nhất bạn {user_name} ngủ {sleep_hours}h. Hãy cân nhắc thông tin này khi tư vấn sức khỏe và phục hồi năng lượng."

            system_prompt = f"""Bạn là Enigma AI — Trợ lý Đồng hành Tâm lý, Sức khỏe & Thích nghi Thực tập Doanh nghiệp tại LG Display.

🎯 NGUYÊN TẮC PHẢN HỒI:
1. Thấu cảm & Trả lời TRỰC TIẾP, ĐÚNG TRỌNG TÂM câu hỏi của bạn {user_name}.
2. Nếu có cẩm nang liên quan bên dưới, hãy trích dẫn rõ [Nguồn X: Tên bài viết] và ứng dụng vào câu trả lời.
3. Đưa ra 2-3 lời khuyên hành động thực tế, khoa học và dễ làm theo.
4. Xưng hô thân thiện "mình - bạn" hoặc "Enigma - {user_name}".
{sleep_instruction}

{safety_block}

👤 THÔNG TIN SINH VIÊN:
- Tên: {user_name} | Chặng: {intern_phase} | Stress: {stress_level}/5 | Ngủ: {sleep_info} | Triệu chứng: {', '.join(recent_symptoms) if recent_symptoms else 'Bình thường'}

📚 CẨM NANG LIÊN QUAN (RAG CONTEXT):
{context_str}
"""

        # Bọc tin nhắn sinh viên trong XML tag để chống injection
        wrapped_user_query = wrap_user_message(query)

        # ─── BƯỚC 4: MULTI-MODEL CASCADE (GROQ -> GEMINI -> FALLBACK) ──────────
        ai_reply = ""
        llm_success = False

        # TẦNG 1: Groq AI LPU
        if settings.GROQ_API_KEY:
            for groq_model in GROQ_MODELS:
                try:
                    async with httpx.AsyncClient(timeout=4.0) as client:
                        resp = await client.post(
                            "https://api.groq.com/openai/v1/chat/completions",
                            headers={
                                "Authorization": f"Bearer {settings.GROQ_API_KEY}",
                                "Content-Type": "application/json"
                            },
                            json={
                                "model": groq_model,
                                "messages": [
                                    {"role": "system", "content": system_prompt},
                                    {"role": "user", "content": wrapped_user_query}
                                ],
                                "temperature": 0.6,
                                "max_tokens": 600,
                            }
                        )
                        if resp.status_code == 200:
                            data = resp.json()
                            content = data["choices"][0]["message"]["content"]
                            if content and content.strip():
                                ai_reply = content.strip()
                                llm_success = True
                                logger.info(f"[Dual-LLM] Đã phản hồi qua Groq ({groq_model})")
                                break
                except Exception as e:
                    logger.warning(f"[Dual-LLM] Groq {groq_model} gặp lỗi ({e}), chuyển model tiếp theo...")

        # TẦNG 2: Google Gemini (Sử dụng system_instruction chính thức)
        if not llm_success and settings.GEMINI_API_KEY:
            genai.configure(api_key=settings.GEMINI_API_KEY)
            for model_name in GEMINI_MODELS:
                try:
                    model = genai.GenerativeModel(
                        model_name=model_name,
                        system_instruction=system_prompt
                    )
                    response = await asyncio.wait_for(
                        asyncio.to_thread(model.generate_content, wrapped_user_query),
                        timeout=5.0
                    )
                    if response and response.text and response.text.strip():
                        ai_reply = response.text.strip()
                        llm_success = True
                        logger.info(f"[Dual-LLM] Đã phản hồi qua Gemini ({model_name})")
                        break
                except Exception as e:
                    logger.warning(f"[Dual-LLM] Gemini {model_name} không khả dụng ({e}), thử model tiếp...")

        # TẦNG 3: Offline Dynamic Fallback
        if not llm_success:
            risk_result = AIAgentService.evaluate_psychological_risk(
                stress_level=stress_level,
                sleep_hours=sleep_hours,
                note_text=query,
                physical_symptoms=recent_symptoms
            )
            ai_reply = AdvancedRAGService._generate_dynamic_fallback(query, intent, rag_sources, user_name, risk_result)

        # ─── BƯỚC 5: OUTPUT CHECK (KIỂM SOÁT ĐƠN THUỐC, CHẨN ĐOÁN & TRÍCH DẪN) ─
        # Kiểm tra và làm sạch trích dẫn giả mạo (fake citations)
        valid_indices = list(range(1, len(rag_sources) + 1))
        validated_reply = validate_citations(ai_reply, valid_indices)

        sanitized_reply, violation = check_output(validated_reply)

        return {
            "content": sanitized_reply,
            "rag_sources": rag_sources,
            "crag_status": crag_status,
            "expanded_queries": expanded_queries,
            "intent": intent,
            "function_calls_made": [],
            "risk_assessment": {
                "level": "YELLOW" if stress_level >= 4 else "GREEN",
                "reasons": ["Đã xử lý thông qua luồng RAG an toàn."],
                "trigger_emergency": False,
                "recommended_actions": []
            }
        }

    @staticmethod
    async def generate_advanced_rag_response_stream(
        query: str,
        user_name: str = "Sinh viên",
        intern_phase: str = "adaptation",
        stress_level: int = 2,
        sleep_hours: Optional[float] = None,
        recent_symptoms: Optional[List[str]] = None,
        top_k: int = 3,
        user_id: Optional[str] = None,
        db: Optional[Any] = None,
    ):
        """
        Stream câu trả lời AI theo Server-Sent Events (SSE).
        Đảm bảo Crisis / Injection / Scope được chặn trước khi stream,
        và sử dụng StreamingOutputGuard (sentence buffering) để phát hiện vi phạm y tế giữa chừng.
        """
        # ── 1. KIỂM TRA BẢO VỆ ĐẦU VÀO ──
        decision = route_message(query, stress_level=stress_level)

        if decision.stage == STAGE_CRISIS:
            tier = decision.crisis.tier
            if tier == TIER_EXPLICIT:
                has_recent = await AdvancedRAGService._has_recent_crisis_flag(db, user_id, hours=settings.CRISIS_FLAG_DEDUP_HOURS)
                if not has_recent:
                    await AdvancedRAGService._flag_crisis_for_admin(db, user_id, tier=TIER_EXPLICIT)
                    content = build_fixed_crisis_message()
                else:
                    content = build_crisis_followup(turn_index=1)

                yield {
                    "type": "metadata",
                    "rag_sources": [],
                    "crag_status": "CORRECT",
                    "risk_assessment": {
                        "level": "RED",
                        "reasons": list(decision.crisis.signals) or ["Phát hiện tín hiệu khủng hoảng."],
                        "trigger_emergency": True,
                        "recommended_actions": [f"Liên hệ Cấp cứu {settings.CRISIS_CONTACT_EMERGENCY}."]
                    }
                }
                for word in content.split(" "):
                    yield {"type": "chunk", "delta": word + " "}
                    await asyncio.sleep(0.015)
                yield {"type": "done", "full_content": content}
                return

            elif tier == TIER_AMBIGUOUS:
                content = build_ambiguous_checkin(turn_index=0, third_party=decision.crisis.third_party)
                yield {
                    "type": "metadata",
                    "rag_sources": [],
                    "crag_status": "CORRECT",
                    "risk_assessment": {
                        "level": "YELLOW",
                        "reasons": list(decision.crisis.signals),
                        "trigger_emergency": False,
                        "recommended_actions": []
                    }
                }
                for word in content.split(" "):
                    yield {"type": "chunk", "delta": word + " "}
                    await asyncio.sleep(0.015)
                yield {"type": "done", "full_content": content}
                return

        if decision.stage == STAGE_INJECTION:
            content = build_injection_refusal()
            yield {
                "type": "metadata",
                "rag_sources": [],
                "crag_status": "CORRECT",
                "risk_assessment": {"level": "GREEN", "reasons": ["Bảo vệ injection."], "trigger_emergency": False, "recommended_actions": []}
            }
            yield {"type": "chunk", "delta": content}
            yield {"type": "done", "full_content": content}
            return

        if decision.stage == STAGE_OFF_TOPIC:
            category = decision.off_topic_category or "general"
            content = build_off_topic_refusal(category)
            yield {
                "type": "metadata",
                "rag_sources": [],
                "crag_status": "CORRECT",
                "risk_assessment": {"level": "GREEN", "reasons": [f"Ngoài phạm vi: {category}"], "trigger_emergency": False, "recommended_actions": []}
            }
            yield {"type": "chunk", "delta": content}
            yield {"type": "done", "full_content": content}
            return

        # ── 2. RAG RETRIEVAL & GROUNDING ──
        intent = decision.intent
        rag_sources = []
        context_texts = []
        crag_status = "CORRECT"
        query_type = classify_query_type(query)

        if intent == INTENT_DOMAIN:
            expanded_queries = AdvancedRAGService.expand_query(query)
            all_chunks = []
            seen_chunk_texts = set()

            for target in expanded_queries:
                results = VectorStoreService.search_similar_chunks(target, top_k=top_k)
                for res in results:
                    chunk_text = res.get("chunk", "")
                    if chunk_text and chunk_text not in seen_chunk_texts:
                        seen_chunk_texts.add(chunk_text)
                        all_chunks.append(res)

            all_chunks.sort(key=lambda x: x.get("similarity", 0.0), reverse=True)
            top_chunks = [c for c in all_chunks if c.get("similarity", 0.0) >= 0.40][:top_k]

            if not top_chunks:
                crag_status = "NO_INFO"
                await AdvancedRAGService._record_missing_topic(db, query)

                if query_type == "factual":
                    fixed_no_info = (
                        f"Chào {user_name}! {NO_INFO_PREFIX}\n\n"
                        "Về các quy định, nội quy hoặc chế độ cụ thể này, bạn vui lòng liên hệ trực tiếp "
                        "với Anh/Chị Quản lý ca (Leader/Mentor) hoặc Phòng Nhân sự/Phòng Đào tạo của trường để có thông tin chính xác nhất.\n\n"
                        "Nếu bạn đang gặp khó khăn hoặc lo lắng về ca làm, mình vẫn luôn ở đây để lắng nghe và hỗ trợ bạn nhé!"
                    )
                    yield {
                        "type": "metadata",
                        "rag_sources": [],
                        "crag_status": "NO_INFO",
                        "risk_assessment": AdvancedRAGService._evaluate_real_risk(
                            stress_level=stress_level,
                            recent_symptoms=recent_symptoms,
                            default_reason="Câu hỏi sự thật nhưng cẩm nang chưa có tài liệu."
                        )
                    }
                    for word in fixed_no_info.split(" "):
                        yield {"type": "chunk", "delta": word + " "}
                        await asyncio.sleep(0.015)
                    yield {"type": "done", "full_content": fixed_no_info}
                    return

            for idx, item in enumerate(top_chunks, 1):
                meta = item.get("metadata", {})
                title = meta.get("title", "Cẩm nang thực tập")
                category = meta.get("category", "general")
                article_id = meta.get("article_id", "h0")
                similarity = item.get("similarity", 0.0)

                doc_block = wrap_document_chunk(
                    chunk_index=idx,
                    title=title,
                    category=category,
                    content=item['chunk']
                )
                context_texts.append(f"[Nguồn {idx}: {title}]\n{doc_block}")
                rag_sources.append({
                    "article_id": article_id,
                    "title": title,
                    "category": category,
                    "similarity_score": similarity
                })

        context_str = "\n\n".join(context_texts) if context_texts else f"{NO_INFO_PREFIX}"
        safety_block = safety_policy_block()

        if intent == INTENT_GREETING:
            system_prompt = f"""Bạn là Enigma AI — Trợ lý Đồng hành Tâm lý & Sức khỏe Thực tập tại LG Display.
Nhiệm vụ: Chào hỏi bạn {user_name} ấm áp, giới thiệu hỗ trợ.
{safety_block}"""
        elif intent == INTENT_CLOSING:
            system_prompt = f"""Bạn là Enigma AI — Trợ lý Thực tập LG Display.
Nhiệm vụ: Cảm ơn bạn {user_name}, chúc ca làm an toàn.
{safety_block}"""
        else:
            sleep_info = f"{sleep_hours}h" if sleep_hours is not None else "Chưa có dữ liệu (chưa rõ)"
            system_prompt = f"""Bạn là Enigma AI — Trợ lý Đồng hành Tâm lý, Sức khỏe & Thích nghi Thực tập Doanh nghiệp tại LG Display.

🎯 NGUYÊN TẮC:
1. Thấu cảm & Trả lời trực tiếp đúng trọng tâm câu hỏi của {user_name}.
2. Nếu có cẩm nang, trích dẫn rõ [Nguồn X: Tên bài viết].
3. Đưa ra 2-3 lời khuyên hành động thực tế.

{safety_block}

👤 THÔNG TIN SINH VIÊN:
- Tên: {user_name} | Chặng: {intern_phase} | Stress: {stress_level}/5 | Ngủ: {sleep_info}

📚 CẨM NANG LIÊN QUAN:
{context_str}
"""

        wrapped_user_query = wrap_user_message(query)

        yield {
            "type": "metadata",
            "rag_sources": rag_sources,
            "crag_status": crag_status,
            "risk_assessment": {
                "level": "YELLOW" if stress_level >= 4 else "GREEN",
                "reasons": ["Đang sinh nội dung qua bộ đệm an toàn."],
                "trigger_emergency": False,
                "recommended_actions": []
            }
        }

        guard = StreamingOutputGuard()
        full_text = ""
        llm_stream_success = False

        # --- STREAM TẦNG 1: Groq ---
        if settings.GROQ_API_KEY:
            for groq_model in GROQ_MODELS:
                try:
                    async with httpx.AsyncClient(timeout=15.0) as client:
                        async with client.stream(
                            "POST",
                            "https://api.groq.com/openai/v1/chat/completions",
                            headers={
                                "Authorization": f"Bearer {settings.GROQ_API_KEY}",
                                "Content-Type": "application/json"
                            },
                            json={
                                "model": groq_model,
                                "messages": [
                                    {"role": "system", "content": system_prompt},
                                    {"role": "user", "content": wrapped_user_query}
                                ],
                                "temperature": 0.6,
                                "max_tokens": 600,
                                "stream": True
                            }
                        ) as response:
                            if response.status_code == 200:
                                import json as json_lib
                                async for line in response.aiter_lines():
                                    line_str = line.strip()
                                    if line_str.startswith("data: ") and line_str != "data: [DONE]":
                                        chunk_json = json_lib.loads(line_str[6:])
                                        delta_text = chunk_json["choices"][0]["delta"].get("content", "")
                                        if delta_text:
                                            released_sentences = guard.feed(delta_text)
                                            for s in released_sentences:
                                                full_text += s
                                                yield {"type": "chunk", "delta": s}
                                            if guard.blocked:
                                                break
                                for s in guard.flush():
                                    full_text += s
                                    yield {"type": "chunk", "delta": s}

                                if full_text.strip():
                                    llm_stream_success = True
                                    break
                except Exception as e:
                    logger.warning(f"[Dual-LLM Stream] Groq {groq_model} lỗi ({e}), chuyển model tiếp...")

        # --- STREAM TẦNG 2: Gemini ---
        if not llm_stream_success and settings.GEMINI_API_KEY:
            genai.configure(api_key=settings.GEMINI_API_KEY)
            for model_name in GEMINI_MODELS:
                try:
                    model = genai.GenerativeModel(
                        model_name=model_name,
                        system_instruction=system_prompt
                    )
                    response = await asyncio.to_thread(model.generate_content, wrapped_user_query, stream=True)
                    for chunk in response:
                        if chunk.text:
                            released_sentences = guard.feed(chunk.text)
                            for s in released_sentences:
                                full_text += s
                                yield {"type": "chunk", "delta": s}
                            if guard.blocked:
                                break
                    for s in guard.flush():
                        full_text += s
                        yield {"type": "chunk", "delta": s}

                    if full_text.strip():
                        llm_stream_success = True
                        break
                except Exception as e:
                    logger.warning(f"[Dual-LLM Stream] Gemini {model_name} không khả dụng ({e})...")

        # --- TẦNG 3: Offline Fallback ---
        if not llm_stream_success:
            risk_result = AIAgentService.evaluate_psychological_risk(
                stress_level=stress_level,
                sleep_hours=sleep_hours,
                note_text=query,
                physical_symptoms=recent_symptoms
            )
            fallback = AdvancedRAGService._generate_dynamic_fallback(query, intent, rag_sources, user_name, risk_result)
            sanitized_fallback, _ = check_output(fallback)
            full_text = sanitized_fallback
            words = sanitized_fallback.split(" ")
            chunk_size = 3
            for i in range(0, len(words), chunk_size):
                sub = " ".join(words[i:i+chunk_size]) + " "
                yield {"type": "chunk", "delta": sub}
                await asyncio.sleep(0.02)

        valid_indices = list(range(1, len(rag_sources) + 1))
        final_validated_content = validate_citations(full_text.strip(), valid_indices)

        yield {
            "type": "done",
            "full_content": final_validated_content
        }

    @staticmethod
    def _generate_dynamic_fallback(
        query: str,
        intent: str,
        rag_sources: List[Dict[str, Any]],
        user_name: str,
        risk_result: RiskAssessmentResult
    ) -> str:
        """Sinh câu trả lời thông minh an toàn khi ngoại tuyến."""
        clean_q = query.lower().strip()

        if intent == INTENT_GREETING:
            return (
                f"Chào {user_name}! 🤖 Mình là Enigma AI — Trợ lý Đồng hành Tâm lý & Sức khỏe Thực tập tại LG Display.\n\n"
                f"Mình luôn sẵn sàng giải đáp thắc mắc về nhịp ca kíp, an toàn nhà máy 5S, kinh nghiệm ở KTX và hướng dẫn các bài tập phục hồi thể chất sau ca làm.\n\n"
                f"Hôm nay bạn cảm thấy thế nào? Hãy chia sẻ cùng mình nhé! ✨"
            )

        if intent == INTENT_CLOSING:
            return f"Không có gì đâu nè {user_name}! 😊 Chúc bạn có một ngày thực tập thật nhiều năng lượng và an toàn. Bất cứ khi nào cần chia sẻ hay hỗ trợ, hãy nhắn cho Enigma nhé!"

        if any(w in clean_q for w in ["đau chân", "giày", "esd", "mỏi chân", "gót chân"]):
            return (
                f"Chào {user_name}! Đau chân khi mang giày bảo hộ ESD đứng máy 8-12 tiếng là vấn đề rất phổ biến ở giai đoạn đầu.\n\n"
                f"💡 **Giải pháp phục hồi nhanh:**\n"
                f"1. **Miếng lót silicon y tế**: Sử dụng thêm lót giày có đệm gót dày để phân tán trọng lực.\n"
                f"2. **Ngâm chân nước ấm 15 phút**: Sau ca về phòng, ngâm chân nước ấm giúp giãn mao mạch và giảm nhức mỏi.\n"
                f"3. **Kê cao chân khi ngủ**: Đặt gối dưới bắp chân giúp máu lưu thông về tim, hạn chế sưng phù.\n"
                f"4. **Vận động tại chỗ**: Tranh thủ các quãng nghỉ 5 phút xoay khớp cổ chân và nhón gót."
            )

        if any(w in clean_q for w in ["ngủ", "ca đêm", "mất ngủ", "đổi ca", "nhịp sinh học"]):
            return (
                f"Chào {user_name}! Đổi ca làm việc từ ca ngày sang ca đêm dễ gây rối loạn nhịp sinh học.\n\n"
                f"💡 **Bí quyết ngủ ngon sau ca đêm:**\n"
                f"1. **Đeo kính râm khi tan ca về**: Hạn chế ánh sáng mặt trời làm ức chế hormone Melatonin tự nhiên.\n"
                f"2. **Phòng ngủ tối & mát (22-24°C)**: Kéo rèm kín và dùng bịt mắt chống ồn.\n"
                f"3. **Tránh caffeine trước khi hết ca 4 tiếng**: Không uống cà phê/bò húc sát giờ về phòng.\n"
                f"4. **Tắt màn hình 30 phút trước khi ngủ**: Giúp não bộ thả lỏng và dễ đi vào giấc ngủ sâu."
            )

        if any(w in clean_q for w in ["stress", "thở", "căng thẳng", "áp lực", "lo lắng"]):
            return (
                f"Chào {user_name}! Cảm giác căng thẳng khi đứng chuyền hay làm quen việc mới là điều bình thường.\n\n"
                f"🫁 **Thực hành Hít thở Box Breathing 4-4-4-4 (Hạ stress trong 3 phút):**\n"
                f"- **Bước 1**: Hít vào chậm rãi qua mũi trong **4 giây**.\n"
                f"- **Bước 2**: Giữ nín thở trong **4 giây**.\n"
                f"- **Bước 3**: Thở ra từ từ qua miệng trong **4 giây**.\n"
                f"- **Bước 4**: Nín thở nghỉ trong **4 giây** trước khi lặp lại chu kỳ tiếp theo."
            )

        # Nếu có nguồn cẩm nang được tìm thấy
        if rag_sources:
            top = rag_sources[0]
            return (
                f"Chào {user_name}! Về thắc mắc của bạn, Cẩm nang thực tập [{top['title']}] có hướng dẫn liên quan.\n\n"
                f"💡 Hãy áp dụng các quy chuẩn an toàn và trao đổi với Trưởng ca (Leader) nếu cần hướng dẫn trực tiếp.\n"
                f"Bạn có thể hỏi thêm Enigma về các bài tập thư giãn cơ hoặc chế độ sinh hoạt ca kíp nhé!"
            )

        return (
            f"Chào {user_name}! Mình đã ghi nhận câu hỏi của bạn. Trong môi trường thực tập tại LG Display, "
            f"hãy giữ tinh thần cởi mở và chủ động hỏi Anh/Chị Mentor hoặc Leader khi gặp trở ngại.\n\n"
            f"Bạn có thể hỏi mình về: *'Kinh nghiệm mang giày ESD'*, *'Cách ngủ ngon ca đêm'*, *'Bài tập Box Breathing'* hoặc *'Quy tắc 5S'*."
        )
