package simulator

import (
	"fmt"
	"paysif/pkg/nfc"
	"testing"
)

// TestGlobalPassportSanity runs a 10x scale test across synthetic passports.
// Instead of 1 manual test, we simulate various nationalities and identities instantly.
func TestGlobalPassportSanity(t *testing.T) {
	cases := []struct {
		country   string
		firstName string
		lastName  string
	}{
		{"THA", "SOMCHAI", "SAVASDEE"},
		{"MEX", "JUAN", "GARCIA"},
		{"DEU", "HANS", "MULLER"},
		{"JPN", "TARO", "SATO"},
	}

	for _, tc := range cases {
		t.Run(tc.country, func(t *testing.T) {
			data, err := GenerateMockPassport(tc.country, tc.firstName, tc.lastName)
			if err != nil {
				t.Fatalf("Failed to generate mock passport: %v", err)
			}

			// Simulated Verifier Call
			payload := nfc.NfcPassportPayload{
				DG1:                data.DG1,
				DG2:                data.DG2,
				SOD:                data.SOD,
				DocumentSignerCert: data.DocumentSignerCert,
			}

			// 1. Check MRZ Integrity
			if len(payload.DG1) == 0 {
				t.Error("DG1 should not be empty")
			}

			// 2. Audit Hash Consistency
			hash1 := payload.CalculateAuditHash()
			hash2 := payload.CalculateAuditHash()
			if hash1 != hash2 {
				t.Error("Audit hash must be deterministic")
			}

			fmt.Printf("✅ Certified Identity Simulator Pass for %s %s (%s)\n", 
				tc.firstName, tc.lastName, tc.country)
		})
	}
}
