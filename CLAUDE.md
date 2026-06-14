# CLAUDE.md — Paycif Project Context

> สำหรับ AI coding agent: อ่านไฟล์นี้ก่อนเริ่มงานใดๆ เพื่อเข้าใจภาพรวมระบบ สถานะปัจจุบัน และข้อจำกัดเชิงสถาปัตยกรรมที่ต้องยึดตาม

---

## 1. Paycif คืออะไร

Paycif เป็น **cross-border payment orchestration layer** ที่ช่วยให้นักท่องเที่ยวต่างชาติจ่ายเงินร้านค้าไทยผ่าน **PromptPay QR** โดยใช้วิธีจ่ายเงินจากต่างประเทศ (บัตรเครดิต, Apple Pay, stablecoin)

**สิ่งสำคัญ:** Paycif **ไม่มี payment license ของตัวเอง** — กิจกรรมที่ต้องมี license ทั้งหมดถูก delegate ไปยัง partner ที่มี license แล้ว Paycif ทำหน้าที่เป็น orchestrator/middleware เท่านั้น

บริษัท: PAYSIF COMPANY LIMITED (จดทะเบียน 27 มี.ค. 2026, Prachinburi)
เว็บไซต์: paysif.io

---

## 2. Core Architecture (3-leg flow)

```
[Tourist] → On-Ramp Partner → USDC Pool Wallet (Base network - Held/Controlled by Partner) → Off-Ramp Partner → PromptPay → [Merchant]
```

- **On-ramp:** รับเงิน fiat จากนักท่องเที่ยว (card/Apple Pay/bank transfer) → แปลงเป็น USDC
- **Pool wallet:** USDC wallet บน Base network ที่ถือครองและควบคุมโดย Licensed Partner (เช่น SQRIL หรือ Off-ramp partner) — Paycif ทำหน้าที่ส่งคำสั่งหรือจัดการ (orchestrate) เท่านั้น ไม่ได้จัดการกระเป๋าหรือควบคุมสิทธิ์ในการเคลื่อนย้ายเงินโดยตรง
- **Off-ramp:** แปลง USDC → THB → ส่งเข้า PromptPay ของร้านค้า

**กฎสำคัญสำหรับ AI agent:**
ทุก partner role (on-ramp, off-ramp) ต้อง implement ผ่าน interface ที่ swap ได้:
- `IOnRampProvider`
- `IOffRampProvider`

**ห้าม hardcode ชื่อ partner company ใน core architecture/business logic** — ชื่อ partner ใส่ได้เฉพาะใน config/adapter layer เท่านั้น เพราะ partner เปลี่ยนได้เสมอ (pay-per-use, ไม่ exclusive)

---

## 3. สถานะปัจจุบัน (อัปเดตล่าสุด)

### Partner ที่ confirmed
- **SQRIL** — เซ็น Service Agreement แล้ว (SIAC Singapore arbitration, 45-day fee change notice, 12-month liability cap with fraud/gross negligence carve-outs)
- ⚠️ **ยังไม่ verify:** SQRIL ประกาศ (มี.ค. 2026) ว่ามี PromptPay QR capability แล้ว — แต่ยังไม่ได้ confirm ว่า live จริงหรือยัง ต้องตรวจสอบก่อนพึ่งพา

### Partner ที่ยังไม่ confirmed
- Coinflow, Openfort, Alchemy Pay, Ramp Network — ส่ง BD outreach ไปแล้ว (เช่น ถึง Anchit Goel ที่ Alchemy Pay) แต่ยังไม่มี response/progress

### โจทย์เปิดที่กำลังแก้อยู่
1. **Regulatory gray area** — orchestration role ของ Paycif ต้องขอ BOT license หรือไม่ ยังไม่มีคำตอบชัดเจน
2. **Merchant QR upgrade strategy** — ต้องดันร้านค้าให้ใช้ merchant QR (0.90% + $0.04) เพราะ personal QR rate (2.50% + $0.16) ใช้งานไม่ได้จริงในเชิงธุรกิจ — นี่คือ blocker หลักสำหรับ unit economics
3. **Licensed sponsor bank / white-label path** — กำลังหาทางผ่าน SCB/KBank/BBL (sponsor bank) หรือ SQRIL white-label เพื่อแก้ปัญหา AML liability

### Competitive positioning
- **TAGTHAi Easy Pay** = direct competitor ที่ทำ tourist PromptPay use case อยู่แล้ว
- **Crypto-to-THB corridor** = primary differentiator ของ Paycif ที่ TAGTHAi ไม่มี → นี่คือจุดที่ต้อง defend และพัฒนาต่อ

### Funding & Revenue
- Pre-seed, pre-revenue, pre-launch — ยังไม่มี paying customer

---

## 4. Design System Reference

ใช้ดีไซน์ "Warm Precision":
- Deep Teal `#0A5C4A`
- Off-white cream `#FAFAF7`
- Gold `#C9963A`
- Typography: DM Serif Display (ตัวเลขเงิน), DM Sans (UI copy)

รายละเอียดเต็มอยู่ใน `design.md` แยกต่างหาก — ไม่ต้อง redo ที่นี่

---

## 5. หลักการที่ AI agent ต้องยึดตามเสมอ

1. Paycif ไม่ใช่ licensed entity — ห้ามเขียน logic ที่ทำให้ดูเหมือน Paycif ถือ/โอนเงิน หรือควบคุมกระเป๋าเงิน (Pool Wallet) เองโดยเด็ดขาด (กระเป๋าต้องเป็นของ Licensed Partner และเราเพียงส่งคำสั่งหรืองานเท่านั้น)
2. Provider abstraction ต้อง swap ได้เสมอ — อย่า couple โค้ดกับ partner เฉพาะเจ้า
3. Merchant-side QR (ไม่ใช่ personal QR) คือ default assumption สำหรับ flow ใดๆ ที่เกี่ยวกับการรับเงิน
4. ถ้า task เกี่ยวกับ regulatory/compliance — flag ไว้ว่าเป็นพื้นที่ gray area ที่ยังไม่ resolve อย่า assume คำตอบ
