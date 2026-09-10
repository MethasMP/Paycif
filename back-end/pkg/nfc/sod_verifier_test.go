package nfc_test

import (
	"bytes"
	"testing"

	"paysif/pkg/nfc"
	"paysif/pkg/nfc/simulator"
)

func TestCalculateMRZChecksum(t *testing.T) {
	tests := []struct {
		input    string
		expected int
	}{
		{"L898902C3", 6},
		{"590119", 1},
		{"941115", 1},
		{"HA1234567", 7},
	}

	for _, tt := range tests {
		got := nfc.CalculateMRZChecksum(tt.input)
		if got != tt.expected {
			t.Errorf("CalculateMRZChecksum(%q) = %d; want %d", tt.input, got, tt.expected)
		}
	}
}

func TestCalculateAuditHash(t *testing.T) {
	data, err := simulator.GenerateMockPassport("THA", "JOHN", "DOE")
	if err != nil {
		t.Fatalf("Failed to generate mock passport: %v", err)
	}

	payload := nfc.NfcPassportPayload{
		DG1:                data.DG1,
		DG2:                data.DG2,
		SOD:                data.SOD,
		DocumentSignerCert: data.DocumentSignerCert,
	}

	hash1 := payload.CalculateAuditHash()
	hash2 := payload.CalculateAuditHash()

	if !bytes.Equal(hash1[:], hash2[:]) {
		t.Errorf("CalculateAuditHash produced inconsistent results: %x vs %x", hash1, hash2)
	}
}

func TestVerifyPassportNfcSignature_Success(t *testing.T) {
	data, err := simulator.GenerateMockPassport("THA", "SOMCHAI", "PROMPAT")
	if err != nil {
		t.Fatalf("Failed to generate mock passport: %v", err)
	}

	payload := nfc.NfcPassportPayload{
		DG1:                data.DG1,
		DG2:                data.DG2,
		SOD:                data.SOD,
		DocumentSignerCert: data.DocumentSignerCert,
	}

	identity, err := nfc.VerifyPassportNfcSignature(payload)
	if err != nil {
		t.Fatalf("VerifyPassportNfcSignature failed: %v", err)
	}

	if identity.Nationality != "THA" {
		t.Errorf("Expected nationality 'THA', got %q", identity.Nationality)
	}
}

func TestVerifyPassportNfcSignature_MissingDG1(t *testing.T) {
	payload := nfc.NfcPassportPayload{
		DG1: nil,
	}

	_, err := nfc.VerifyPassportNfcSignature(payload)
	if err == nil {
		t.Error("Expected error for missing DG1, got nil")
	}
}

func BenchmarkCalculateMRZChecksum(b *testing.B) {
	data := "HA12345674THA9001015M3001013"
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = nfc.CalculateMRZChecksum(data)
	}
}

func BenchmarkCalculateAuditHash(b *testing.B) {
	data, _ := simulator.GenerateMockPassport("THA", "BENCH", "TEST")
	payload := nfc.NfcPassportPayload{
		DG1:                data.DG1,
		DG2:                data.DG2,
		SOD:                data.SOD,
		DocumentSignerCert: data.DocumentSignerCert,
	}

	b.ResetTimer()
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = payload.CalculateAuditHash()
	}
}

func BenchmarkVerifyPassportNfcSignature(b *testing.B) {
	data, _ := simulator.GenerateMockPassport("THA", "BENCH", "TEST")
	payload := nfc.NfcPassportPayload{
		DG1:                data.DG1,
		DG2:                data.DG2,
		SOD:                data.SOD,
		DocumentSignerCert: data.DocumentSignerCert,
	}

	b.ResetTimer()
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_, _ = nfc.VerifyPassportNfcSignature(payload)
	}
}
