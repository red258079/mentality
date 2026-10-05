import os
import pathlib
import chromadb
from chromadb.config import Settings as ChromaSettings
from typing import List, Dict, Any, Optional

# Path to persistent ChromaDB database on disk
CHROMA_DATA_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "chroma_db")
os.makedirs(CHROMA_DATA_DIR, exist_ok=True)

# Persistent Chroma Client
_chroma_client = chromadb.PersistentClient(
    path=CHROMA_DATA_DIR,
    settings=ChromaSettings(anonymized_telemetry=False)
)
_collection = _chroma_client.get_or_create_collection(
    name="enigma_handbook",
    metadata={"hnsw:space": "cosine"}  # Cosine Similarity Metric
)


def chunk_text(text: str, chunk_size: int = 500, overlap: int = 100) -> List[str]:
    """Sliding Window Chunking with overlap for text processing."""
    if not text:
        return []
    chunks = []
    start = 0
    while start < len(text):
        end = start + chunk_size
        chunk = text[start:end]
        chunks.append(chunk.strip())
        if end >= len(text):
            break
        start += (chunk_size - overlap)
    return [c for c in chunks if c]


class VectorStoreService:
    @staticmethod
    def add_or_update_article(article_id: str, title: str, content: str, category: str):
        """Index an article into ChromaDB HNSW collection."""
        chunks = chunk_text(content, chunk_size=500, overlap=100)
        if not chunks:
            chunks = [title]

        ids = [f"{article_id}_chunk_{i}" for i in range(len(chunks))]
        metadatas = [
            {
                "article_id": str(article_id),
                "title": title,
                "category": category,
                "chunk_index": i,
            }
            for i in range(len(chunks))
        ]

        _collection.upsert(
            ids=ids,
            documents=chunks,
            metadatas=metadatas
        )

    @staticmethod
    def search_similar_chunks(query: str, top_k: int = 3) -> List[Dict[str, Any]]:
        """
        Cosine Similarity HNSW Vector Search in ChromaDB.
        Returns top_k matching document chunks with similarity score and metadata.
        """
        results = _collection.query(
            query_texts=[query],
            n_results=top_k
        )

        output = []
        if results and results.get("documents") and results["documents"][0]:
            docs = results["documents"][0]
            metadatas = results["metadatas"][0] if results.get("metadatas") else []
            distances = results["distances"][0] if results.get("distances") else []

            for i in range(len(docs)):
                dist = distances[i] if i < len(distances) else 0.5
                # In Cosine distance, similarity = 1 - distance
                similarity = max(0.0, 1.0 - dist)
                output.append({
                    "chunk": docs[i],
                    "metadata": metadatas[i] if i < len(metadatas) else {},
                    "similarity": round(similarity, 4),
                })

        return output

    @staticmethod
    def seed_initial_handbook_data():
        """Seed initial handbook articles into ChromaDB only if empty."""
        try:
            if _collection.count() > 0:
                print(f"[OK] ChromaDB da san sang ({_collection.count()} chunks handbook).")
                return
        except Exception as e:
            print(f"[WARN] Kiem tra ChromaDB: {e}")

        seed_articles = [
            {
                "id": "h1-5s-lgd",
                "title": "Quy tắc 5S và An toàn lao động tại nhà máy LG Display",
                "category": "career",
                "content": """Quy tắc 5S bao gồm: Sàng lọc (Seiri), Sắp xếp (Seiton), Sạch sẽ (Seiso), Săn sóc (Seiketsu), Sẵn sàng (Shitsuke).
Tất cả sinh viên thực tập phải tuân thủ nghiêm ngặt đồ bảo hộ (mũ, kính, giày chống tĩnh điện ESD). Khi đứng làm việc ca 12 tiếng, hãy tranh thủ 5 phút nghỉ giữa ca để giãn cơ chân và cổ vai gáy.
Nếu gặp sự cố máy móc hoặc quá tải thao tác, hãy lập tức báo hiệu cho Trưởng ca (Leader) để được hỗ trợ, tuyệt đối không tự ý sửa thiết bị."""
            },
            {
                "id": "h2-sleep-shift",
                "title": "Bí quyết cân bằng nhịp sinh học và giấc ngủ khi đổi ca làm việc",
                "category": "sleep",
                "content": """Đổi ca từ ca ngày (08:00 - 20:00) sang ca đêm (20:00 - 08:00) dễ gây rối loạn nhịp sinh học và kiệt sức.
Mẹo ngủ ngon sau ca đêm:
1. Đeo kính râm khi mệt trở về nhà để giảm tiếp xúc ánh sáng mặt trời làm ức chế Melatonin.
2. Dùng rèm che tối phòng và giữ nhiệt độ phòng từ 22-24 độ C.
3. Không uống cà phê hay nước tăng lực trước khi kết thúc ca làm 4 tiếng.
4. Ngâm chân nước ấm 15 phút trước khi ngủ để thư giãn mạch máu."""
            },
            {
                "id": "h3-stress-relief",
                "title": "Kỹ thuật Hít thở Box Breathing 4-4-4-4 giảm căng thẳng tức thì",
                "category": "mental",
                "content": """Khi cảm thấy hoảng sợ, dồn dập hoặc kiệt sức trong ca thực tập:
Bước 1: Thở hết không khí ra khỏi phổi.
Bước 2: Hít vào chậm rãi qua mũi trong 4 giây.
Bước 3: Giữ nín thở trong 4 giây.
Bước 4: Thở ra nhẹ nhàng qua miệng trong 4 giây.
Bước 5: Nín thở nghỉ trong 4 giây trước khi hít lại.
Lặp lại 4 chu kỳ giúp kích hoạt hệ thần kinh phó giao cảm, hạ nhịp tim và cân bằng tâm trí nhanh chóng."""
            },
            {
                "id": "h4-social-comm",
                "title": "Kỹ năng giao tiếp và chia sẻ khó khăn với quản lý nhóm thực tập",
                "category": "social",
                "content": """Khi gặp áp lực công việc hoặc khó khăn trong môi trường mới, việc giao tiếp cởi mở là chìa khóa thích nghi.
Chủ động trao đổi với Anh/Chị Mentor hoặc Quản lý trực tiếp khi bạn chưa hiểu rõ quy trình thao tác. Tham gia vào nhóm trao đổi sinh viên thực tập để chia sẻ kinh nghiệm thích nghi và hỗ trợ lẫn nhau."""
            },
            {
                "id": "h5-physical-care",
                "title": "Chăm sóc thể chất và bài tập giãn cơ cổ vai gáy ca đứng",
                "category": "physical",
                "content": """Đứng làm việc liên tục dễ gây hội chứng căng cơ cổ vai gáy và đau thắt lưng.
Bài tập giãn cơ 3 phút:
1. Xoay cổ nhẹ nhàng theo chiều kim đồng hồ 5 lần, đổi chiều 5 lần.
2. Nâng hai vai lên cao về phía tai, giữ 3 giây rồi thả lỏng hoàn toàn.
3. Đứng thẳng, hai tay đan sau lưng kéo nhẹ ra sau để mở ngực và thả lỏng bả vai.
Uống đủ 2 lít nước mỗi ngày và bổ sung điện giải khi làm việc trong môi trường điều hòa nhà máy."""
            },
            {
                "id": "h6-esd-shoes-care",
                "title": "Kinh nghiệm giảm đau chân khi mang giày bảo hộ ESD và đứng ca dài",
                "category": "physical",
                "content": """Mang giày bảo hộ công nghiệp/chống tĩnh điện (ESD) đứng máy 8-12 tiếng liên tục là nguyên nhân hàng đầu gây đau nhức gan bàn chân và gót chân.
Kinh nghiệm thực chiến từ cựu sinh viên:
1. Luôn chuẩn bị miếng lót giày êm y tế/silicon có độ đàn hồi cao để giảm áp lực lên lòng bàn chân.
2. Mang theo chai dầu xoa bóp hoặc cao xoa, tự massage lòng bàn chân và bắp chuối 10 phút sau khi tan ca về phòng.
3. Kê cao chân bằng gối khi nằm ngủ để máu huyết lưu thông ngược về tim, giảm sưng phù chân.
4. Tranh thủ các quãng nghỉ giải lao (10-15 phút giữa ca) để nhấc mũi chân và xoay khớp cổ chân."""
            },
            {
                "id": "h7-roommate-conflict",
                "title": "Kỹ năng xử lý bất đồng bạn cùng phòng ký túc xá và đổi phòng trọ",
                "category": "social",
                "content": """Sống tập thể tại ký túc xá nhà máy hoặc phòng trọ ghép khi đi thực tập xa nhà rất dễ phát sinh mâu thuẫn do lệch ca làm việc (người ngủ ca ngày, người làm ca đêm), tiếng ồn và chia sẻ chi phí sinh hoạt.
Kinh nghiệm xử lý từ khóa trước:
1. Thống nhất quy ước phòng ngay từ ngày đầu: Giờ yên tĩnh tuyệt đối, nguyên tắc tắt đèn, đeo tai nghe khi giải trí và phân công dọn dẹp.
2. Sử dụng bịt tai chống ồn và bịt mắt khi ngủ để không bị ảnh hưởng bởi giờ giấc của bạn cùng phòng.
3. Nếu phát sinh xung đột không thể dung hòa, hãy chủ động liên hệ Ban quản lý ký túc xá hoặc Giáo viên phụ trách đoàn thực tập để xin chuyển sang phòng phù hợp ngay từ tuần đầu, tuyệt đối không nên cố chịu đựng 3 tháng gây ức chế tâm lý kéo dài."""
            },
            {
                "id": "h8-rights-allowance",
                "title": "Cẩm nang tìm hiểu hợp đồng, phụ cấp và an toàn lao động thực tập sinh",
                "category": "career",
                "content": """Sinh viên thực tập cần nắm vững quyền lợi và quy tắc an toàn cơ bản trước và trong quá trình thực tập:
1. Quyền lợi: Nắm rõ mức phụ cấp sinh hoạt, tiền hỗ trợ ca đêm, tiền ăn trưa/tối tại nhà ăn công ty và chính sách hỗ trợ xe đưa đón hoặc ký túc xá.
2. Thời gian làm việc và nghỉ phép: Biết chính xác quy trình đăng ký nghỉ phép hoặc xin đổi ca với Trưởng ca (Leader) ít nhất 24 giờ trước ca làm việc.
3. An toàn lao động: Tuyệt đối không chạm tay vào các nút khẩn cấp (Emergency Stop) hoặc khu vực cảnh báo nguy hiểm khi chưa được huấn luyện an toàn; luôn tuân thủ 100% trang phục bảo hộ theo tiêu chuẩn nhà máy."""
            },
            {
                "id": "h9-mindset-career",
                "title": "Tâm thế thích ứng khi làm việc trái ngành và định hướng giá trị bản thân",
                "category": "career",
                "content": """Rất nhiều sinh viên cảm thấy hụt hẫng và sốc khi công việc thực tế tại nhà máy mang tính vận hành dây chuyền, khác xa với lý thuyết chuyên ngành đại học.
Định hướng tâm thế tích cực:
1. Kỳ thực tập là cơ hội vàng để rèn luyện tác phong công nghiệp, kỹ năng chịu áp lực, làm việc nhóm và kỷ luật 5S - những kỹ năng mềm mà mọi doanh nghiệp lớn đều coi trọng.
2. Quan sát quy trình vận hành tổng thể: Dù đứng ở vị trí thao tác, hãy chủ động quan sát cách nhà máy quản lý chất lượng (QA/QC), quản trị chuỗi cung ứng và điều phối nhân sự.
3. Đặt mục tiêu học hỏi cụ thể mỗi tuần thay vì chỉ tập trung vào sự mệt mỏi, biến kỳ thực tập thành điểm tựa vững chắc trong CV sau khi tốt nghiệp."""
            }
        ]

        for item in seed_articles:
            VectorStoreService.add_or_update_article(
                article_id=item["id"],
                title=item["title"],
                content=item["content"],
                category=item["category"]
            )
        print(f"ChromaDB seeded successfully with {len(seed_articles)} handbook articles!")
