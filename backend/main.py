import asyncio
from contextlib import asynccontextmanager
from fastapi import FastAPI, Depends
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes import auth, users, checkins, journals, tasks, chat, handbook, admin, life_logs, notifications, workplace, catalog, crisis_flags
from app.api.routes.admin import get_authed_admin
from app.db.database import create_tables
from app.core.config import settings


@asynccontextmanager
async def lifespan(app: FastAPI):
    try:
        await create_tables()
    except Exception as e:
        print(f"[WARN] Khong the ket noi database luc khoi dong: {e}")

    try:
        from app.services.vector_store_service import VectorStoreService
        VectorStoreService.seed_initial_handbook_data()
    except Exception as e:
        print(f"[WARN] Khoi tao vector store: {e}")
    
    # Nạp dữ liệu cẩm nang mẫu vào PostgreSQL nếu bảng còn trống
    try:
        from app.db.database import AsyncSessionLocal
        from sqlalchemy import select, func
        from app.db.models.handbook_article import HandbookArticle, ArticleStatus
        
        async with AsyncSessionLocal() as session:
            res = await session.execute(select(func.count(HandbookArticle.id)))
            count = res.scalar()
            if count == 0:
                seed_data = [
                    ("Quy tắc 5S và An toàn lao động tại nhà máy LG Display", "career", "Hướng dẫn 5S và bảo hộ lao động ESD ca đứng 12 tiếng.", """Quy tắc 5S bao gồm: Sàng lọc (Seiri), Sắp xếp (Seiton), Sạch sẽ (Seiso), Săn sóc (Seiketsu), Sẵn sàng (Shitsuke).\nTất cả sinh viên thực tập phải tuân thủ nghiêm ngặt đồ bảo hộ (mũ, kính, giày chống tĩnh điện ESD). Khi đứng làm việc ca 12 tiếng, hãy tranh thủ 5 phút nghỉ giữa ca để giãn cơ chân và cổ vai gáy.\nNếu gặp sự cố máy móc hoặc quá tải thao tác, hãy lập tức báo hiệu cho Trưởng ca (Leader) để được hỗ trợ, tuyệt đối không tự ý sửa thiết bị.""", ["5s", "an-toan", "lg-display"]),
                    ("Bí quyết cân bằng nhịp sinh học và giấc ngủ khi đổi ca làm việc", "sleep", "Kinh nghiệm ngủ sâu sau ca đêm và thích nghi nhịp ca kíp.", """Đổi ca từ ca ngày (08:00 - 20:00) sang ca đêm (20:00 - 08:00) dễ gây rối loạn nhịp sinh học và kiệt sức.\nMẹo ngủ ngon sau ca đêm:\n1. Đeo kính râm khi mệt trở về nhà để giảm tiếp xúc ánh sáng mặt trời làm ức chế Melatonin.\n2. Dùng rèm che tối phòng và giữ nhiệt độ phòng từ 22-24 độ C.\n3. Không uống cà phê hay nước tăng lực trước khi kết thúc ca làm 4 tiếng.\n4. Ngâm chân nước ấm 15 phút trước khi ngủ để thư giãn mạch máu.""", ["giac-ngu", "ca-dem", "phuc-hoi"]),
                    ("Kỹ thuật Hít thở Box Breathing 4-4-4-4 giảm căng thẳng tức thì", "mental", "Hạ nhịp tim và cân bằng tâm trí nhanh chóng trong 3 phút.", """Khi cảm thấy hoảng sợ, dồn dập hoặc kiệt sức trong ca thực tập:\nBước 1: Thở hết không khí ra khỏi phổi.\nBước 2: Hít vào chậm rãi qua mũi trong 4 giây.\nBước 3: Giữ nín thở trong 4 giây.\nBước 4: Thở ra nhẹ nhàng qua miệng trong 4 giây.\nBước 5: Nín thở nghỉ trong 4 giây trước khi hít lại.\nLặp lại 4 chu kỳ giúp kích hoạt hệ thần kinh phó giao cảm, hạ nhịp tim và cân bằng tâm trí nhanh chóng.""", ["hit-tho", "box-breathing", "giam-stress"]),
                    ("Chăm sóc thể chất và bài tập giãn cơ cổ vai gáy ca đứng", "physical", "Bài tập 3 phút giãn cơ chống đau mỏi lưng và vai gáy.", """Đứng làm việc liên tục dễ gây hội chứng căng cơ cổ vai gáy và đau thắt lưng.\nBài tập giãn cơ 3 phút:\n1. Xoay cổ nhẹ nhàng theo chiều kim đồng hồ 5 lần, đổi chiều 5 lần.\n2. Nâng hai vai lên cao về phía tai, giữ 3 giây rồi thả lỏng hoàn toàn.\n3. Đứng thẳng, hai tay đan sau lưng kéo nhẹ ra sau để mở ngực và thả lỏng bả vai.\nUống đủ 2 lít nước mỗi ngày và bổ sung điện giải khi làm việc trong môi trường điều hòa nhà máy.""", ["gian-co", "the-chat", "vai-gay"]),
                    ("Kinh nghiệm giảm đau chân khi mang giày bảo hộ ESD và đứng ca dài", "physical", "Bí quyết từ cựu sinh viên: lót giày y tế, massage và ngâm chân.", """Mang giày bảo hộ công nghiệp/chống tĩnh điện (ESD) đứng máy 8-12 tiếng liên tục là nguyên nhân hàng đầu gây đau nhức gan bàn chân và gót chân.\nKinh nghiệm thực chiến từ cựu sinh viên:\n1. Luôn chuẩn bị miếng lót giày êm y tế/silicon có độ đàn hồi cao để giảm áp lực lên lòng bàn chân.\n2. Mang theo chai dầu xoa bóp hoặc cao xoa, tự massage lòng bàn chân và bắp chuối 10 phút sau khi tan ca về phòng.\n3. Kê cao chân bằng gối khi nằm ngủ để máu huyết lưu thông ngược về tim, giảm sưng phù chân.\n4. Tranh thủ các quãng nghỉ giải lao (10-15 phút giữa ca) để nhấc mũi chân và xoay khớp cổ chân.""", ["giay-esd", "dau-chan", "kinh-nghiem"]),
                    ("Kỹ năng xử lý bất đồng bạn cùng phòng ký túc xá và đổi phòng trọ", "social", "Quy ước sinh hoạt chung và giải quyết xung đột lệch ca.", """Sống tập thể tại ký túc xá nhà máy hoặc phòng trọ ghép khi đi thực tập xa nhà rất dễ phát sinh mâu thuẫn do lệch ca làm việc (người ngủ ca ngày, người làm ca đêm), tiếng ồn và chia sẻ chi phí sinh hoạt.\nKinh nghiệm xử lý từ khóa trước:\n1. Thống nhất quy ước phòng ngay từ ngày đầu: Giờ yên tĩnh tuyệt đối, nguyên tắc tắt đèn, đeo tai nghe khi giải trí và phân công dọn dẹp.\n2. Sử dụng bịt tai chống ồn và bịt mắt khi ngủ để không bị ảnh hưởng bởi giờ giấc của bạn cùng phòng.\n3. Nếu phát sinh xung đột không thể dung hòa, hãy chủ động liên hệ Ban quản lý ký túc xá hoặc Giáo viên phụ trách đoàn thực tập để xin chuyển sang phòng phù hợp ngay từ tuần đầu.""", ["ktx", "phong-tro", "giao-tiep"]),
                    ("Cẩm nang tìm hiểu hợp đồng, phụ cấp và an toàn lao động thực tập sinh", "career", "Quyền lợi phụ cấp, xe đưa đón và quy trình xin đổi ca.", """Sinh viên thực tập cần nắm vững quyền lợi và quy tắc an toàn cơ bản trước và trong quá trình thực tập:\n1. Quyền lợi: Nắm rõ mức phụ cấp sinh hoạt, tiền hỗ trợ ca đêm, tiền ăn trưa/tối tại nhà ăn công ty và chính sách hỗ trợ xe đưa đón hoặc ký túc xá.\n2. Thời gian làm việc và nghỉ phép: Biết chính xác quy trình đăng ký nghỉ phép hoặc xin đổi ca với Trưởng ca (Leader) ít nhất 24 giờ trước ca làm việc.\n3. An toàn lao động: Tuyệt đối không chạm tay vào các nút khẩn cấp (Emergency Stop) khi chưa được huấn luyện.""", ["quyen-loi", "phu-cap", "hop-dong"])
                ]
                for title, cat, summ, content, tags in seed_data:
                    art = HandbookArticle(
                        title=title,
                        category=cat,
                        summary=summ,
                        content=content,
                        tags=tags,
                        author_name="Ban Cố vấn Thực tập",
                        status=ArticleStatus.published,
                        helpful_count=5,
                        view_count=18
                    )
                    session.add(art)
                await session.commit()
                print("[OK] Da nap thanh cong du lieu Cam nang thuc tap vao PostgreSQL!")
    except Exception as e:
        print(f"[WARN] Seed handbook postgres: {e}")
        
    # Re-index toàn bộ bài viết cẩm nang đã xuất bản từ PostgreSQL vào ChromaDB dưới dạng background task
    # (Chạy bất đồng bộ trong background sau khi khởi động, KHÔNG làm block lifespan trước yield)
    async def _background_reindex_handbook():
        try:
            from app.services.vector_store_service import VectorStoreService
            from app.db.database import AsyncSessionLocal
            async with AsyncSessionLocal() as session:
                count = await VectorStoreService.sync_all_published_articles_from_db(session)
                print(f"[OK] [Background] Da dong bo va re-index {count} bai viet published tu PostgreSQL vao ChromaDB!")
        except Exception as e:
            print(f"[WARN] [Background] Dong bo handbook vao ChromaDB: {e}")

    reindex_task = asyncio.create_task(_background_reindex_handbook())

    # Chạy dọn dẹp các tin nhắn chat cũ quá hạn lưu trữ khi khởi động hệ thống
    try:
        from app.db.database import AsyncSessionLocal
        from app.services.chat_service import ChatService
        async with AsyncSessionLocal() as session:
            cleaned = await ChatService.cleanup_expired_chat_history(session)
            if cleaned > 0:
                print(f"[RETENTION] Da don dep {cleaned} tin nhan chat het han luu tru.")
    except Exception as e:
        print(f"[WARN] Don dep chat history luc khoi dong: {e}")

    # Scheduled background task định kỳ dọn dẹp chat history (chạy mỗi 24 giờ)
    async def _periodic_retention_cleanup():
        while True:
            try:
                await asyncio.sleep(86400)
                from app.db.database import AsyncSessionLocal
                from app.services.chat_service import ChatService
                async with AsyncSessionLocal() as session:
                    c = await ChatService.cleanup_expired_chat_history(session)
                    if c > 0:
                        print(f"[RETENTION] Dinh ky da don dep {c} tin nhan chat het han.")
            except asyncio.CancelledError:
                break
            except Exception as e:
                print(f"[WARN] Dinh ky don dep chat history: {e}")

    cleanup_task = asyncio.create_task(_periodic_retention_cleanup())

    try:
        yield
    finally:
        cleanup_task.cancel()
        reindex_task.cancel()
        for t in (cleanup_task, reindex_task):
            try:
                await t
            except asyncio.CancelledError:
                pass


app = FastAPI(
    title="Enigma API",
    description="Student Mental Health Support System API",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router,      prefix="/auth",      tags=["Auth"])
app.include_router(users.router,     prefix="/users",     tags=["Users"])
app.include_router(checkins.router,  prefix="/checkins",  tags=["Check-ins"])
app.include_router(journals.router,  prefix="/journals",  tags=["Journals"])
app.include_router(life_logs.router, prefix="/life-logs", tags=["Life Logs"])
app.include_router(tasks.router,     prefix="/tasks",     tags=["Tasks"])
app.include_router(chat.router,          prefix="/chat",          tags=["AI Chat"])
app.include_router(handbook.router,      prefix="/handbook",      tags=["Handbook"])
app.include_router(notifications.router, prefix="/notifications", tags=["Notifications"])
app.include_router(workplace.router,     prefix="/workplace",     tags=["Workplace & Geofence"])
app.include_router(catalog.router,       prefix="/catalog",       tags=["Catalog"])
app.include_router(admin.router,         prefix="/admin",         tags=["Admin"], dependencies=[Depends(get_authed_admin)])
app.include_router(crisis_flags.router,  prefix="/admin",         tags=["Crisis Flags"], dependencies=[Depends(get_authed_admin)])

# Root-level convenience alias for user profile catalog update
from app.schemas.catalog import ProfileCatalogUpdateResponse
app.add_api_route(
    "/me/profile",
    users.update_my_catalog_profile,
    methods=["PUT"],
    response_model=ProfileCatalogUpdateResponse,
    tags=["Users"],
    summary="Cập nhật trường học và công ty thực tập theo Catalog (alias)",
)


@app.get("/", tags=["Health"])
async def root():
    return {"status": "ok", "message": "Enigma API is running"}



# Mount Admin Web Portal nếu thư mục tồn tại
import os
from fastapi.staticfiles import StaticFiles

admin_web_dir = os.path.join(os.path.dirname(__file__), "admin_web")
if os.path.exists(admin_web_dir):
    app.mount("/admin-web", StaticFiles(directory=admin_web_dir, html=True), name="admin_web")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)

