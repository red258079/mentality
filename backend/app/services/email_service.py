"""
Email Service – Gửi email OTP qua Gmail SMTP (aiosmtplib, async).

Cấu hình trong .env:
    SMTP_USER=your_gmail@gmail.com
    SMTP_PASSWORD=xxxx xxxx xxxx xxxx   ← App Password 16 ký tự (không phải mật khẩu Gmail thường)

Hướng dẫn lấy App Password:
    1. Truy cập myaccount.google.com → Bảo mật
    2. Bật "Xác minh 2 bước" (nếu chưa bật)
    3. Tìm "App passwords" (Mật khẩu ứng dụng) → Tạo mới
    4. Đặt tên bất kỳ (vd: "Enigma") → Google tạo mã 16 ký tự → Copy vào SMTP_PASSWORD
"""
import logging
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.utils import formataddr

import aiosmtplib

from app.core.config import settings

logger = logging.getLogger(__name__)


# ── HTML Template OTP Email ───────────────────────────────────────────────────

def _build_otp_html(otp_code: str, recipient_name: str = "bạn") -> str:
    """
    Tạo email HTML đẹp chứa mã OTP.
    Thiết kế: dark purple gradient, font sans-serif, mobile-friendly.
    """
    return f"""
<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Mã xác nhận Enigma</title>
</head>
<body style="margin:0;padding:0;background:#0d0d1a;font-family:'Segoe UI',Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#0d0d1a;padding:40px 20px;">
    <tr>
      <td align="center">
        <table width="480" cellpadding="0" cellspacing="0"
               style="background:linear-gradient(135deg,#1a1040 0%,#0f0a2a 100%);
                      border-radius:20px;border:1px solid rgba(139,92,246,0.25);
                      overflow:hidden;max-width:480px;">

          <!-- Header -->
          <tr>
            <td style="background:linear-gradient(135deg,#7c3aed,#6d28d9);
                        padding:32px 40px;text-align:center;">
              <div style="width:60px;height:60px;background:rgba(255,255,255,0.15);
                          border-radius:16px;display:inline-flex;align-items:center;
                          justify-content:center;font-size:28px;margin-bottom:12px;">
                🧘
              </div>
              <h1 style="margin:0;color:#fff;font-size:22px;font-weight:700;
                          letter-spacing:-0.5px;">Enigma</h1>
              <p style="margin:4px 0 0;color:rgba(255,255,255,0.7);font-size:13px;">
                Hỗ trợ tâm lý sinh viên
              </p>
            </td>
          </tr>

          <!-- Body -->
          <tr>
            <td style="padding:36px 40px;">
              <p style="margin:0 0 8px;color:#c4b5fd;font-size:13px;
                         font-weight:600;text-transform:uppercase;letter-spacing:1px;">
                Mã xác nhận
              </p>
              <h2 style="margin:0 0 16px;color:#fff;font-size:20px;font-weight:700;">
                Đặt lại mật khẩu
              </h2>
              <p style="margin:0 0 28px;color:#94a3b8;font-size:14px;line-height:1.6;">
                Xin chào <strong style="color:#e2e8f0;">{recipient_name}</strong>,<br>
                Chúng tôi nhận được yêu cầu đặt lại mật khẩu cho tài khoản Enigma của bạn.
                Sử dụng mã xác nhận bên dưới:
              </p>

              <!-- OTP Box -->
              <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:28px;">
                <tr>
                  <td align="center">
                    <div style="background:rgba(124,58,237,0.15);
                                border:1.5px solid rgba(124,58,237,0.5);
                                border-radius:14px;padding:20px 32px;display:inline-block;">
                      <span style="font-size:42px;font-weight:800;
                                   color:#a78bfa;letter-spacing:14px;
                                   font-family:'Courier New',monospace;">
                        {otp_code}
                      </span>
                    </div>
                  </td>
                </tr>
              </table>

              <!-- Warning -->
              <table width="100%" cellpadding="0" cellspacing="0"
                     style="background:rgba(251,191,36,0.08);
                            border:1px solid rgba(251,191,36,0.25);
                            border-radius:10px;margin-bottom:24px;">
                <tr>
                  <td style="padding:14px 18px;">
                    <p style="margin:0;color:#fbbf24;font-size:13px;line-height:1.5;">
                      ⏱ Mã có hiệu lực trong <strong>5 phút</strong> kể từ khi nhận được email này.
                    </p>
                  </td>
                </tr>
              </table>

              <p style="margin:0;color:#64748b;font-size:12px;line-height:1.6;">
                Nếu bạn không yêu cầu đặt lại mật khẩu, hãy bỏ qua email này.
                Tài khoản của bạn vẫn an toàn.
              </p>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="padding:20px 40px 28px;border-top:1px solid rgba(255,255,255,0.06);">
              <p style="margin:0;color:#475569;font-size:11px;text-align:center;line-height:1.6;">
                Email này được gửi tự động bởi hệ thống Enigma.<br>
                Vui lòng không trả lời email này.
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>
"""


# ── Core Send Function ────────────────────────────────────────────────────────

async def send_otp_email(
    to_email: str,
    otp_code: str,
    recipient_name: str = "",
) -> bool:
    """
    Gửi email chứa mã OTP qua Gmail SMTP (TLS/STARTTLS, port 587).

    Trả về:
        True  – gửi thành công
        False – thiếu cấu hình SMTP hoặc gửi thất bại (lỗi được log)

    Nếu SMTP_USER chưa được cấu hình trong .env, hàm sẽ fallback sang
    in OTP ra console (chế độ dev) thay vì raise exception.
    """
    if not settings.SMTP_USER or not settings.SMTP_PASSWORD:
        # ── Fallback: dev mode – in ra console ──────────────────────────────
        logger.warning("[EMAIL] SMTP chưa cấu hình – in OTP ra console (dev mode)")
        print(f"\n{'='*55}")
        print(f"  [OTP EMAIL – DEV MODE]")
        print(f"  To         : {to_email}")
        print(f"  OTP Code   : {otp_code}")
        print(f"  Expires in : 5 phút")
        print(f"{'='*55}\n")
        return True  # Vẫn trả True để flow tiếp tục trong môi trường dev

    # ── Build email message ──────────────────────────────────────────────────
    msg = MIMEMultipart("alternative")
    msg["Subject"] = f"[Enigma] Mã xác nhận đặt lại mật khẩu: {otp_code}"
    msg["From"]    = formataddr((settings.SMTP_FROM_NAME, settings.SMTP_USER))
    msg["To"]      = to_email

    # Plain-text fallback (email clients không hỗ trợ HTML)
    plain_text = (
        f"Mã xác nhận Enigma của bạn: {otp_code}\n\n"
        f"Mã có hiệu lực trong 5 phút.\n"
        f"Nếu bạn không yêu cầu, hãy bỏ qua email này."
    )
    msg.attach(MIMEText(plain_text, "plain", "utf-8"))
    msg.attach(MIMEText(_build_otp_html(otp_code, recipient_name or to_email), "html", "utf-8"))

    # ── Send via SMTP (aiosmtplib, async, STARTTLS) ──────────────────────────
    try:
        await aiosmtplib.send(
            msg,
            hostname  = settings.SMTP_HOST,
            port      = settings.SMTP_PORT,
            username  = settings.SMTP_USER,
            password  = settings.SMTP_PASSWORD,
            start_tls = True,          # STARTTLS (Gmail port 587)
            timeout   = 15,            # Timeout 15 giây
        )
        logger.info(f"[EMAIL] OTP gửi thành công đến {to_email}")
        return True

    except aiosmtplib.SMTPAuthenticationError:
        logger.error(
            "[EMAIL] Xác thực SMTP thất bại! Kiểm tra SMTP_USER và SMTP_PASSWORD trong .env.\n"
            "Lưu ý: SMTP_PASSWORD phải là App Password 16 ký tự (không phải mật khẩu Gmail thường)."
        )
        return False

    except aiosmtplib.SMTPConnectError as e:
        logger.error(f"[EMAIL] Không thể kết nối SMTP server {settings.SMTP_HOST}:{settings.SMTP_PORT} – {e}")
        return False

    except Exception as e:
        logger.error(f"[EMAIL] Lỗi không xác định khi gửi email: {e}")
        return False
