package queue

import (
	"encoding/json"
	"time"
)

// JobStatus represents the state of a job in the queue
type JobStatus string

const (
	StatusPending    JobStatus = "pending"
	StatusProcessing JobStatus = "processing"
	StatusCompleted  JobStatus = "completed"
	StatusFailed     JobStatus = "failed"
)

// Job maps to the public.jobs table in PostgreSQL
type Job struct {
	ID           string          `json:"id"` // UUID
	Type         string          `json:"type"`
	Payload      json.RawMessage `json:"payload"`
	Status       JobStatus       `json:"status"`
	ErrorMessage *string         `json:"error_message,omitempty"`
	CreatedAt    time.Time       `json:"created_at"`
	UpdatedAt    time.Time       `json:"updated_at"`
	LockedAt     *time.Time      `json:"locked_at,omitempty"`
}
