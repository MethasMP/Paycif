package simulator

import (
	"fmt"
	"paysif/pkg/nfc"
	"runtime"
	"sync"
	"testing"
	"time"
)

// BenchmarkKYCVerification10x ทดสอบความเร็วในการตรวจพาสปอร์ตในระดับอุตสาหกรรม
// เพื่อพิสูจน์ว่าเสาหลัก "Blazing Fast" ของเราสามารถรับมือได้ 10,000+ เล่ม/นาที
func BenchmarkKYCVerification10x(b *testing.B) {
	// 1. เตรียมข้อมูลพาสปอร์ตจำลองล่วงหน้า
	data, _ := GenerateMockPassport("THA", "STRESS", "TESTER")
	payload := nfc.NfcPassportPayload{
		DG1:                data.DG1,
		DG2:                data.DG2,
		SOD:                data.SOD,
		DocumentSignerCert: data.DocumentSignerCert,
	}

	b.ResetTimer()
	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			_, err := nfc.VerifyPassportNfcSignature(payload)
			if err != nil {
				b.Errorf("Verification failed during stress test: %v", err)
			}
		}
	})
}

// TestSystemHighAvailabilitySimulation จำลองพายุคนเข้าใช้งาน (Traffic Spike)
// เพื่อดูพฤติกรรมของระบบในภาวะสภาวะวิกฤต
func TestSystemHighAvailabilitySimulation(t *testing.T) {
	const totalIdentities = 1000 // จำนวนคนทำ KYC พร้อมกัน
	var wg sync.WaitGroup

	start := time.Now()
	successCount := 0
	var mu sync.Mutex

	fmt.Printf("🚀 Starting 10x Stress Test: Simulating %d concurrent KYC sessions...\n", totalIdentities)
	fmt.Printf("💻 System Resources: %d CPU Cores\n", runtime.NumCPU())

	for i := 0; i < totalIdentities; i++ {
		wg.Add(1)
		go func(idx int) {
			defer wg.Done()
			
			// จำลองการสร้างพาสปอร์ตที่แตกต่างกัน (Heavy computation)
			data, _ := GenerateMockPassport("THA", fmt.Sprintf("USER%d", idx), "TEST")
			payload := nfc.NfcPassportPayload{
				DG1:                data.DG1,
				DG2:                data.DG2,
				SOD:                data.SOD,
				DocumentSignerCert: data.DocumentSignerCert,
			}

			// รันการตรวจสอบแบบสากล
			_, err := nfc.VerifyPassportNfcSignature(payload)
			
			if err == nil {
				mu.Lock()
				successCount++
				mu.Unlock()
			}
		}(i)
	}

	wg.Wait()
	duration := time.Since(start)

	tps := float64(totalIdentities) / duration.Seconds()

	fmt.Println("\n--- 📊 10x Stress Test Report ---")
	fmt.Printf("Total KYC Requests:  %d\n", totalIdentities)
	fmt.Printf("Success Rate:        %d/%d (%.2f%%)\n", successCount, totalIdentities, float64(successCount)/float64(totalIdentities)*100)
	fmt.Printf("Total Time:          %v\n", duration)
	fmt.Printf("Throughput (TPS):    %.2f KYC/Second\n", tps)
	fmt.Printf("Estimated Capacity:  %.0f KYC/Hour\n", tps*3600)
	fmt.Println("--------------------------------")

	if successCount < totalIdentities {
		t.Errorf("Failed to maintain 100%% reliability under load: only %d succeeded", successCount)
	}
}
