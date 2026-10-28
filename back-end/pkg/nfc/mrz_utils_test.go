package nfc_test

import (
	"paysif/pkg/nfc"
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
		{"AB1234567<", 1},
		{"HA5432108<", 8},
		{"550101", 8},
	}

	for _, tt := range tests {
		got := nfc.CalculateMRZChecksum(tt.input)
		if got != tt.expected {
			t.Errorf("CalculateMRZChecksum(%q) = %d, want %d", tt.input, got, tt.expected)
		}
	}
}

func BenchmarkCalculateMRZChecksum(b *testing.B) {
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = nfc.CalculateMRZChecksum("L898902C3740812120415AB1234567")
	}
}
