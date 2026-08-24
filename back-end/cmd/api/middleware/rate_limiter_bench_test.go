package middleware

import (
	"fmt"
	"strconv"
	"testing"
	"time"
)

func BenchmarkKeyGenSprintf(b *testing.B) {
	identifier := "user_1234567890_test_key"
	currentMinute := time.Now().Unix() / 60
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("rate:%s:%d", identifier, currentMinute)
	}
}

func BenchmarkKeyGenConcat(b *testing.B) {
	identifier := "user_1234567890_test_key"
	currentMinute := time.Now().Unix() / 60
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = "rate:" + identifier + ":" + strconv.FormatInt(currentMinute, 10)
	}
}
