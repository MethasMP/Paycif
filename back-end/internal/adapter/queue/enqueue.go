package queue

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"
)

// EnqueueClient handles pushing new jobs to the queue
type EnqueueClient struct {
	pool *pgxpool.Pool
}

// NewEnqueueClient creates a new client
func NewEnqueueClient(pool *pgxpool.Pool) *EnqueueClient {
	return &EnqueueClient{pool: pool}
}

// Enqueue adds a new job to the PostgreSQL queue
func (c *EnqueueClient) Enqueue(ctx context.Context, jobType string, payload any) (string, error) {
	b, err := json.Marshal(payload)
	if err != nil {
		return "", fmt.Errorf("failed to marshal payload: %w", err)
	}

	var jobID string
	query := `
		INSERT INTO public.jobs (type, payload, status)
		VALUES ($1, $2, 'pending')
		RETURNING id
	`
	err = c.pool.QueryRow(ctx, query, jobType, b).Scan(&jobID)
	if err != nil {
		return "", fmt.Errorf("failed to enqueue job: %w", err)
	}

	return jobID, nil
}
