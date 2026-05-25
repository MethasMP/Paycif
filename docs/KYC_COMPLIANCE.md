# KYC Compliance Audit: Paycif NFC e-Passport System

This document outlines how the Paycif identity verification system aligns with the **Bank of
Thailand (BOT)** and international standards for digital identity assurance (IAL).

## 1. Identity Assurance Level (IAL)

Based on ETDA (Electronic Transactions Development Agency) standards adopted by BOT:

| Level       | Requirement                       | Paycif Implementation                                                |
| ----------- | --------------------------------- | -------------------------------------------------------------------- |
| **IAL 1.1** | No evidence required              | N/A                                                                  |
| **IAL 2.2** | Physical ID evidence needed       | Handled via MRZ OCR scan.                                            |
| **IAL 2.3** | **Strong cryptographic evidence** | **ACHIEVED** via NFC Passport Chip reading (Passive Authentication). |

## 2. Technical Security Layers

### A. Document Integrity (Passive Authentication)

- **Standard**: ICAO Doc 9303.
- **Implementation**: The backend verifies the `SOD` (Security Object Document) using the Document
  Signer (`DS`) certificate.
- **Trust Root**: Certificates are validated against the **ICAO Master List** (CSCA).
- **Benefit**: Ensures that the data (Name, Date of Birth, Photo) inside the chip was digitally
  signed by a sovereign government and has not been tampered with.

### B. Anti-Cloning (Active Authentication)

- **Implementation**: The system performs an internal challenge-response with the Secure Element
  (SE) of the passport chip.
- **Benefit**: Prevents attackers from copying original data onto a blank NFC chip or emulator.

### C. Live Person Verification (Liveness Detection)

- **Standard**: ISO/IEC 30107 (PAD - Presentation Attack Detection).
- **Implementation**: Challenge-Response (Blink/Smile) + Biometric Face Matching.
- **Benefit**: Ensures the person presenting the document is the legitimate owner and is physically
  present (prevents photo/video replay attacks).

### D. Cryptographic Data Binding (Leakage Prevention)

- **Mechanism**: Dynamic Session Binding.
- **Implementation**: The system generates a one-time `VerificationSessionID` after successful NFC
  authentication. This ID is cryptographically linked to the `Selfie` payload.
- **Benefit**: Prevents **"Injection Attacks"** or **"KYC Replay"** where an attacker uses valid NFC
  data from one person and a fake selfie from another. The backend only matches biometrics against
  the specific, signed `DG2` image that was just verified in the same session.

## 3. Data Protection & Compliance

- **Encryption**: All PII (Personally Identifiable Information) captured is encrypted using
  **AES-256-GCM** before storage.
- **Privacy**: The system only extracts necessary data groups (`DG1` for ID info, `DG2` for
  biometrics) as per purpose-limitation principles.
- **Audit Logs**: Comprehensive logging of verification events (success/failure reason) is
  maintained for regulatory review.

## 4. Conclusion

Paycif exceeds the minimum requirements for fintech KYC in Thailand by utilizing NFC technology,
providing a "high" confidence level for digital on-boarding that is significantly more secure than
traditional camera-based ID card scanning.
