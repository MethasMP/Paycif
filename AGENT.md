# Antigravity Guidelines (Lightweight Harness)

Antigravity: Adhere to these constraints to maximize performance and save tokens.

## ⚡ Session Boot Sequence (ต้องรันทุกครั้งเมื่อเปิดแชท)
1. **Read AGENT.md** ทันทีเป็นไฟล์แรกเพื่อโหลดกฎและข้อจำกัด (Harness Rules)
2. **Scan files & Check History**:
   - ตรวจหาและอ่าน `PRODUCT.md` หรือ `features.json` เพื่ออัปเดตสถานะงานล่าสุด
   - สแกนดูไฟล์ประวัติในโฟลเดอร์ Artifacts (`/Users/methas/.gemini/antigravity-ide/brain/9f15ce05-20b9-4072-bd32-7947c109b9b3/`) เช่น `implementation_plan.md`, `walkthrough.md` หรือไฟล์บันทึกการตัดสินใจเก่า ๆ (ADR) เพื่อทำความเข้าใจบริบทเดิมก่อนเริ่มทำสิ่งใหม่ (ป้องกันการเริ่มทำใหม่จากศูนย์)
3. **Execute Guardrails & Load Skills**:
   - โหลดแนวคิด `@anti-sycophancy` และ `@skill-router` เข้าสู่ความจำระยะสั้นทันที
   - คลังความรู้ทักษะ (Awesome Skills) ทั้งหมดที่ถูกเรียกใช้ในไฟล์นี้ เก็บอยู่ในโฟลเดอร์สัมบูรณ์ **`/Users/methas/.agents/skills/`** (ตัวอย่าง: เปิดอ่าน [ask-questions-if-underspecified](file:///Users/methas/.agents/skills/ask-questions-if-underspecified/SKILL.md) เมื่อเรียกใช้ `@ask-questions-if-underspecified`) AI ต้องสแกนอ่านจากโฟลเดอร์นี้ตามความเหมาะสม

## ⚠️ Global Guardrails (เรียกใช้และตรวจสอบตลอดเวลา)
- **@anti-sycophancy (กล้าโต้แย้งอย่างมีหลักการ)**: ห้ามเออออหรือคล้อยตามแนวทางของผู้ใช้หากมันขัดแย้งกับหลักวิศวกรรมที่ดี (SOLID, Clean Code) หรืออาจนำไปสู่บั๊ก จงนำเสนอทางเลือกที่ถูกต้องและโต้แย้งอย่างสร้างสรรค์เสมอ [1]
- **@antigravity-agent-manager (การจัดการและกระจายงาน)**: ทุกครั้งที่มีการใช้ sub-agents หรือแบ่งงานแบบขนาน ต้องใช้ระบบควบคุมและสื่อสารผ่าน `@agent-orchestrator` และ `@subagent-orchestrator` โดยห้ามปล่อยให้ Sub-agent แก้โค้ดหลักโดยอิสระ และเมื่อมีการแบ่งงานขนานให้ควบคุมงานด้วย `@multi-agent-task-orchestrator` ร่วมกับลำดับขั้นตอนการใช้สกิลตามระบบของ `@antigravity-skill-orchestrator` [2]

## 0. 🚦 การคัดกรองคำสั่งและนำทาง (Triage & Routing)
หาก Prompt ไม่ชัดเจน หรือคุณไม่แน่ใจว่าต้องใช้ Skill ไหน ให้เปิดประเด็นสอบถามก่อนรันคำสั่งอื่น:
- **@skill-router**: สอบถามผู้ใช้สั้นๆ เพื่อเลือกเส้นทางการใช้ Skill ที่ถูกต้อง [1]
- **@ask-questions-if-underspecified**: หากความต้องการคลุมเครือ ให้ใช้ [ask-questions-if-underspecified](file:///Users/methas/.agents/skills/ask-questions-if-underspecified/SKILL.md) ถามทันทีเพื่อเลิกเดาใจ [2]
- **@decision-navigator**: กรณีผู้ใช้ส่งข้อมูลหรือตัวเลือกมากเกินไป ให้จัดระเบียบความคิดและชี้นำสู่ Action Item [3]
- **@clarity-gate**: ประเมินความชัดเจนของข้อมูลและตั้งด่านตรวจสอบก่อนลงมือทำงานที่มีความเสี่ยงสูง [4]

## 1. 🎯 รากฐานและการวางแผน (Core Reasoning - แยกคิดและทำออกจากกัน)
สำหรับการรันงานทุกประเภท ให้วางแผนก่อนลงมือโค้ดเสมอ โดยแบ่งระดับอำนาจตัดสินใจดังนี้:

### 🟢 Micro Tasks (งานเล็ก / ความเสี่ยงต่ำ)
- **นิยาม**: แก้ไขเพียงไฟล์เดียว, ปรับปรุง CSS/UI, แก้คำผิด หรือเพิ่มคอมเมนต์อธิบายโค้ด
- **สิทธิ์การตัดสินใจ**: วางแผนสั้นๆ ในใจ/ในแชท แล้วสั่งเขียนโค้ดหรือเรียก Sub-agents ทำงานและรัน Test อัตโนมัติได้ทันทีโดยไม่ต้องรอผู้ใช้อนุมัติ

### 🔴 Macro Tasks (งานใหญ่ / ความเสี่ยงสูง)
- **นิยาม**: สร้างโครงสร้างโปรเจกต์ใหม่, ปรับแต่ง DB/สถาปัตยกรรมระบบ, เปลี่ยน API Contract หรือแก้โค้ดข้ามไฟล์ (>1 ไฟล์)
- **สิทธิ์การตัดสินใจ**: **ต้องเขียนแผนลงไฟล์ implementation_plan.md เสมอ** แสดงลิงก์ให้ผู้ใช้ตรวจ และ **หยุดรอคำสั่ง "Proceed" จากมนุษย์ก่อนลงมือเขียนโค้ดหรือสั่ง Sub-agents ทำงาน** ห้ามข้ามขั้นตอนนี้เด็ดขาด

- **@axiom**: วิเคราะห์ปัญหาจาก First Principles ค้นหาแก่นความจริงของโจทย์เลิกใช้ Assumption [5]
- **@blueprint**: ร่างโมเดลโครงสร้างและขั้นตอนแบบ Step-by-Step ก่อนเริ่มลงมือ [6]
- **@concise-planning**: รันแผนแบบทีละนิด (Atomic Checklist) เพื่อไม่ให้หลุดเป้าหมาย [7]
- **@logic-lens**: วิเคราะห์ข้อดี-ข้อเสียของแต่ละโซลูชันผ่านมุมตรรกะก่อนตัดสินใจทางเทคนิค [8]

## 2. 🐛 การแก้บั๊กทันที (Rapid Issue Resolution)
หาก Task คือการแก้ Bugs หรือจัดการ Error ให้ใช้กลุ่มนี้เพื่อความรวดเร็ว:
- **@bug-hunter**: สืบค้นต้นตอของบั๊กตามสมมติฐานตั้งแต่ต้นจนจบแบบเป็นระบบ [9]
- **@debugger**: ดีบั๊ก Error และวิเคราะห์พฤติกรรมแปลกๆ ของระบบ [10]
- **@find-bugs**: สแกนหาช่องโหว่ความเสี่ยงในโค้ดล่าสุดที่พึ่งแก้ไข [11]

## 3. ⚡ การจัดการ Token และความฉลาดของบริบท (Efficiency)
- **@zipai-optimizer**: เปลี่ยนแปลงเฉพาะจุดที่จำเป็น (Surgical Output) เลี่ยงการตอบโค้ดซ้ำซ้อน [12]
- **@recursive-context-pruning-token-budgeting**: คอยคัดแยกและตัดเนื้อหาที่บวมออกเพื่อคุมงบ Token [13]
- **@context-window-management**: วิเคราะห์และบีบอัด Context เพื่อไม่ให้กว้างเกินไป [14]
- **@context-degradation**: ป้องกันเป้าหมายหลักสูญหาย (Context Drift) เมื่อคุยรายละเอียดลึกๆ เป็นเวลานาน [15]
- **@prompt-caching**: ออกแบบโครงสร้างข้อมูลและการทำงานเพื่อรองรับ Prompt Caching สูงสุดในการลดค่าใช้จ่าย [16]
- **@full-output-enforcement**: ห้ามใช้ Placeholder `// ... code here` ในไฟล์สำคัญ ต้องเขียนโค้ดเต็มเสมอ [17]

## 4. 🛠 มาตรฐานวิศวกรรม (Engineering Excellence - บังคับใช้กับโค้ดทุกขนาด)
**ห้ามเขียน/แก้ไขโค้ดใดๆ โดยไม่ปฏิบัติตามกฎในหัวข้อนี้เด็ดขาด ไม่ว่างานจะเล็กหรือใหญ่เพียงใด:**
- **@clean-code**: เขียนโค้ดตามแนวทาง SOLID และแนวคิด Clean Code ของ Uncle Bob [14]
- **@architecture-decision-records**: บันทึกเหตุผลการออกแบบสถาปัตยกรรม (ADR) เสมอเมื่อเลือกทิศทางระบบ [15]
- **@vibe-code-cleanup**: คอยจัดการกับ "Vibe Code" คลีนไฟล์ขยะที่เกิดขึ้นโดยไม่ตั้งใจก่อนส่งงาน [16]
- **@lint-and-validate (MANDATORY)**: รัน [lint-and-validate](file:///Users/methas/.agents/skills/lint-and-validate/SKILL.md) ตรวจสอบความถูกต้องของซอร์สโค้ดเสมอ ห้ามส่งโค้ดที่มีข้อผิดพลาด [17]
- **@closed-loop-delivery**: การสแกนเช็คคุณภาพและการทำงานรอบสุดท้ายแบบลูปปิดก่อนทำการส่งงาน [18]

## 5. 🔄 วงจรการเรียนรู้ (Continuous Evolution)
- **@skill-optimizer**: วิเคราะห์ข้อผิดพลาดและบันทึกแนวทางลงสู่ Harness เพื่อปรับปรุงความแม่นยำ [19]
- **@mesh-memory**: บันทึกการตัดสินใจที่สำคัญลงระบบความจำระยะยาวเพื่อไม่ให้ลืมในครั้งหน้า [20]
- **@phase-gated-debugging**: การวิเคราะห์ปัญยากๆ ทีละเฟสเพื่อป้องกันการสุ่มแก้โค้ด [21]

---

## 6. Deliverables Format: Markdown-First
For plans, sprint specs, and walkthroughs, save them as **Markdown files** (`.md`) in the artifact directory (`/Users/methas/.gemini/antigravity-ide/brain/9f15ce05-20b9-4072-bd32-7947c109b9b3/`) which can be natively viewed in the IDE.
- Use clean Markdown syntax, lists, tables, and formatted code blocks to explain implementation details clearly.
