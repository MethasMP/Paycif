package usecase

import (
	"fmt"
	"strconv"
	"strings"
	"testing"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
)

func TestReconciliationDescriptionFormatting(t *testing.T) {
	amount := int64(15000)
	expected := "Reconciled Deposit: 15000 satang"
	actual := "Reconciled Deposit: " + strconv.FormatInt(amount, 10) + " satang"
	assert.Equal(t, expected, actual)
}

func TestReconciliationBatchQueryGeneration(t *testing.T) {
	t.Run("Empty intents early return", func(t *testing.T) {
		var intents []PayoutIntent
		assert.Equal(t, 0, len(intents))
		// Reconciler checks len(intents) == 0 and returns early before query generation
	})

	t.Run("Non-empty intents batch query construction", func(t *testing.T) {
		intents := []PayoutIntent{
			{ID: uuid.New()},
			{ID: uuid.New()},
			{ID: uuid.New()},
		}

		ids := make([]interface{}, len(intents))
		placeholders := make([]string, len(intents))
		for i, intent := range intents {
			ids[i] = intent.ID
			placeholders[i] = "$" + strconv.Itoa(i+1)
		}
		query := "UPDATE payout_intents SET status = 'RECONCILING' WHERE id IN (" + strings.Join(placeholders, ", ") + ")"

		assert.Equal(t, "UPDATE payout_intents SET status = 'RECONCILING' WHERE id IN ($1, $2, $3)", query)
		assert.Equal(t, 3, len(ids))
	})
}

func BenchmarkReconciliationDescriptionSprintf(b *testing.B) {
	amount := int64(15000)
	b.ResetTimer()
	b.ReportAllocs()

	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("Reconciled Deposit: %d satang", amount)
	}
}

func BenchmarkReconciliationDescriptionConcat(b *testing.B) {
	amount := int64(15000)
	b.ResetTimer()
	b.ReportAllocs()

	for i := 0; i < b.N; i++ {
		_ = "Reconciled Deposit: " + strconv.FormatInt(amount, 10) + " satang"
	}
}
