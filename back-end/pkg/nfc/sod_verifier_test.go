package nfc

import (
	"bytes"
	"testing"
)

func BenchmarkCalculateAuditHash(b *testing.B) {
	payload := NfcPassportPayload{
		DG1:                bytes.Repeat([]byte{0x01, 0x02, 0x03, 0x04}, 25),
		DG2:                bytes.Repeat([]byte{0x05, 0x06, 0x07, 0x08}, 2500),
		SOD:                []byte("MOCK_SOD_CMS:dummy_signature_data_here_for_testing"),
		DocumentSignerCert: bytes.Repeat([]byte{0x09, 0x0a, 0x0b, 0x0c}, 100),
	}

	b.ReportAllocs()
	b.ResetTimer()

	for i := 0; i < b.N; i++ {
		_ = payload.CalculateAuditHash()
	}
}

func TestCalculateAuditHash(t *testing.T) {
	payload := NfcPassportPayload{
		DG1:                []byte("DG1_TEST_DATA"),
		DG2:                []byte("DG2_TEST_DATA"),
		SOD:                []byte("MOCK_SOD_CMS:TEST_SIGNATURE"),
		DocumentSignerCert: []byte("TEST_CERT"),
	}

	hash1 := payload.CalculateAuditHash()
	hash2 := payload.CalculateAuditHash()

	if hash1 != hash2 {
		t.Fatalf("expected identical audit hashes, got %x and %x", hash1, hash2)
	}

	// Verify that modifying payload changes the audit hash
	payloadModified := payload
	payloadModified.DG1 = []byte("DG1_MODIFIED_DATA")
	hash3 := payloadModified.CalculateAuditHash()

	if hash1 == hash3 {
		t.Fatalf("expected different audit hashes after modification, but got equal: %x", hash1)
	}
}

func TestParseDG1(t *testing.T) {
	// Sample TD3 MRZ DG1 payload snippet (2 lines of 44 characters = 88 characters)
	// Line 1: P<THASPECIMEN<<USER<<<<<<<<<<<<<<<<<<<<<<<<< (44 chars)
	// Line 2: AA12345674THA9001015M3001013<<<<<<<<<<<<<<<0 (44 chars)
	dg1Prefix := []byte{0x61, 0x5B, 0x5F, 0x1F, 0x58}
	mrzLine1 := []byte("P<THASPECIMEN<<USER<<<<<<<<<<<<<<<<<<<<<<<<<")
	mrzLine2 := []byte("AA12345674THA9001015M3001013<<<<<<<<<<<<<<<0")
	dg1Data := append(dg1Prefix, append(mrzLine1, mrzLine2...)...)

	identity, err := parseDG1(dg1Data)
	if err != nil {
		t.Fatalf("unexpected error parsing valid DG1: %v", err)
	}

	if identity.DocumentNumber != "AA1234567" {
		t.Errorf("expected DocumentNumber 'AA1234567', got %q", identity.DocumentNumber)
	}
	if identity.Nationality != "THA" {
		t.Errorf("expected Nationality 'THA', got %q", identity.Nationality)
	}
	if identity.DateOfBirth != "900101" {
		t.Errorf("expected DateOfBirth '900101', got %q", identity.DateOfBirth)
	}
}

func TestVerifyPassportNfcSignature_MissingDG1(t *testing.T) {
	payload := NfcPassportPayload{
		DG1: []byte{},
	}
	_, err := VerifyPassportNfcSignature(payload)
	if err == nil {
		t.Fatal("expected error for empty DG1, got nil")
	}
}
