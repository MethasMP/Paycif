package nfc

// CalculateMRZChecksum calculates the check digit for a string according to ICAO 9303 standards.
// It uses the 7-3-1 weighting system.
func CalculateMRZChecksum(data string) int {
	weights := [3]int{7, 3, 1}
	sum := 0

	for i, char := range data {
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
