package usecase

import (
	"fmt"
	"strconv"
	"strings"
	"testing"

	"github.com/google/uuid"
)

func BenchmarkReconcilerDescription_Format(b *testing.B) {
	amount := int64(150000)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("Reconciled Deposit: %d satang", amount)
	}
}

func BenchmarkReconcilerDescription_Concat(b *testing.B) {
	amount := int64(150000)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = "Reconciled Deposit: " + strconv.FormatInt(amount, 10) + " satang"
	}
}

func BenchmarkReconcilerBatchQueryBuilding_Loop(b *testing.B) {
	intents := make([]PayoutIntent, 50)
	for i := 0; i < 50; i++ {
		intents[i] = PayoutIntent{ID: uuid.New()}
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		for _, intent := range intents {
			_ = fmt.Sprintf("UPDATE payout_intents SET status = 'RECONCILING' WHERE id = '%s'", intent.ID.String())
		}
	}
}

func BenchmarkReconcilerBatchQueryBuilding_ParameterizedIN(b *testing.B) {
	intents := make([]PayoutIntent, 50)
	for i := 0; i < 50; i++ {
		intents[i] = PayoutIntent{ID: uuid.New()}
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		placeholders := make([]string, len(intents))
		args := make([]interface{}, len(intents))
		for j, intent := range intents {
			placeholders[j] = "$" + strconv.Itoa(j+1)
			args[j] = intent.ID
		}
		_ = "UPDATE payout_intents SET status = 'RECONCILING' WHERE id IN (" + strings.Join(placeholders, ",") + ")"
		_ = args
	}
}
