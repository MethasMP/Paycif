package nfc

import (
	"testing"
)

func TestCalculateMRZChecksum(t *testing.T) {
	tests := []struct {
		input    string
		expected int
	}{
		{"L898902C3", 6},
		{"740812", 2},
		{"120415", 9},
		{"AB123456", 4},
	}

	for _, tt := range tests {
		got := CalculateMRZChecksum(tt.input)
		if got != tt.expected {
			t.Errorf("CalculateMRZChecksum(%q) = %d; want %d", tt.input, got, tt.expected)
		}
	}
}

func TestCalculateAuditHash(t *testing.T) {
	payload := NfcPassportPayload{
		DG1:                []byte("P<THASPECIMEN<<TEST<<<<<<<<<<<<<<<<<<<<<<<<<"),
		DG2:                []byte("MOCK_FACIAL_BIOMETRICS_DATA"),
		SOD:                []byte("MOCK_SOD_CMS:SIGNATURE"),
		DocumentSignerCert: []byte("MOCK_CERTIFICATE"),
	}

	hash1 := payload.CalculateAuditHash()
	hash2 := payload.CalculateAuditHash()

	if hash1 != hash2 {
		t.Errorf("CalculateAuditHash produced inconsistent results: %x vs %x", hash1, hash2)
	}

	if hash1 == [32]byte{} {
		t.Errorf("CalculateAuditHash returned zero hash")
	}
}

func BenchmarkCalculateMRZChecksum(b *testing.B) {
	mrz := "L898902C363USA7408122F1204159ZE184226B<<<<<10"
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = CalculateMRZChecksum(mrz)
	}
}

func BenchmarkCalculateAuditHash(b *testing.B) {
	payload := NfcPassportPayload{
		DG1:                []byte("P<THASPECIMEN<<TEST<<<<<<<<<<<<<<<<<<<<<<<<<"),
		DG2:                []byte("MOCK_FACIAL_BIOMETRICS_DATA"),
		SOD:                []byte("MOCK_SOD_CMS:SIGNATURE"),
		DocumentSignerCert: []byte("MOCK_CERTIFICATE"),
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = payload.CalculateAuditHash()
	}
}
