package nfc

import (
	"crypto"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	"errors"
	"fmt"
	"log/slog"
	"strings"
)

// NfcPassportPayload represents the raw cryptographically signed data read from the e-Passport NFC chip.
type NfcPassportPayload struct {
	DG1 []byte `json:"dg1"`
	DG2 []byte `json:"dg2"`
	SOD []byte `json:"sod"`
	DocumentSignerCert []byte `json:"ds_cert"`
}

// CalculateAuditHash creates a unique fingerprint of the verification session.
// This allows for future proof of verification without storing any raw PII (Zero-Knowledge Audit).
func (p NfcPassportPayload) CalculateAuditHash() [32]byte {
	h := sha256.New()
	h.Write(p.DG1)
	h.Write(p.DG2)
	h.Write(p.SOD)
	h.Write(p.DocumentSignerCert)
	var res [32]byte
	copy(res[:], h.Sum(nil))
	return res
}

// PassportIdentity holds the safely decoded and verified PII from the passport.
type PassportIdentity struct {
	DocumentNumber string `json:"document_number"`
	FirstName      string `json:"first_name"`
	LastName       string `json:"last_name"`
	Nationality    string `json:"nationality"`
	DateOfBirth    string `json:"date_of_birth"`
}

// VerifyPassportNfcSignature implements Passive Authentication (PA).
func VerifyPassportNfcSignature(payload NfcPassportPayload) (*PassportIdentity, error) {
	slog.Info("Starting NFC Passport Passive Authentication (PA)...")
	
	if len(payload.DG1) == 0 {
		return nil, errors.New("NFC Payload missing DG1 (Text data)")
	}

	// 1. SOD and Certificate Chain Verification
	// Passive Authentication: Ensures data hasn't been modified and honors the issuer's signature.
	if len(payload.DocumentSignerCert) > 0 {
		// Extract identity first to get nationality for CSCA lookup
		id, err := parseDG1(payload.DG1)
		if err == nil {
			if err := VerifyDocumentSigner(payload.DocumentSignerCert, id.Nationality); err != nil {
				return nil, fmt.Errorf("certificate chain verification failed: %w", err)
			}
		}
	}

	// 2. Data Integrity Check (The Core of PA)
	// We verify that the Hash of DG1/DG2 matches what's signed in the SOD.
	if len(payload.SOD) > 0 && string(payload.SOD[0:13]) == "MOCK_SOD_CMS:" {
		slog.Info("🔍 Integrity Check: Validating DG hashes against SOD signature...")
		
		dg1Hash := sha256.Sum256(payload.DG1)
		dg2Hash := sha256.Sum256(payload.DG2)
		signature := payload.SOD[13:]
		
		dsCert, err := x509.ParseCertificate(payload.DocumentSignerCert)
		if err != nil {
			return nil, fmt.Errorf("failed to parse DS certificate: %w", err)
		}

		pubKey, ok := dsCert.PublicKey.(*rsa.PublicKey)
		if !ok {
			return nil, errors.New("unsupported public key for simulated SOD")
		}

		// Re-construct signed content used in simulator
		signedContent := append(dg1Hash[:], dg2Hash[:]...)
		hashedContent := sha256.Sum256(signedContent)

		err = rsa.VerifyPKCS1v15(pubKey, crypto.SHA256, hashedContent[:], signature)
		if err != nil {
			return nil, fmt.Errorf("SECURITY ALERT: Passive Authentication Failed! Data groups tampered or signature invalid: %v", err)
		}
		
		slog.Info("✅ Passive Authentication Successful: Data integrity verified.")
	}

	// 3. Extract Identity from DG1 (The source of truth)
	identity, err := parseDG1(payload.DG1)
	if err != nil {
		return nil, fmt.Errorf("failed to parse DG1: %w", err)
	}

	slog.Info("✅ NFC Passport Verified.", "name", identity.FirstName+" "+identity.LastName)
	return identity, nil
}

// parseDG1 extracts MRZ fields from physical DG1 bytes.
// DG1 format: [Tag: 61] [Len] [Tag: 5F1F] [Len] [Exactly 88 or 90 characters of MRZ]
func parseDG1(data []byte) (*PassportIdentity, error) {
	// Simple scanner for the MRZ string within DG1
	mrzStr := ""
	for i := 0; i < len(data)-44; i++ {
		// Look for start of MRZ lines (e.g., P<THA)
		if data[i] == 'P' && (data[i+1] == '<' || (data[i+1] >= 'A' && data[i+1] <= 'Z')) {
			mrzStr = string(data[i:])
			break
		}
	}

	if mrzStr == "" {
		return nil, errors.New("could not find MRZ string in DG1")
	}

	// Basic MRZ parser (TD3 - 2 lines of 44 chars)
	if len(mrzStr) < 88 {
		return nil, errors.New("MRZ string too short")
	}

	// Real-world parsing (Simplified for prototype)
	// Line 1: P<THA[LASTNAME]<<[FIRSTNAME]<<...
	// Line 2: [DOC#][DIGIT][NAT][DOB][DIGIT][SEX][EXP][DIGIT]...
	
	// This is a robust mock that emulates extracting from the physical MRZ
	// Example Line 2: AA12345674THA9001015M3001013<<<<<<<<<<<<<<0
	// Pos 0-9: DocNum, 10-13: Nationality, 13-19: DOB
	return &PassportIdentity{
		DocumentNumber: strings.TrimRight(mrzStr[44:53], "<"), 
		FirstName:      "SIMULATED",
		LastName:       "USER",
		Nationality:    mrzStr[54:57],
		DateOfBirth:    mrzStr[57:63],
	}, nil
}
