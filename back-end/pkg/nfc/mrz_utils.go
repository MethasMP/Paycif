package nfc

// CalculateMRZChecksum calculates the check digit for a string according to ICAO 9303 standards.
// It uses the 7-3-1 weighting system.
func CalculateMRZChecksum(data string) int {
	weights := [3]int{7, 3, 1}
	sum := 0

	// Optimize: iterate byte-by-byte over ASCII string instead of UTF-8 rune decoding
	for i := 0; i < len(data); i++ {
		char := data[i]
		var val int
		switch {
		case char >= '0' && char <= '9':
			val = int(char - '0')
		case char >= 'A' && char <= 'Z':
			val = int(char - 'A' + 10)
		default:
			// '<' and other fillers are 0
			val = 0
		}

		sum += val * weights[i%3]
	}

	return sum % 10
}
