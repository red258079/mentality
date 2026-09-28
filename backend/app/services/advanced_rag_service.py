import json
import logging
from typing import List, Dict, Any, Optional
import google.generativeai as genai

from app.core.config import settings
from app.services.vector_store_service import VectorStoreService
from app.services.ai_agent_service import AIAgentService, RiskAssessmentResult
from app.services.function_calling_service import FunctionCallingService

logger = logging.getLogger(__name__)

if settings.GEMINI_API_KEY:
    genai.configure(api_key=settings.GEMINI_API_KEY)


class AdvancedRAGService:
    @staticmethod
    def expand_query(query: str) -> List[str]:
        """
        Pre-Retrieval Strategy 1: Multi-Query Expansion.
        Expands raw student query into 3 semantic variations.
        """
        queries = [query]
        if not settings.GEMINI_API_KEY:
            return queries

        try:
            model = genai.GenerativeModel("gemini-1.5-flash")
            prompt = (
                f"Hãy tạo 2 biến thể câu hỏi khác có cùng ý nghĩa với câu hỏi sau của sinh viên thực tập:\n"
                f"Câu hỏi gốc: '{query}'\n"
                f"Trả về đúng 2 dòng, mỗi dòng 1 câu hỏi biến thể, không kèm số thứ tự."
            )
            res = model.generate_content(prompt)
            lines = [line.strip() for line in res.text.split("\n") if line.strip()]
            queries.extend(lines[:2])
        except Exception:
            pass
        return queries

    @staticmethod
    def generate_hyde_document(query: str) -> str:
        """
        Pre-Retrieval Strategy 2: HyDE (Hypothetical Document Embeddings).
        Generates a hypothetical ideal answer document to embed for vector search.
        """
        if not settings.GEMINI_API_KEY:
            return query

        try:
            model = genai.GenerativeModel("gemini-1.5-flash")
            prompt = (
                f"Viết 1 đoạn văn ngắn (3 câu) giả định là câu trả lời lý tưởng trong cẩm nang cho thắc mắc sau:\n"
                f"'{query}'"
            )
            res = model.generate_content(prompt)
            return res.text.strip()
        except Exception:
            return query

    @staticmethod
    def crag_evaluator_guardrail(query: str, retrieved_chunks: List[Dict[str, Any]]) -> str:
        """
        Self-Correction & CRAG Strategy: Evaluates retrieval quality.
        Returns:
          - 'CORRECT': Strong match (similarity >= 0.75)
          - 'AMBIGUOUS': Moderate match (0.45 <= similarity < 0.75)
          - 'INCORRECT': Weak match (similarity < 0.45)
        """
        if not retrieved_chunks:
            return "INCORRECT"

        top_similarity = retrieved_chunks[0].get("similarity", 0.0)
        if top_similarity >= 0.75:
            return "CORRECT"
        elif top_similarity >= 0.45:
            return "AMBIGUOUS"
        else:
            return "INCORRECT"

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
        """
        Full Advanced RAG Pipeline:
        1. Pre-Retrieval: Query Expansion & HyDE
        2. Multi-Query Retrieval & Deduplication
        3. Post-Retrieval Re-ranking & Context Compression
        4. CRAG Self-Correction Guardrail Evaluation
        5. Gemini LLM Context Fusion Generation & Cited Sources Metadata
        """
        # Step 1: Pre-Retrieval Query Expansion & HyDE
        expanded_queries = AdvancedRAGService.expand_query(query)
        hyde_doc = AdvancedRAGService.generate_hyde_document(query)

        # Step 2: Retrieve Chunks across expanded queries & HyDE doc
        all_chunks = []
        seen_chunk_texts = set()

        search_targets = expanded_queries + [hyde_doc]
        for target in search_targets:
            results = VectorStoreService.search_similar_chunks(target, top_k=top_k)
            for res in results:
                chunk_text = res.get("chunk", "")
                if chunk_text not in seen_chunk_texts:
                    seen_chunk_texts.add(chunk_text)
                    all_chunks.append(res)

        # Step 3: Post-Retrieval Re-ranking by Similarity Score
        all_chunks.sort(key=lambda x: x.get("similarity", 0.0), reverse=True)
        top_chunks = all_chunks[:top_k]

        # Step 4: CRAG Evaluator Guardrail Evaluation
        crag_status = AdvancedRAGService.crag_evaluator_guardrail(query, top_chunks)

        # Build rag_sources metadata
        rag_sources = []
        context_texts = []
        for idx, item in enumerate(top_chunks, 1):
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

        # Step 5: AI Agent Psychological Risk Screening
        risk_result: RiskAssessmentResult = AIAgentService.evaluate_psychological_risk(
            stress_level=stress_level,
            sleep_hours=sleep_hours,
            note_text=query,
            physical_symptoms=recent_symptoms
        )

        # Step 5b: Function Calling — thu thập dữ liệu bổ sung khi CRAG INCORRECT
        function_call_context = ""
        function_calls_made = []

        if enable_function_calling and crag_status in ["INCORRECT", "AMBIGUOUS"]:
            logger.info(f"[AdvancedRAG] CRAG={crag_status}, triggering Function Calling for query: {query[:60]}")

            # Determine which tools to call
            tool_calls_needed = []

            # Always search medical guidelines when RAG fails
            tool_calls_needed.append({
                "tool_name": "search_medical_mental_guidelines",
                "args": {
                    "query_topic": query,
                    "severity": "moderate" if stress_level >= 4 else "mild"
                }
            })

            # Fetch user data if user_id available
            if user_id:
                tool_calls_needed.append({
                    "tool_name": "fetch_student_life_metrics",
                    "args": {"user_id": user_id, "days_limit": 7}
                })

            # Trigger crisis alert if RED risk
            if risk_result.trigger_emergency and user_id:
                tool_calls_needed.append({
                    "tool_name": "trigger_crisis_emergency_alert",
                    "args": {
                        "user_id": user_id,
                        "risk_reason": "; ".join(risk_result.reasons),
                        "risk_level": risk_result.level
                    }
                })

            # Execute tool calls
            tool_results = []
            for tc in tool_calls_needed:
                result_data = await FunctionCallingService.execute_tool(
                    tool_name=tc["tool_name"],
                    tool_args=tc["args"],
                    db=db
                )
                result_data["_tool_name"] = tc["tool_name"]
                tool_results.append(result_data)
                function_calls_made.append(tc["tool_name"])

            function_call_context = FunctionCallingService.format_tool_results_as_context(tool_results)
            logger.info(f"[AdvancedRAG] Function Calling completed: {function_calls_made}")

        context_str = "\n\n".join(context_texts) if context_texts else "Không tìm thấy nội dung cẩm nang phù hợp."

        # Step 6: Construct Advanced RAG Prompt (with Function Calling context)
        function_calling_section = f"\n{function_call_context}" if function_call_context else ""
        system_prompt = f"""Bạn là Enigma Advanced AI - Trợ lý Chăm sóc Tâm lý & Thích nghi Thực tập Nâng cao tại LG Display.
Nhiệm vụ: Trả lời thắc mắc của sinh viên kết hợp tri thức Cẩm nang công ty và hỗ trợ cá nhân hóa.

========= HỒ SƠ SINH VIÊN =========
- Tên sinh viên: {user_name}
- Giai đoạn thực tập: {intern_phase}
- Mức độ stress hiện tại: {stress_level}/5
- Số giờ ngủ ca gần nhất: {sleep_hours}h
- Triệu chứng thể chất: {', '.join(recent_symptoms) if recent_symptoms else 'Không có'}
- Đánh giá Rủi ro Tâm lý: {risk_result.level}
- Đánh giá Độ tin cậy RAG (CRAG Status): {crag_status}

========= DỮ LIỆU CẨM NANG NÂNG CAO (ADVANCED RAG CONTEXT) =========
{context_str}{function_calling_section}

========= QUY TẮC PHẢN HỒI =========
1. Lắng nghe đồng cảm, khích lệ ân cần.
2. Trích dẫn chính xác nhãn [Nguồn X] từ Cẩm nang nếu thông tin có sẵn.
3. Nếu CRAG Status = 'INCORRECT', ưu tiên dùng dữ liệu từ Function Calling để trả lời.
4. Nếu Function Calling có kết quả từ Medical Guidelines, trích dẫn cụ thể các bước.
5. Đưa ra 1-2 lời khuyên hành động ngay (Hít thở Box Breathing 4-4-4-4, ngâm chân, nghỉ ngơi ca làm).
6. Nếu mức rủi ro RED, lập tức đưa ra chỉ dẫn an toàn và Hotline 111 / Y tế 115.
"""

        ai_reply = ""
        if settings.GEMINI_API_KEY:
            try:
                model = genai.GenerativeModel("gemini-1.5-flash")
                response = model.generate_content(f"{system_prompt}\n\nCÂU HỎI SINH VIÊN: {query}")
                ai_reply = response.text
            except Exception:
                ai_reply = AdvancedRAGService._offline_advanced_fallback(query, top_chunks, risk_result, crag_status, user_name)
        else:
            ai_reply = AdvancedRAGService._offline_advanced_fallback(query, top_chunks, risk_result, crag_status, user_name)

        return {
            "content": ai_reply,
            "rag_sources": rag_sources,
            "crag_status": crag_status,
            "expanded_queries": expanded_queries,
            "function_calls_made": function_calls_made,
            "risk_assessment": {
                "level": risk_result.level,
                "reasons": risk_result.reasons,
                "trigger_emergency": risk_result.trigger_emergency,
                "recommended_actions": risk_result.recommended_actions
            }
        }

    @staticmethod
    def _offline_advanced_fallback(
        query: str,
        chunks: List[Dict],
        risk_result: RiskAssessmentResult,
        crag_status: str,
        user_name: str
    ) -> str:
        lines = [f"Chào {user_name}! Enigma Advanced AI hân hạnh hỗ trợ bạn trong kỳ thực tập tại LG Display."]

        if chunks and crag_status != "INCORRECT":
            top_meta = chunks[0].get("metadata", {})
            lines.append(f"\n [Cẩm nang: {top_meta.get('title', 'Thực tập')}]")
            lines.append(chunks[0].get("chunk", ""))
        else:
            lines.append("\n Cẩm nang công ty chưa đề cập chi tiết chủ đề này, nhưng Enigma khuyên bạn nên duy trì chế độ sinh hoạt điều độ, uống đủ nước và trao đổi trực tiếp với Trưởng ca khi cần hỗ trợ.")

        if risk_result.level == "RED":
            lines.append("\n CẢNH BÁO AN TOÀN: Bạn đang có dấu hiệu mệt mỏi tột cùng. Hãy tạm dừng công việc nghỉ ngơi và gọi Hotline 111 / Y tế 115 nhé!")
        elif risk_result.level == "YELLOW":
            lines.append("\n Mẹo phục hồi: Thử tập 3 phút Hít thở Box Breathing 4-4-4-4 để đưa nhịp tim và tâm trí về trạng thái cân bằng.")

        return "\n".join(lines)
