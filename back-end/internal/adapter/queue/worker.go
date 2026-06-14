package queue

import (
	"context"
	"fmt"
	"log"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// JobProcessor defines the interface for handling different job types
type JobProcessor interface {
	Process(ctx context.Context, job *Job) error
}

// Worker represents the background worker process
type Worker struct {
	pool       *pgxpool.Pool
	processors map[string]JobProcessor
}

// NewWorker creates a new Worker instance
func NewWorker(pool *pgxpool.Pool) *Worker {
	return &Worker{
		pool:       pool,
		processors: make(map[string]JobProcessor),
	}
}

// Register assigns a processor logic to a specific job type
func (w *Worker) Register(jobType string, p JobProcessor) {
	w.processors[jobType] = p
}

// Start begins listening for new jobs and processing them
func (w *Worker) Start(ctx context.Context) {
	// Start the reclaimer routine to rescue stuck jobs
	go w.reclaimStuckJobs(ctx)

	// Keep trying to listen even if connection drops
	for {
		select {
		case <-ctx.Done():
			return
		default:
			if err := w.listenAndProcess(ctx); err != nil {
				log.Printf("Queue listener error: %v, reconnecting in 5s...", err)
				time.Sleep(5 * time.Second)
			}
		}
	}
}

// listenAndProcess connects to PostgreSQL and waits for NOTIFY signals
func (w *Worker) listenAndProcess(ctx context.Context) error {
	conn, err := w.pool.Acquire(ctx)
	if err != nil {
		return fmt.Errorf("failed to acquire connection for listening: %w", err)
	}
	defer conn.Release()

	_, err = conn.Exec(ctx, "LISTEN new_job_channel")
	if err != nil {
		return fmt.Errorf("failed to execute LISTEN: %w", err)
	}

	log.Println("Queue worker is listening for new jobs...")

	// Do an initial check just in case there are pending jobs
	w.processAvailableJobs(ctx)

	for {
		// Wait for notification
		notification, err := conn.Conn().WaitForNotification(ctx)
		if err != nil {
			return fmt.Errorf("error waiting for notification: %w", err)
		}

		log.Printf("Received notification for job type: %s", notification.Payload)
		w.processAvailableJobs(ctx)
	}
}

// processAvailableJobs attempts to dequeue and process jobs until none are left
func (w *Worker) processAvailableJobs(ctx context.Context) {
	for {
		job, err := w.dequeue(ctx)
		if err != nil {
			if err == pgx.ErrNoRows {
				// No more jobs available
				return
			}
			log.Printf("Error dequeuing job: %v", err)
			return
		}

		if job != nil {
			w.handleJob(ctx, job)
		} else {
			return
		}
	}
}

// dequeue locks a single job using SKIP LOCKED and returns it
func (w *Worker) dequeue(ctx context.Context) (*Job, error) {
	query := `
		UPDATE public.jobs
		SET status = 'processing', locked_at = now(), updated_at = now()
		WHERE id = (
			SELECT id FROM public.jobs
			WHERE status = 'pending'
			ORDER BY created_at ASC
			FOR UPDATE SKIP LOCKED
			LIMIT 1
		)
		RETURNING id, type, payload, status, error_message, created_at, updated_at, locked_at
	`

	var j Job
	err := w.pool.QueryRow(ctx, query).Scan(
		&j.ID, &j.Type, &j.Payload, &j.Status, &j.ErrorMessage, &j.CreatedAt, &j.UpdatedAt, &j.LockedAt,
	)

	if err != nil {
		return nil, err
	}
	return &j, nil
}

// handleJob executes the logic and updates status to completed or failed
func (w *Worker) handleJob(ctx context.Context, job *Job) {
	processor, ok := w.processors[job.Type]
	if !ok {
		w.markJobFailed(ctx, job.ID, fmt.Errorf("no processor registered for type: %s", job.Type))
		return
	}

	err := processor.Process(ctx, job)
	if err != nil {
		w.markJobFailed(ctx, job.ID, err)
		return
	}

	w.markJobCompleted(ctx, job.ID)
}

func (w *Worker) markJobCompleted(ctx context.Context, id string) {
	query := `UPDATE public.jobs SET status = 'completed', locked_at = NULL, updated_at = now() WHERE id = $1`
	_, err := w.pool.Exec(ctx, query, id)
	if err != nil {
		log.Printf("Failed to mark job %s as completed: %v", id, err)
	}
}

func (w *Worker) markJobFailed(ctx context.Context, id string, jobErr error) {
	query := `UPDATE public.jobs SET status = 'failed', error_message = $1, locked_at = NULL, updated_at = now() WHERE id = $2`
	_, err := w.pool.Exec(ctx, query, jobErr.Error(), id)
	if err != nil {
		log.Printf("Failed to mark job %s as failed: %v", id, err)
	}
}

// reclaimStuckJobs periodically checks for jobs stuck in processing status
func (w *Worker) reclaimStuckJobs(ctx context.Context) {
	ticker := time.NewTicker(5 * time.Minute)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			query := `
				UPDATE public.jobs
				SET status = 'pending', locked_at = NULL, updated_at = now()
				WHERE status = 'processing' 
				  AND locked_at < now() - interval '10 minutes'
			`
			tag, err := w.pool.Exec(ctx, query)
			if err != nil {
				log.Printf("Error reclaiming stuck jobs: %v", err)
				continue
			}
			if tag.RowsAffected() > 0 {
				log.Printf("Reclaimed %d stuck jobs", tag.RowsAffected())
				// Trigger processing for the reclaimed jobs
				w.processAvailableJobs(ctx)
			}
		}
	}
}
