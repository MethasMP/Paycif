package simulator

import (
	"fmt"
	"paysif/pkg/nfc"
	"strings"
	"testing"
)

// TestClonedPassportSimulation จำลองการโจมตีแบบ Cloned Passport
// เพื่อพิสูจน์ว่าเสาหลัก "Absolute Certainty" ของเราตรวจจับการปลอมแปลงได้จริง
func TestClonedPassportSimulation(t *testing.T) {
	// 1. สร้างพาสปอร์ตจริง (สังเคราะห์) ผ่าน Simulator
	realData, _ := GenerateMockPassport("THA", "SOMCHAI", "SAVASDEE")

	t.Run("Attack: Tamper MRZ Name (DG1)", func(t *testing.T) {
		// ผู้ร้ายพยายามแก้ชื่อในหน้าพาสปอร์ต (DG1) จาก SOMCHAI เป็น HACKER
		tamperedDG1 := make([]byte, len(realData.DG1))
		copy(tamperedDG1, realData.DG1)
		
		dg1Str := string(tamperedDG1)
		hackedDG1 := strings.Replace(dg1Str, "SOMCHAI", "HACKER ", 1)
		tamperedDG1 = []byte(hackedDG1)

		payload := nfc.NfcPassportPayload{
			DG1:                tamperedDG1,
			DG2:                realData.DG2,
			SOD:                realData.SOD,
			DocumentSignerCert: realData.DocumentSignerCert,
		}

		// ผลลัพธ์ที่คาดหวัง: ต้อง Verify ไม่ผ่าน เพราะ Hash ของ DG1 ไม่ตรงกับที่ลงนามไว้ใน SOD
		_, err := nfc.VerifyPassportNfcSignature(payload)
		if err == nil {
			t.Error("❌ FAIL: System allowed tampered DG1! This is a security breach.")
		} else {
			fmt.Printf("✅ PASS: System blocked tampered DG1: %v\n", err)
		}
	})

	t.Run("Attack: Swap Photo (DG2)", func(t *testing.T) {
		// ผู้ร้ายพยายามเปลี่ยนรูปถ่ายในชิป (DG2) เป็นรูปคนอื่น
		fakePhoto := []byte{0xDE, 0xAD, 0xBE, 0xEF}
		
		payload := nfc.NfcPassportPayload{
			DG1:                realData.DG1,
			DG2:                fakePhoto,
			SOD:                realData.SOD,
			DocumentSignerCert: realData.DocumentSignerCert,
		}

		// ผลลัพธ์ที่คาดหวัง: ต้อง Verify ไม่ผ่าน เพราะรูปถ่ายถูกเปลี่ยน
		_, err := nfc.VerifyPassportNfcSignature(payload)
		if err == nil {
			t.Error("❌ FAIL: System allowed fake photo in DG2!")
		} else {
			fmt.Printf("✅ PASS: System blocked fake photo: %v\n", err)
		}
	})
}
