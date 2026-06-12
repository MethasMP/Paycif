package queue

import (
	"context"
	"testing"
)

type MockProcessor struct {
	Called bool
}

func (m *MockProcessor) Process(ctx context.Context, job *Job) error {
	m.Called = true
	return nil
}

func TestWorker_Register(t *testing.T) {
	w := &Worker{
		processors: make(map[string]JobProcessor),
	}

	p := &MockProcessor{}
	w.Register("test_job", p)

	if len(w.processors) != 1 {
		t.Errorf("Expected 1 processor, got %d", len(w.processors))
	}
}
