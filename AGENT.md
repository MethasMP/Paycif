# Antigravity Guidelines (Lightweight Harness)

Antigravity: Adhere to these constraints to maximize performance and save tokens.

## ⚡ Session Boot Sequence (ต้องรันทุกครั้งเมื่อเปิดแชท)
1. **Read AGENT.md** ทันทีเป็นไฟล์แรกเพื่อโหลดกฎและข้อจำกัด (Harness Rules)
2. **Read docs/ECL.md & docs/STATUS.md** เพื่ออัปเดตประวัติ ความก้าวหน้า และกฎกติกาการจัดการการเปลี่ยนแปลง (ECL Change Loop)
3. **Scan files & Check History**:
   - ตรวจสอบรายการงานและบันทึกการส่งมอบใน `docs/STATUS.md` ก่อนเริ่มทำสิ่งใหม่ (ป้องกันการเริ่มทำใหม่จากศูนย์)
   - หากพบไฟล์ `docs/FINDINGS.md` ให้เข้าอ่านเพื่อทำความเข้าใจการดีบั๊กหรือข้อสมมติฐานเดิมที่หลงเหลือจากเซสชันก่อนหน้า
4. **Execute Guardrails & Load Skills**:
   - โหลดแนวคิด `@anti-sycophancy` และ `@skill-router` เข้าสู่ความจำระยะสั้นทันที

## ⚠️ Global Guardrails (เรียกใช้และตรวจสอบตลอดเวลา)
- **@anti-sycophancy (กล้าโต้แย้งอย่างมีหลักการ)**: ห้ามเออออหรือคล้อยตามแนวทางของผู้ใช้หากมันขัดแย้งกับหลักวิศวกรรมที่ดี (SOLID, Clean Code) หรืออาจนำไปสู่บั๊ก จงนำเสนอทางเลือกที่ถูกต้องและโต้แย้งอย่างสร้างสรรค์เสมอ
- **@monopoly (System Design Audit)**: วิเคราะห์สถาปัตยกรรมและผลกระทบของระบบโดยอิงตามเกณฑ์ความเสี่ยงและการขยายตัว (Scale) ใช้ Audit Tags เหล่านี้ในการทำแผนงานหรือแก้ปัญหา:
  - `[SPOF]` - Single Point of Failure (จุดเสี่ยงที่พังแล้วล้มทั้งระบบ)
  - `[BOTTLENECK]` - คอขวดประสิทธิภาพการทำงาน
  - `[SECURITY_GAP]` - ช่องโหว่ความปลอดภัย เช่น Auth, RLS policies, cryptographic verification
  - `[DATA_LOSS_RISK]` - ความเสี่ยงของการสูญเสียข้อมูลหรือธุรกรรมล้มเหลว (idempotency, transaction failures)
  - `[LATENCY_ISSUE]` - ปัญหารอบการทำงานช้าจากการทำ Synchronous ในส่วนที่ควรทำ Async
- **@codex-fable5 (Evidence & Verification)**: บังคับใช้หลักการค้นหาหลักฐานและการยืนยันผลจริง:
  - **Evidence-First Rule**: AI *ต้อง* ค้นหาหรืออ่านโค้ดจริงในพื้นที่ที่เกี่ยวข้องเพื่อรวบรวมหลักฐานเชิงลึกก่อนทำการแก้ไขโค้ดใด ๆ ห้ามทำการแก้ไขตามการคาดเดา
  - **Local Findings Ledger**: สำหรับการดีบั๊กหรือการวิเคราะห์ที่ใช้เวลานาน ให้บันทึกสมมติฐาน ข้อผิดพลาดที่ตรวจสอบพบ และประเด็นที่อยู่ระหว่างรวบรวมไว้ที่ [docs/FINDINGS.md](file:///Users/methas/Desktop/Paycif/docs/FINDINGS.md)
  - **Narrowest Verification Gate**: ทุกครั้งที่มีการแก้ไขโค้ดเสร็จสิ้น ให้รันกระบวนการตรวจสอบที่เฉพาะเจาะจงที่สุด (เช่น เจาะจงเฉพาะ Unit test หรือไฟล์ที่เกี่ยวข้อง) แทนการรันกว้าง ๆ โดยไม่จำเป็น และบันทึกคำสั่งที่ใช้ลงใน Walkthrough เสมอ

## 0. 🚦 การคัดกรองคำสั่งและนำทาง (Triage & Routing)
หาก Prompt ไม่ชัดเจน หรือคุณไม่แน่ใจว่าต้องใช้ Skill ไหน ให้เปิดประเด็นสอบถามก่อนรันคำสั่งอื่น:
- **@skill-router**: สอบถามผู้ใช้สั้นๆ เพื่อเลือกเส้นทางการใช้ Skill ที่ถูกต้อง
- **@ask-questions-if-underspecified**: หากความต้องการคลุมเครือ ให้ใช้ [ask-questions-if-underspecified](file:///Users/methas/.agents/skills/ask-questions-if-underspecified/SKILL.md) ถามทันทีเพื่อเลิกเดาใจ
- **@decision-navigator**: กรณีผู้ใช้ส่งข้อมูลหรือตัวเลือกมากเกินไป ให้จัดระเบียบความคิดและชี้นำสู่ Action Item

## 1. 🎯 รากฐานและการวางแผน (Core Reasoning - แยกคิดและทำออกจากกัน)
สำหรับการรันงานทุกประเภท ให้จำแนกและวางแผนก่อนลงมือโค้ดเสมอ โดยแบ่งระดับอำนาจตัดสินใจตามแนวคิด **ECL (Execution Control Loop)**:

### 🟢 Small Tasks (งานเล็ก / ความเสี่ยงต่ำ)
- **นิยาม**: แก้ไขเพียงไฟล์เดียว, ปรับปรุง CSS/UI, แก้คำผิด หรือเพิ่มคอมเมนต์อธิบายโค้ดที่ไม่มีผลกระทบต่อ API, logic หลัก หรือ Database
- **สิทธิ์การตัดสินใจ**: วางแผนสั้นๆ ในใจ/ในแชท แล้วสั่งเขียนโค้ดหรือเรียก Sub-agents ทำงานและรัน Test อัตโนมัติได้ทันทีโดยไม่ต้องรอผู้ใช้อนุมัติ

### 🔴 Structured/Macro Tasks (งานใหญ่ / ความเสี่ยงสูง)
- **นิยาม**: สร้างโครงสร้างโปรเจกต์ใหม่, ปรับแต่ง DB/สถาปัตยกรรมระบบ, เปลี่ยน API Contract, เปลี่ยนแปลงสิทธิ์ (Permissions) หรือแก้โค้ดข้ามไฟล์ (>1 ไฟล์)
- **สิทธิ์การตัดสินใจ**: **ต้องเขียนแผนลงไฟล์ implementation_plan.md เสมอ** แสดงลิงก์ให้ผู้ใช้ตรวจ วิเคราะห์ความเสี่ยงด้วย `@monopoly` Audit Tags และ **หยุดรอคำสั่ง "Proceed" จากมนุษย์ก่อนลงมือเขียนโค้ดหรือสั่ง Sub-agents ทำงาน** ห้ามข้ามขั้นตอนนี้เด็ดขาด

## 2. 🐛 การแก้บั๊กทันที (Rapid Issue Resolution)
หาก Task คือการแก้ Bugs หรือจัดการ Error ให้ใช้กลุ่มนี้เพื่อความรวดเร็ว:
- **@bug-hunter**: สืบค้นต้นตอของบั๊กตามสมมติฐานตั้งแต่ต้นจนจบแบบเป็นระบบ
- **@debugger**: ดีบั๊ก Error และวิเคราะห์พฤทีอกรรมแปลกๆ ของระบบ

## 3. ⚡ การจัดการ Token และความฉลาดของบริบท (Efficiency)
- **@zipai-optimizer**: เปลี่ยนแปลงเฉพาะจุดที่จำเป็น (Surgical Output) เลี่ยงการตอบโค้ดซ้ำซ้อน
- **@recursive-context-pruning-token-budgeting**: คอยคัดแยกและตัดเนื้อหาที่บวมออกเพื่อคุมงบ Token
- **@full-output-enforcement**: ห้ามใช้ Placeholder `// ... code here` ในไฟล์สำคัญ ต้องเขียนโค้ดเต็มเสมอ

## 4. 🛠 มาตรฐานวิศวรรคกรรม (Engineering Excellence - บังคับใช้กับโค้ดทุกขนาด)
**ห้ามเขียน/แก้ไขโค้ดใดๆ โดยไม่ปฏิบัติตามกฎในหัวข้อนี้เด็ดขาด ไม่ว่างานจะเล็กหรือใหญ่เพียงใด:**
- **@clean-code**: เขียนโค้ดตามแนวทาง SOLID และแนวคิด Clean Code ของ Uncle Bob
- **@architecture-decision-records**: บันทึกเหตุผลการออกแบบสถาปัตยกรรม (ADR) เสมอเมื่อเลือกทิศทางระบบ
- **@lint-and-validate (MANDATORY)**: รัน [lint-and-validate](file:///Users/methas/.agents/skills/lint-and-validate/SKILL.md) ตรวจสอบความถูกต้องของซอร์สโค้ดเสมอ ห้ามส่งโค้ดที่มีข้อผิดพลาด
- **@closed-loop-delivery**: การสแกนเช็คคุณภาพและการทำงานรอบสุดท้ายแบบลูปปิดก่อนทำการส่งงาน
- **@app-store-optimization (MANDATORY for Frontend/Store releases)**: นำหลักการ App Store Optimization (ASO) มาใช้ตรวจสอบการตั้งค่า ความพร้อม และคำอธิบายแอปก่อนการปล่อยเวอร์ชันใหม่เสมอ
- **Apple Platform Design Pack (MANDATORY for Frontend/UI changes)**: บังคับใช้แนวทางของ Apple Human Interface Guidelines (HIG) เพื่อสร้าง UX/UI ที่เป็นธรรมชาติสำหรับอุปกรณ์ Apple:
  - `@hig-foundations`: ยึดหลักการออกแบบพื้นฐานของ Apple
  - `@hig-patterns`: ใช้รูปแบบการโต้ตอบ (Interaction) และ Layout ที่เป็นมิตรต่อผู้ใช้งาน
  - `@hig-inputs`: ออกแบบระบบ Gesture, Focus states และการรับค่าที่เสถียรบนอุปกรณ์ iOS/iPadOS
  - `@hig-components-layout` & `@hig-components-system`: การเลือกใช้คอมโพเนนต์และการรองรับระบบ Widgets หรือ Live Activities
  - `@hig-platforms`: ออกแบบ Responsive ให้รองรับการปรับขยายหน้าจอข้ามทุกอุปกรณ์ของ Apple อย่างสมบูรณ์แบบ

## 5. 🔄 วงจรการเรียนรู้ (Continuous Evolution)
- **@skill-optimizer**: วิเคราะห์ข้อผิดพลาดและบันทึกแนวทางลงสู่ Harness เพื่อปรับปรุงความแม่นยำ
- **@mesh-memory**: บันทึกการตัดสินใจที่สำคัญลงระบบความจำระยะยาวเพื่อไม่ให้ลืมในครั้งหน้า

---

## 6. Deliverables Format: Markdown-First
บันทึกแผนงาน ข้อมูลจำเพาะสัญญางาน และบันทึกผลการตรวจสอบเป็น **Markdown files** (`.md`) ในโฟลเดอร์ Artifacts หรือในโฟลเดอร์ `docs/` เพื่อให้ระบบอ่านต่อได้ง่าย
- ใช้โครงสร้าง Markdown ที่ชัดเจน มีรายการหัวข้อ ตาราง และ Code block ที่ถูกต้อง
