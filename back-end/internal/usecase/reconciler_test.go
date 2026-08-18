package usecase

import (
	"fmt"
	"strconv"
	"strings"
	"testing"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
)

func TestReconciler_DescriptionFormatting(t *testing.T) {
	amount := int64(15000)
	// Direct string concatenation
	desc := "Reconciled Deposit: " + strconv.FormatInt(amount, 10) + " satang"
	expected := fmt.Sprintf("Reconciled Deposit: %d satang", amount)

	assert.Equal(t, expected, desc)
}

func BenchmarkReconciler_DescriptionFormatting_Concatenation(b *testing.B) {
	amount := int64(15000)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = "Reconciled Deposit: " + strconv.FormatInt(amount, 10) + " satang"
	}
}

func BenchmarkReconciler_DescriptionFormatting_Sprintf(b *testing.B) {
	amount := int64(15000)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("Reconciled Deposit: %d satang", amount)
	}
}

func TestReconciler_BatchQueryConstruction(t *testing.T) {
	id1 := uuid.New()
	id2 := uuid.New()
	id3 := uuid.New()
	intents := []PayoutIntent{
		{ID: id1},
		{ID: id2},
		{ID: id3},
	}

	placeholders := make([]string, len(intents))
	args := make([]interface{}, len(intents))
	for i, intent := range intents {
		placeholders[i] = "$" + strconv.Itoa(i+1)
		args[i] = intent.ID
	}
	batchQuery := "UPDATE payout_intents SET status = 'RECONCILING' WHERE id IN (" + strings.Join(placeholders, ", ") + ")"

	assert.Equal(t, "UPDATE payout_intents SET status = 'RECONCILING' WHERE id IN ($1, $2, $3)", batchQuery)
	assert.Len(t, args, 3)
	assert.Equal(t, id1, args[0])
	assert.Equal(t, id2, args[1])
	assert.Equal(t, id3, args[2])
}
