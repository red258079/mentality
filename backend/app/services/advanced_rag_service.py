import logging
import asyncio
from typing import List, Dict, Any, Optional
import google.generativeai as genai

from app.core.config import settings
from app.services.vector_store_service import VectorStoreService
from app.services.ai_agent_service import AIAgentService, RiskAssessmentResult

logger = logging.getLogger(__name__)

# Danh sách Model Gemini ưu tiên theo độ tin cậy và hạn mức (Failover Cascade)
GEMINI_MODELS = [
    "gemini-3.5-flash-lite",
    "gemini-3.1-flash-lite",
    "gemini-3.5-flash",
    "gemini-3.7-flash",
]


class AdvancedRAGService:
    """
    Kiến trúc RAG Đa tầng (Multi-tier Resilient RAG Architecture):
    1. Intent Routing: Phân loại ý định thông minh (Chào hỏi / Cẩm nang / Nguy cơ).
    2. Hybrid Vector Retrieval: Tìm kiếm ngữ nghĩa ChromaDB có ngưỡng lọc tin cậy.
    3. Multi-Model Cascade: Tự động chuyển đổi mô hình dự phòng khi gặp sự cố hạn ngạch (429/timeout).
    4. Context-Aware Dynamic Fallback: Phản hồi chính xác ngay cả khi ngoại tuyến hoặc mất kết nối API.
    """

    @staticmethod
    def classify_intent(query: str) -> str:
        """Phân loại ý định người dùng để tối ưu hóa luồng xử lý (Intent Routing)."""
        clean_q = query.lower().strip()
        
        # 1. Chào hỏi / Hỏi về Enigma AI
        greetings = ["hello", "hi", "chào", "xin chào", "alo", "helo", "ban la ai", "bạn là ai", "ai vậy", "giới thiệu"]
        if clean_q in greetings or any(clean_q.startswith(g) for g in ["chào", "xin chào", "hello", "hi "]):
            return "GREETING"

        # 2. Cảm ơn / Tạm biệt
        thanks = ["cảm ơn", "cam on", "thank", "thanks", "tạm biệt", "tam biet", "bye", "ok cảm ơn"]
        if any(t in clean_q for t in thanks):
            return "CLOSING"

        # 3. Mặc định là câu hỏi nghiệp vụ / cẩm nang
        return "DOMAIN_QUERY"

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
        ]

        for keywords, expansion in topic_mappings:
            if any(k in clean_q for k in keywords):
                queries.append(expansion)
                break

        return queries

    @staticmethod
    async def generate_advanced_rag_response(
        query: str,
        user_name: str = "Sinh viên",
        intern_phase: str = "adaptation",
        stress_level: int = 2,
        sleep_hours: float = 7.0,
        recent_symptoms: Optional[List[str]] = None,
        top_k: int = 3,
        user_id: Optional[str] = None,
        db=None,
        enable_function_calling: bool = True
    ) -> Dict[str, Any]:
        """Điều phối toàn bộ quy trình RAG hợp lý, logic và không gián đoạn."""
        intent = AdvancedRAGService.classify_intent(query)

        # 1. Đánh giá rủi ro tâm lý
        risk_result: RiskAssessmentResult = AIAgentService.evaluate_psychological_risk(
            stress_level=stress_level,
            sleep_hours=sleep_hours,
            note_text=query,
            physical_symptoms=recent_symptoms
        )

        rag_sources = []
        context_texts = []
        crag_status = "CORRECT"

        # 2. Xử lý theo Intent
        if intent == "DOMAIN_QUERY":
            # Chỉ truy vấn Vector DB khi là câu hỏi cẩm nang nghiệp vụ thực tế
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
            # Ngưỡng lọc tin cậy: Chỉ lấy các đoạn có độ tương đồng >= 0.40
            top_chunks = [c for c in all_chunks if c.get("similarity", 0.0) >= 0.40][:top_k]

            for idx, item in enumerate(top_chunks, 1):
                meta = item.get("metadata", {})
                title = meta.get("title", "Cẩm nang thực tập")
                category = meta.get("category", "general")
                article_id = meta.get("article_id", "h0")
                similarity = item.get("similarity", 0.0)

                context_texts.append(f"[Nguồn {idx}: {title}]\nChủ đề: {category}\nNội dung: {item['chunk']}")
                rag_sources.append({
                    "article_id": article_id,
                    "title": title,
                    "category": category,
                    "similarity_score": similarity
                })
        else:
            expanded_queries = [query]

        context_str = "\n\n".join(context_texts) if context_texts else "Không có trích dẫn cẩm nang cụ thể cho câu hỏi này."

        # 3. Xây dựng System Prompt thích ứng linh hoạt theo từng Intent
        if intent == "GREETING":
            system_prompt = f"""Bạn là Enigma AI — Trợ lý Đồng hành Tâm lý & Sức khỏe Thực tập tại LG Display.
Nhiệm vụ: Chào hỏi bạn {user_name} một cách ấm áp, thân thiện (dùng emoji sinh động), giới thiệu ngắn gọn khả năng hỗ trợ (giải đáp ca kíp, đau mỏi ca đứng, cẩm nang 5S, bài tập thư giãn) và hỏi thăm tình hình hôm nay của bạn ấy."""
        elif intent == "CLOSING":
            system_prompt = f"""Bạn là Enigma AI — Trợ lý Thực tập LG Display.
Nhiệm vụ: Cảm ơn bạn {user_name}, gửi lời chúc bạn có một ca làm việc an toàn, nhiều năng lượng và nhắc bạn luôn có Enigma bên cạnh khi cần hỗ trợ."""
        else:
            system_prompt = f"""Bạn là Enigma AI — Trợ lý Đồng hành Tâm lý, Sức khỏe & Thích nghi Thực tập Doanh nghiệp tại LG Display.

🎯 NGUYÊN TẮC PHẢN HỒI:
1. Thấu cảm & Trả lời TRỰC TIẾP, ĐÚNG TRỌNG TÂM câu hỏi của bạn {user_name}.
2. Nếu có cẩm nang liên quan bên dưới, hãy trích dẫn rõ [Nguồn X: Tên bài viết] và ứng dụng vào câu trả lời.
3. Đưa ra 2-3 lời khuyên hành động thực tế, khoa học và dễ làm theo.
4. Xưng hô thân thiện "mình - bạn" hoặc "Enigma - {user_name}".

👤 THÔNG TIN SINH VIÊN:
- Tên: {user_name} | Chặng: {intern_phase} | Stress: {stress_level}/5 | Ngủ: {sleep_hours}h | Triệu chứng: {', '.join(recent_symptoms) if recent_symptoms else 'Bình thường'}

📚 CẨM NANG LIÊN QUAN (RAG CONTEXT):
{context_str}
"""

        # 4. Multi-Model Cascade Execution (Non-blocking with failover)
        ai_reply = ""
        gemini_success = False

        if settings.GEMINI_API_KEY:
            genai.configure(api_key=settings.GEMINI_API_KEY)
            prompt_text = f"{system_prompt}\n\nCÂU HỎI CỦA SINH VIÊN:\n{query}"

            for model_name in GEMINI_MODELS:
                try:
                    model = genai.GenerativeModel(model_name)
                    # Gọi bất đồng bộ trong thread pool với timeout bảo vệ 6 giây
                    response = await asyncio.wait_for(
                        asyncio.to_thread(model.generate_content, prompt_text),
                        timeout=6.0
                    )
                    if response and response.text and response.text.strip():
                        ai_reply = response.text.strip()
                        gemini_success = True
                        break
                except Exception as e:
                    logger.warning(f"[RAG Failover] Model {model_name} không khả dụng ({e}), chuyển sang model tiếp theo...")

        # 5. Context-Aware Dynamic Fallback nếu không gọi được LLM
        if not gemini_success:
            ai_reply = AdvancedRAGService._generate_dynamic_fallback(query, intent, rag_sources, user_name, risk_result)

        return {
            "content": ai_reply,
            "rag_sources": rag_sources,
            "crag_status": crag_status,
            "expanded_queries": expanded_queries,
            "intent": intent,
            "function_calls_made": [],
            "risk_assessment": {
                "level": risk_result.level,
                "reasons": risk_result.reasons,
                "trigger_emergency": risk_result.trigger_emergency,
                "recommended_actions": risk_result.recommended_actions
            }
        }

    @staticmethod
    def _generate_dynamic_fallback(
        query: str,
        intent: str,
        rag_sources: List[Dict[str, Any]],
        user_name: str,
        risk_result: RiskAssessmentResult
    ) -> str:
        """Sinh câu trả lời thông minh dựa trên ngữ cảnh khi ngoại tuyến."""
        clean_q = query.lower().strip()

        if intent == "GREETING":
            return (
                f"Chào {user_name}! 🤖 Mình là Enigma AI — Trợ lý Đồng hành Tâm lý & Sức khỏe Thực tập tại LG Display.\n\n"
                f"Mình luôn sẵn sàng giải đáp thắc mắc về nhịp ca kíp, an toàn nhà máy 5S, kinh nghiệm ở KTX và hướng dẫn các bài tập phục hồi thể chất sau ca làm.\n\n"
                f"Hôm nay bạn cảm thấy thế nào? Hãy chia sẻ cùng mình nhé! ✨"
            )

        if intent == "CLOSING":
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
                f"1. **Đeo kính râm khi tan ca về**: Hạn chế ánh sáng mặt trời làm ức chế hormone Melatonin.\n"
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
                f"Chào {user_name}! Về thắc mắc của bạn, Cẩm nang thực tập [{top['title']}] có hướng dẫn như sau:\n\n"
                f"💡 Hãy áp dụng các quy chuẩn an toàn và trao đổi với Trưởng ca (Leader) nếu cần hướng dẫn trực tiếp.\n"
                f"Bạn có thể hỏi thêm Enigma về các bài tập thư giãn cơ hoặc chế độ dinh dưỡng ca kíp nhé!"
            )

        return (
            f"Chào {user_name}! Mình đã ghi nhận câu hỏi của bạn. Trong môi trường thực tập tại LG Display, "
            f"hãy giữ tinh thần cởi mở và chủ động hỏi Anh/Chị Mentor hoặc Leader khi gặp trở ngại.\n\n"
            f"Bạn có thể hỏi mình về: *'Kinh nghiệm mang giày ESD'*, *'Cách ngủ ngon ca đêm'*, *'Bài tập Box Breathing'* hoặc *'Quy tắc 5S'*."
        )
