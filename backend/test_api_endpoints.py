import sys
import os
import asyncio
import httpx
import json

# Fix stdout encoding for Windows console
if sys.platform.startswith('win'):
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

BASE_URL = "http://127.0.0.1:8000"

async def run_tests():
    print("[*] Bat dau kiem thu toan dien cac API nghiep vu Enigma...\n")
    async with httpx.AsyncClient(base_url=BASE_URL, timeout=30.0) as client:
        # 1. Health check
        res = await client.get("/")
        print(f"1. Health check: {res.status_code} -> {res.json()}")
        assert res.status_code == 200

        # 2. Register or Login
        email = "test_intern_2026@enigma.edu.vn"
        password = "Password123@"
        
        reg_res = await client.post("/auth/register", json={
            "full_name": "Dang Van Hung",
            "email": email,
            "password": password,
            "student_id": "SV_AUTO_999",
            "university": "Dai hoc Bach Khoa Ha Noi",
            "major": "Ky thuat Tu dong hoa"
        })
        
        token = None
        if reg_res.status_code in [200, 201]:
            token = reg_res.json()["access_token"]
            print(f"2. Dang ky tai khoan sinh vien: Thanh cong ({email})")
        else:
            login_res = await client.post("/auth/login", json={"email": email, "password": password})
            assert login_res.status_code == 200, f"Login failed: {login_res.text}"
            token = login_res.json()["access_token"]
            print(f"2. Dang nhap tai khoan sinh vien: Thanh cong -> Token nhan duoc")

        headers = {"Authorization": f"Bearer {token}"}

        # 3. Test Tasks API
        print("\n--- [3] KIEM THU API QUAN LY NHIEM VU THEO CHANG ---")
        tasks_res = await client.get("/tasks", headers=headers)
        print(f"GET /tasks: {tasks_res.status_code} - Tong so {len(tasks_res.json())} nhiem vu")
        assert tasks_res.status_code == 200

        prep_tasks = await client.get("/tasks?phase=preparation", headers=headers)
        print(f"GET /tasks?phase=preparation: {len(prep_tasks.json())} nhiem vu chuan bi")
        assert prep_tasks.status_code == 200

        summary_res = await client.get("/tasks/summary", headers=headers)
        print(f"GET /tasks/summary: {summary_res.json()}")
        assert summary_res.status_code == 200

        if tasks_res.json():
            first_task = tasks_res.json()[0]
            task_id = first_task["id"]
            toggle_res = await client.post(f"/tasks/{task_id}/toggle", headers=headers)
            print(f"POST /tasks/{task_id}/toggle: {toggle_res.status_code} -> {toggle_res.json()}")
            assert toggle_res.status_code == 200

        # 4. Test Handbook API
        print("\n--- [4] KIEM THU API TRA CUU CAM NANG & TIM KIEM VECTOR ---")
        cat_res = await client.get("/handbook/categories")
        print(f"GET /handbook/categories: {cat_res.status_code} -> {cat_res.json()}")
        assert cat_res.status_code == 200

        articles_res = await client.get("/handbook?limit=10")
        print(f"GET /handbook: {articles_res.status_code} -> {len(articles_res.json())} bai viet")
        assert articles_res.status_code == 200

        vector_search_res = await client.get("/handbook/search?q=dau chan giay bao ho esd ca dung&top_k=2")
        print(f"GET /handbook/search (ChromaDB): {vector_search_res.status_code}")
        for idx, item in enumerate(vector_search_res.json(), 1):
            print(f"   [{idx}] {item.get('title')} (Score: {item.get('similarity_score')})")
        assert vector_search_res.status_code == 200

        # 5. Test Situation Accumulation Mechanism
        print("\n--- [5] KIEM THU CO CHE TICH LUY TINH HUONG THUC TE MOI ---")
        accumulate_res = await client.post(
            "/handbook/accumulate",
            headers=headers,
            json={
                "situation_description": "Lan dau vao xuong san xuat Module OLED nghe tieng on coi bao loi lien tuc sinh vien bi choang va mat tap trung.",
                "recommended_solution": "Deo nut bit tai chong on dat chuan cap phat, tap trung vao cong doan duoc phan cong va uong nuoc dien giai giua ca.",
                "category_hint": "physical"
            }
        )
        print(f"POST /handbook/accumulate: {accumulate_res.status_code} -> {accumulate_res.json()['data']['title']}")
        assert accumulate_res.status_code == 200

        # 6. Test AI Chat Session & RAG
        print("\n--- [6] KIEM THU AI CHAT SESSION & RAG GENERATION ---")
        session_res = await client.post("/chat/sessions", headers=headers, json={"title": "Test Chat RAG"})
        session_id = session_res.json()["id"]
        print(f"POST /chat/sessions: {session_res.status_code} -> Session ID: {session_id}")

        msg_res = await client.post(
            f"/chat/sessions/{session_id}/messages",
            headers=headers,
            json={
                "content": "Minh bi dau gan ban chan khi mang giay bao ho ESD dung may ca 12 tieng, co cach nao khac phuc khong?",
                "stress_level": 3,
                "sleep_hours": 6.0,
                "recent_symptoms": ["dau chan", "moi vai"]
            }
        )
        print(f"POST /chat/sessions/{session_id}/messages: {msg_res.status_code}")
        msg_data = msg_res.json()
        print(f"   AI Reply Snippet: {msg_data['ai_message']['content'][:200]}...")
        print(f"   RAG Sources Cited: {len(msg_data['ai_message']['rag_sources'])} nguon")
        print(f"   Risk Assessment: {msg_data['risk_assessment']['level']}")
        assert msg_res.status_code == 200

        # Feedback test
        ai_msg_id = msg_data["ai_message"]["id"]
        fb_res = await client.post(f"/chat/messages/{ai_msg_id}/feedback", headers=headers, json={"feedback": 1})
        print(f"POST /chat/messages/{ai_msg_id}/feedback: {fb_res.status_code} -> {fb_res.json()}")
        assert fb_res.status_code == 200

        print("\n========================================================")
        print("TAT CA CAC API NGHIAP VU DA DUOC KIEM THU HOAN TAT 100%!")
        print("========================================================")

if __name__ == "__main__":
    asyncio.run(run_tests())
