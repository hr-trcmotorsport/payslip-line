# ระบบส่งสลิปเงินเดือนผ่าน LINE

```
พนักงาน ──ทักไลน์──▶ LINE OA ──webhook──▶ FastAPI (Render) ──▶ Supabase (DB + ไฟล์)
                                                                     ▲
HR ──อัปโหลด/อนุมัติ/กดส่ง──▶ Streamlit (admin/app.py) ─────────────┤
GitHub Actions (cron สิ้นเดือน) ──▶ scripts/send_monthly.py ────────┘
```

ทำไมแยกหลายส่วน: Streamlit รับ webhook และตั้งเวลารันเองไม่ได้ ส่วน LINE ส่งไฟล์ PDF ตรงๆ ไม่ได้
ระบบเลยส่ง **ลิงก์ชั่วคราว** ไปที่ไฟล์ PDF ที่ **ใส่รหัสผ่านไว้** (รหัส = เลขบัตร ปชช. 4 ตัวท้าย)

## ขั้นตอนตั้งค่า (ทำครั้งเดียว)

### 1) Supabase (ฟรี)
1. สมัคร supabase.com → New project
2. SQL Editor → วางเนื้อหา `schema.sql` → Run (สร้างตาราง + bucket `payslips` แบบ private)
3. Project Settings → API → จด `Project URL` และ `service_role key`

### 2) LINE Official Account
1. สร้าง LINE OA → เปิด Messaging API ใน LINE Developers Console
2. จด `Channel secret` และออก `Channel access token (long-lived)`
3. ปิด "Auto-reply messages" และ "Greeting message" ของ LINE OA (ให้บอทของเราตอบเอง)

### 3) สร้างคีย์ลับ
```bash
python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"   # → ENCRYPTION_KEY
python -c "import secrets; print(secrets.token_urlsafe(32))"                                # → PEPPER
```
เก็บทั้งสองค่าไว้ดีๆ **ห้ามเปลี่ยนหลังเริ่มใช้งาน** (เปลี่ยนแล้วข้อมูลที่เข้ารหัสไว้จะเปิดไม่ได้)

### 4) GitHub
สร้าง repo (แนะนำ **Private**) แล้ว push โฟลเดอร์นี้ขึ้นไป

### 5) Deploy webhook บน Render
1. render.com → New → Blueprint → เลือก repo (อ่าน `render.yaml` ให้เอง)
2. ใส่ env: `SUPABASE_URL`, `SUPABASE_SERVICE_KEY`, `LINE_CHANNEL_SECRET`, `LINE_CHANNEL_ACCESS_TOKEN`, `ENCRYPTION_KEY`, `PEPPER`
3. Deploy เสร็จได้ URL เช่น `https://payslip-line-webhook.onrender.com`
4. LINE Developers → Webhook URL = `https://.../callback` → เปิด Use webhook → กด Verify
5. แพ็กเกจฟรีของ Render จะหลับถ้าไม่มีคนใช้ (ตื่นช้า ~30-60 วิ) แนะนำตั้ง UptimeRobot ping `https://.../health` ทุก 5 นาที

### 6) Deploy หน้าแอดมินบน Streamlit Community Cloud
1. share.streamlit.io → New app → repo นี้ → Main file: `admin/app.py`
2. Advanced settings → Secrets (รูปแบบ TOML):
```toml
SUPABASE_URL = "https://xxxx.supabase.co"
SUPABASE_SERVICE_KEY = "..."
LINE_CHANNEL_ACCESS_TOKEN = "..."
ENCRYPTION_KEY = "..."
PEPPER = "..."
ADMIN_PASSWORD = "ตั้งรหัสแอดมินยาวๆ"
```

### 7) GitHub Actions (ส่งอัตโนมัติสิ้นเดือน)
repo → Settings → Secrets and variables → Actions → เพิ่ม secrets 4 ตัว:
`SUPABASE_URL`, `SUPABASE_SERVICE_KEY`, `LINE_CHANNEL_ACCESS_TOKEN`, `ENCRYPTION_KEY`

workflow จะรันเวลา 09:00 น. (ไทย) ทุกวันที่ 28-31 และสคริปต์จะส่งเฉพาะ **วันสิ้นเดือนจริง**
ทดสอบด้วยมือ: Actions → "ส่งสลิปสิ้นเดือน" → Run workflow (ติ๊ก force ถ้าไม่ใช่วันสิ้นเดือน)

## ใช้งานจริง

**พนักงาน** ทักไลน์ OA แล้วพิมพ์
`ลงทะเบียน E0123 1234567890123` (รหัสพนักงาน + เลขบัตร ปชช.)
→ HR เห็นในแท็บ "ยืนยันพนักงาน" ตรวจแล้วกดอนุมัติ → พนักงานได้ข้อความยืนยัน
→ พิมพ์ `สลิป` เมื่อไหร่ก็ได้เพื่อขอลิงก์ใหม่ (`สลิป 2026-09` สำหรับย้อนหลัง) — ใช้ reply จึง **ไม่นับโควต้า 500**

**HR ทุกเดือน**
1. แท็บ "อัปโหลดสลิป" → ใส่งวด (เช่น `2026-10`) → เลือกไฟล์ PDF ทั้งหมด → ตรวจ/แก้รหัสในตาราง → บันทึก
2. ระบบส่งให้เองสิ้นเดือน หรือกดส่งเองได้ในแท็บ "ส่งสลิป"

ถ้าลืมอัปโหลดก่อนสิ้นเดือน GitHub Actions จะขึ้น error (มีอีเมลแจ้ง) แล้วค่อยอัปโหลด + กดส่งมือได้ ระบบไม่ส่งซ้ำคนที่ได้รับแล้ว

## โควต้า LINE
ส่งออกเดือนละ ~1 ข้อความ/คน (120 คน ≈ 120 ข้อความ) + ข้อความแจ้งอนุมัติตอนลงทะเบียน ระบบนับโควต้าไว้ที่หน้าแอดมิน และหยุดส่งเองถ้าเกิน `LINE_MONTHLY_LIMIT` (ค่าเริ่มต้น 500 — ปรับได้ถ้าแพ็กเกจของ OA ต่างจากนี้)

## ความปลอดภัย (PDPA)
- เลขบัตร ปชช. ที่พนักงานส่งมาเก็บแบบเข้ารหัส (Fernet) เฉพาะช่วงรออนุมัติ พออนุมัติจะ **ลบทิ้ง** เหลือแค่ค่าแฮช + รหัสผ่านไฟล์แบบเข้ารหัส
- ไฟล์สลิปเก็บใน bucket private; ลิงก์หมดอายุใน 14 วัน (`LINK_EXPIRE_DAYS`) และเปิดไฟล์ได้ต้องมีรหัสผ่าน
- ใช้ service_role key เฉพาะฝั่งเซิร์ฟเวอร์ ห้าม commit `.env` / secrets ลง GitHub
- เลขบัตรที่พนักงานพิมพ์ในแชทไลน์ยังค้างในประวัติแชทฝั่ง LINE OA — แนะนำให้ลบหรือจำกัดคนเข้าถึงแชท
- ปรับจำนวนหลักรหัสผ่านไฟล์ด้วย `PDF_PASSWORD_DIGITS` (ค่าเริ่มต้น 4)

## รูปแบบรหัสพนักงาน
ระบบอ่านรหัสจากชื่อไฟล์ก่อน ถ้าไม่เจอจะอ่านจากข้อความหน้าแรกของ PDF ตั้งรูปแบบด้วย `EMP_CODE_REGEX`
(ค่าเริ่มต้น `[A-Za-z]{0,3}\d{3,8}`) ถ้าไม่ตรงกับบริษัท ปรับ regex หรือแก้ในตารางตอนอัปโหลดได้เลย

## รันเทสต์ / รันในเครื่อง
```bash
pip install -r requirements.txt pytest
python -m pytest tests
streamlit run admin/app.py
uvicorn webhook.main:app --reload
```
