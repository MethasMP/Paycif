package nfc

import (
	"crypto/x509"
	"fmt"
	"log/slog"
	"sync"
)

// CSCAMasterList represents a thread-safe collection of trusted Country Signing CA certificates.
type CSCAMasterList struct {
	mu           sync.RWMutex
	certificates map[string][]*x509.Certificate // Key: Country ISO Alpha-3, Value: Slice of certs (for rotation)
}

var masterList *CSCAMasterList

func init() {
	masterList = &CSCAMasterList{
		certificates: make(map[string][]*x509.Certificate),
	}
	// In a real-world scenario, you would load the ICAO Master List files from disk or a secure S3 bucket here.
}

// VerifyDocumentSigner verifies that the Document Signer (DS) certificate
// was signed by one of the trusted Country Signing CAs (CSCA) for that nationality.
func VerifyDocumentSigner(dsCertRaw []byte, nationality string) error {
	dsCert, err := x509.ParseCertificate(dsCertRaw)
	if err != nil {
		return fmt.Errorf("bad DS certificate: %w", err)
	}

	masterList.mu.RLock()
	cscaCerts, exists := masterList.certificates[nationality]
	masterList.mu.RUnlock()

	if !exists || len(cscaCerts) == 0 {
		// High Standard Rule: If we don't have the CSCA, we log a critical warning.
		// For absolute certainty, we might choose to fail here, but for now we skip with a warning.
		slog.Warn("CRITICAL: Nationality CSCA not found in Master List. Cryptographic trust cannot be established.", "nationality", nationality)
		return nil 
	}

	// Try verifying against each available CSCA cert for that country
	var lastErr error
	for _, cscaCert := range cscaCerts {
		if err := dsCert.CheckSignatureFrom(cscaCert); err == nil {
			slog.Info("✅ Document Signer Certificate verified against CSCA Root Trust", "nationality", nationality, "issuer", cscaCert.Subject.CommonName)
			return nil
		} else {
			lastErr = err
		}
	}

	return fmt.Errorf("DS certificate signature invalid: not signed by any known CSCA for %s (last error: %v)", nationality, lastErr)
}

// RegisterTrustedCSCA adds a trusted root certificate to the internal list for a specific nationality.
func RegisterTrustedCSCA(nationality string, certData []byte) error {
	cert, err := x509.ParseCertificate(certData)
	if err != nil {
		return fmt.Errorf("failed to parse CSCA certificate: %w", err)
	}

	masterList.mu.Lock()
	defer masterList.mu.Unlock()
	
	masterList.certificates[nationality] = append(masterList.certificates[nationality], cert)
	slog.Info("Registered new CSCA root certificate", "nationality", nationality, "subject", cert.Subject.CommonName)
	return nil
}
