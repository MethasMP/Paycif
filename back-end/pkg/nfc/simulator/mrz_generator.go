package simulator

import (
	"fmt"
	"paysif/pkg/nfc"
	"strings"
)

// GenerateTD3MRZ creates a valid 2-line MRZ for a typical Passport (TD3 format).
// Line 1: P<COUNTRY<<LASTNAME<<FIRSTNAME<<<<<<<
// Line 2: DOCNUMBER<CHECK COUNTRY DOB<CHECK SEX EXP<CHECK S-CHECK
func GenerateTD3MRZ(docType, country, lastName, firstName, docNum, nationality, dob, sex, expiry string) []string {
	// Padding and formatting
	line1Prefix := fmt.Sprintf("%-2s%-3s", docType, country)
	names := fmt.Sprintf("%s<<%s", strings.ToUpper(lastName), strings.ToUpper(firstName))
	line1 := fmt.Sprintf("%s%-39s", line1Prefix, names)
	line1 = strings.ReplaceAll(line1, " ", "<")[:44]

	// Line 2 data with checksums
	c1 := nfc.CalculateMRZChecksum(docNum)
	c2 := nfc.CalculateMRZChecksum(dob)
	c3 := nfc.CalculateMRZChecksum(expiry)
	
	// Final composite checksum (all numeric parts)
	compositeSource := fmt.Sprintf("%s%d%s%d%s%d", docNum, c1, dob, c2, expiry, c3)
	cOrg := nfc.CalculateMRZChecksum(compositeSource)

	line2 := fmt.Sprintf("%-9s%d%-3s%-6s%d%-1s%-6s%d%-14s%d", 
		docNum, c1, nationality, dob, c2, sex, expiry, c3, "", cOrg)
	line2 = strings.ReplaceAll(line2, " ", "<")[:44]

	return []string{line1, line2}
}
