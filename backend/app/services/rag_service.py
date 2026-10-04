import os
from typing import List, Dict, Any, Optional
import google.generativeai as genai

from app.core.config import settings
from app.services.vector_store_service import VectorStoreService
from app.services.ai_agent_service import AIAgentService, RiskAssessmentResult

# Configure Gemini API key if present
if settings.GEMINI_API_KEY:
    genai.configure(api_key=settings.GEMINI_API_KEY)


class RAGService:
    @staticmethod
    async def generate_rag_response(
        query: str,
        user_name: str = "Sinh viên",
        intern_phase: str = "adaptation",
        stress_level: int = 2,
        sleep_hours: float = 7.0,
        recent_symptoms: Optional[List[str]] = None,
        top_k: int = 3
    ) -> Dict[str, Any]:
        """
        Full RAG Engine Pipeline:
        1. Vector Search ChromaDB -> Get top_k relevant handbook chunks
        2. Evaluate Psychological Risk via AI Agent Service
        3. Construct Context Fusion Prompt
        4. Call Google Gemini API (or fallback if API key not set)
        5. Return answer with cited rag_sources metadata & risk evaluation
        """
        # Step 1: Perform Cosine Similarity Vector Search in ChromaDB
        relevant_chunks = VectorStoreService.search_similar_chunks(query, top_k=top_k)

        # Build rag_sources metadata
        rag_sources = []
        context_texts = []
        for idx, item in enumerate(relevant_chunks, 1):
            meta = item.get("metadata", {})
            title = meta.get("title", "Cẩm nang thực tập")
            category = meta.get("category", "general")
            article_id = meta.get("article_id", "h0")
            similarity = item.get("similarity", 0.0)

            context_texts.append(f"[Nguồn {idx}] Tiêu đề: {title}\nNội dung: {item['chunk']}")
            rag_sources.append({
                "article_id": article_id,
                "title": title,
                "category": category,
                "similarity_score": similarity
            })

        # Step 2: AI Agent Psychological Risk Assessment
        risk_result: RiskAssessmentResult = AIAgentService.evaluate_psychological_risk(
            stress_level=stress_level,
            sleep_hours=sleep_hours,
            note_text=query,
            physical_symptoms=recent_symptoms
        )

        context_str = "\n\n".join(context_texts) if context_texts else "Không tìm thấy nội dung cẩm nang khớp chính xác."

        # Step 3: Construct System Prompt
        system_prompt = f"""Bạn là Enigma AI - Trợ lý Chăm sóc Tâm lý & Thích nghi Thực tập cho sinh viên tại LG Display.
Nhiệm vụ: Trả lời câu hỏi của sinh viên dựa trên thông tin Cẩm nang thực tập và tình trạng sức khỏe thực tế.

========= HỒ SƠ SINH VIÊN =========
- Tên sinh viên: {user_name}
- Giai đoạn thực tập: {intern_phase} (preparation: Chuẩn bị / adaptation: Thích nghi / sustain: Duy trì)
- Mức độ stress hiện tại: {stress_level}/5
- Số giờ ngủ ca gần nhất: {sleep_hours}h
- Triệu chứng thể chất: {', '.join(recent_symptoms) if recent_symptoms else 'Không có'}
- Mức độ rủi ro tâm lý AI Agent đánh giá: {risk_result.level}

========= DỮ LIỆU CẨM NANG TRÍCH XUẤT (RAG CHUNKS) =========
{context_str}

========= QUY TẮC TRẢ LỜI =========
1. Thái độ ân cần, đồng cảm, tôn trọng và khích lệ sinh viên.
2. Nếu câu hỏi liên quan tới Cẩm nang, hãy trích dẫn cụ thể theo dạng [Nguồn X].
3. Nếu sinh viên đang có stress cao hoặc thiếu ngủ, đưa ra 1-2 lời khuyên hành động ngay (như hít thở Box Breathing 4-4-4-4 hoặc ngâm chân nước ấm).
4. Nếu rủi ro ở mức RED (Nguy cơ cao), đưa ra lời khuyên bình tĩnh và nhắc nhở sinh viên liên hệ ngay Hotline 111 hoặc Y tế trường.
"""

        # Step 4: Call Gemini API or fallback
        ai_reply = ""
        if settings.GEMINI_API_KEY:
            try:
                model = genai.GenerativeModel("gemini-3.8-flash")
                chat = model.start_chat()
                response = chat.send_message(f"{system_prompt}\n\nCÂU HỎI SINH VIÊN: {query}")
                ai_reply = response.text
            except Exception as e:
                ai_reply = RAGService._fallback_response(query, relevant_chunks, risk_result, user_name)
        else:
            ai_reply = RAGService._fallback_response(query, relevant_chunks, risk_result, user_name)

        return {
            "content": ai_reply,
            "rag_sources": rag_sources,
            "risk_assessment": {
                "level": risk_result.level,
                "reasons": risk_result.reasons,
                "trigger_emergency": risk_result.trigger_emergency,
                "recommended_actions": risk_result.recommended_actions
            }
        }

    @staticmethod
    def _fallback_response(query: str, relevant_chunks: List[Dict], risk_result: RiskAssessmentResult, user_name: str) -> str:
        """Intelligent Offline Fallback Generator when Gemini API key is missing or offline."""
        lines = [f"Chào {user_name}! Enigma AI luôn đồng hành cùng bạn trong kỳ thực tập tại LG Display."]

        if relevant_chunks:
            top_meta = relevant_chunks[0].get("metadata", {})
            lines.append(f"\n Dựa trên Cẩm nang [{top_meta.get('title', 'Thực tập')}]:")
            lines.append(relevant_chunks[0].get("chunk", ""))

        if risk_result.level == "RED":
            lines.append("\n CẢNH BÁO AN TOÀN: Bạn đang trải qua mức độ căng thẳng cao. Hãy nghỉ ngơi ngay và liên hệ Hotline 111 hoặc Y tế 115 nếu cần hỗ trợ nhé!")
        elif risk_result.level == "YELLOW":
            lines.append("\n Mẹo phục hồi nhanh: Hãy thử tập 3 phút Hít thở Box Breathing (Hít 4s - Giữ 4s - Thở 4s - Giữ 4s) để thả lỏng nhịp tim.")

        return "\n".join(lines)
