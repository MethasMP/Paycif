package nfc

import (
	"crypto"
	"crypto/ecdsa"
	"crypto/rsa"
	"crypto/sha256"
	"fmt"
)

// VerifyActiveAuthentication ตรวจสอบว่าชิปเล่มนี้ไม่ได้ถูก Clone มา
// โดยการตรวจสอบ Digital Signature ที่ชิปสร้างจาก Challenge
// รองรับทั้ง RSA และ ECDSA ตามมาตรฐานสากล
func VerifyActiveAuthentication(publicKey crypto.PublicKey, challenge []byte, signature []byte) (bool, error) {
	hashed := sha256.Sum256(challenge)

	switch pub := publicKey.(type) {
	case *rsa.PublicKey:
		err := rsa.VerifyPKCS1v15(pub, crypto.SHA256, hashed[:], signature)
		if err != nil {
			return false, fmt.Errorf("AA RSA verification failed: %v", err)
		}
		return true, nil
	case *ecdsa.PublicKey:
		// Note: Standard ECDSA signatures are expected to be ASN.1/DER encoded by most smart card systems
		valid := ecdsa.VerifyASN1(pub, hashed[:], signature)
		if !valid {
			return false, fmt.Errorf("AA ECDSA verification failed: signature mismatch")
		}
		return true, nil
	default:
		return false, fmt.Errorf("unsupported public key type for Global Standard KYC: %T", pub)
	}
}
