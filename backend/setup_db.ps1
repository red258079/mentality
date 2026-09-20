# ============================================================
# SCRIPT THIẾT LẬP DATABASE ENIGMA
# Chạy file này bằng PowerShell với quyền Admin
# ============================================================

# Thêm PostgreSQL 18 vào PATH trong session này
$env:Path += ";C:\Program Files\PostgreSQL\18\bin"

# --- BƯỚC 1: Tạo database enigma_db ---
# Nhập mật khẩu postgres khi được hỏi
Write-Host "=== Bước 1: Tạo database enigma_db ===" -ForegroundColor Cyan
psql -U postgres -c "CREATE DATABASE enigma_db ENCODING 'UTF8' LC_COLLATE 'en-US' LC_CTYPE 'en-US' TEMPLATE template0;"

# --- BƯỚC 2: Chạy schema SQL ---
Write-Host ""
Write-Host "=== Bước 2: Chạy schema.sql ===" -ForegroundColor Cyan
psql -U postgres -d enigma_db -f "d:\mentality\backend\schema.sql"

Write-Host ""
Write-Host "=== HOÀN TẤT! Database enigma_db đã sẵn sàng ===" -ForegroundColor Green

# --- KIỂM TRA: Hiển thị danh sách bảng đã tạo ---
Write-Host ""
Write-Host "=== Danh sách bảng đã tạo ===" -ForegroundColor Yellow
psql -U postgres -d enigma_db -c "\dt"
