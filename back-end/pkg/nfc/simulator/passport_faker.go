package simulator

import (
	"crypto"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	"crypto/x509/pkix"
	"fmt"
	"math/big"
	"time"
)

// MockPassportData represents a synthetically correct e-Passport data structure.
type MockPassportData struct {
	DG1                []byte // MRZ Data
	DG2                []byte // Image Data (Photo)
	SOD                []byte // Security Object (Signed Hashes)
	DocumentSignerCert []byte // Certificate used to sign SOD
}

// GenerateMockPassport generates a validly signed, but synthetic, e-Passport for 10x TDD.
func GenerateMockPassport(nationality string, firstName string, lastName string) (*MockPassportData, error) {
	// 1. Generate MRZ and DG1
	mrzLines := GenerateTD3MRZ("P<", "THA", lastName, firstName, "AA1234567", nationality, "900101", "M", "300101")
	mrzText := fmt.Sprintf("%-44s\n%-44s", mrzLines[0], mrzLines[1])
	dg1 := []byte{0x61, byte(len(mrzText))} // TLV tag for DG1
	dg1 = append(dg1, mrzText...)

	// 2. Generate Synthetic DG2 (Mock Image)
	dg2 := []byte{0x75, 0x0A, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A}

	// 3. Create a Mock Document Signer (DS) Certificate
	privKey, _ := rsa.GenerateKey(rand.Reader, 2048)
	template := &x509.Certificate{
		SerialNumber: big.NewInt(time.Now().Unix()),
		Subject:      pkix.Name{CommonName: "Mock Passport Authority"},
		NotBefore:    time.Now().Add(-time.Hour),
		NotAfter:     time.Now().Add(time.Hour * 24 * 365),
		KeyUsage:     x509.KeyUsageDigitalSignature,
	}
	dsCertRaw, _ := x509.CreateCertificate(rand.Reader, template, template, &privKey.PublicKey, privKey)

	// 4. Create SOD (Simplistic Mock CMS)
	// In reality, SOD contains SHA256 hashes of all DGs.
	dg1Hash := sha256.Sum256(dg1)
	dg2Hash := sha256.Sum256(dg2)
	
	// Composite data to be signed
	content := append(dg1Hash[:], dg2Hash[:]...)
	signature, _ := rsa.SignPKCS1v15(rand.Reader, privKey, crypto.SHA256, content)
	
	// Fake SOD structure for the demo (normally ASN.1 CMS)
	sod := append([]byte("MOCK_SOD_CMS:"), signature...)

	return &MockPassportData{
		DG1:                dg1,
		DG2:                dg2,
		SOD:                sod,
		DocumentSignerCert: dsCertRaw,
	}, nil
}
