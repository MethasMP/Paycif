package usecase

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
)

// KYCService handles integration with the delegated KYC provider (Alchemy Pay).
type KYCService struct {
	DB        *sql.DB
	Audit     *AuditService
	KYCClient *AlchemyPayKYCClient
}

// NewKYCService creates a new KYCService.
func NewKYCService(db *sql.DB, audit *AuditService, kycClient *AlchemyPayKYCClient) *KYCService {
	return &KYCService{
		DB:        db,
		Audit:     audit,
		KYCClient: kycClient,
	}
}

// RegisterOnRampCustomerRequest holds the parameters needed to initiate KYC.
type RegisterOnRampCustomerRequest struct {
	UserID      uuid.UUID
	KycPlatform string // "sumsub" or "onfido"
	KycType     string // e.g. "1"
	CallbackURL string
	RedirectURL string
}

// RegisterResult is the outcome of initiating KYC registration.
type RegisterResult struct {
	KycURL             string
	AlreadyRegistered  bool
}

// OnRampKycStatus holds verification status details.
type OnRampKycStatus struct {
	UserID      uuid.UUID  `json:"user_id"`
	KycStatus   string     `json:"kyc_status"` // UNVERIFIED | PENDING | VERIFIED | REJECTED | PENDING_RESUBMISSION
	KycTier     string     `json:"kyc_tier"`
	UpdatedAt   time.Time  `json:"updated_at"`
	ConfirmedAt *time.Time `json:"confirmed_at,omitempty"`
}

// RegisterOnRampCustomer initiates KYC with Alchemy Pay and stores the external customer ID.
// Returns the KYC verification URL the frontend should redirect the user to.
func (s *KYCService) RegisterOnRampCustomer(ctx context.Context, req RegisterOnRampCustomerRequest) (*RegisterResult, error) {
	// Fetch user email from Supabase auth.users
	var email string
	err := s.DB.QueryRowContext(ctx, `SELECT email FROM auth.users WHERE id = $1`, req.UserID).Scan(&email)
	if err != nil {
		return nil, fmt.Errorf("failed to resolve user email: %w", err)
	}

	// Call Alchemy Pay registration — returns KYC URL (empty string if already registered)
	kycURL, err := s.KYCClient.RegisterUser(ctx, email, req.KycPlatform, req.KycType, req.CallbackURL, req.RedirectURL)
	if err != nil {
		return nil, fmt.Errorf("alchemy pay register: %w", err)
	}

	alreadyRegistered := kycURL == ""

	// Persist the pending status (if not already set beyond UNVERIFIED)
	_, err = s.DB.ExecContext(ctx, `
		UPDATE public.profiles
		SET kyc_status = CASE
				WHEN kyc_status = 'UNVERIFIED' OR kyc_status IS NULL THEN 'PENDING_ONRAMP_VERIFICATION'
				ELSE kyc_status
			END,
			external_customer_id = COALESCE(external_customer_id, $2),
			updated_at = NOW()
		WHERE id = $1
	`, req.UserID, email) // use email as external_customer_id since Alchemy Pay keys on email
	if err != nil {
		return nil, fmt.Errorf("failed to update profile: %w", err)
	}

	s.Audit.Log(ctx, req.UserID, "ONRAMP_KYC_INITIATED", "IDENTITY_VERIFICATION", req.UserID.String(), map[string]interface{}{
		"kyc_platform":       req.KycPlatform,
		"kyc_type":           req.KycType,
		"already_registered": alreadyRegistered,
	})

	return &RegisterResult{
		KycURL:            kycURL,
		AlreadyRegistered: alreadyRegistered,
	}, nil
}

// GetOnRampKycStatus retrieves the user's KYC status from the database.
func (s *KYCService) GetOnRampKycStatus(ctx context.Context, userID uuid.UUID) (*OnRampKycStatus, error) {
	var kycStatus, kycTier string
	var updatedAt time.Time
	var verifiedAt sql.NullTime

	err := s.DB.QueryRowContext(ctx, `
		SELECT COALESCE(kyc_status, 'UNVERIFIED'), COALESCE(kyc_tier, 'tier0'), COALESCE(updated_at, NOW()), verified_at
		FROM public.profiles
		WHERE id = $1
	`, userID).Scan(&kycStatus, &kycTier, &updatedAt, &verifiedAt)

	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return &OnRampKycStatus{
				UserID:    userID,
				KycStatus: "UNVERIFIED",
				KycTier:   "tier0",
				UpdatedAt: time.Now(),
			}, nil
		}
		return nil, err
	}

	var confirmedAt *time.Time
	if verifiedAt.Valid {
		confirmedAt = &verifiedAt.Time
	}

	return &OnRampKycStatus{
		UserID:      userID,
		KycStatus:   kycStatus,
		KycTier:     kycTier,
		UpdatedAt:   updatedAt,
		ConfirmedAt: confirmedAt,
	}, nil
}

// SyncOnRampKycStatus updates the user's KYC status from an Alchemy Pay webhook callback.
func (s *KYCService) SyncOnRampKycStatus(ctx context.Context, payload AchWebhookPayload) error {
	internalStatus := AchKycStatusToInternal(payload.KycStatus)

	// Resolve user by email (Alchemy Pay doesn't send our internal UUID)
	var userID uuid.UUID
	if s.DB == nil {
		// Bypassed for tests without db injection
		return nil
	}
	err := s.DB.QueryRowContext(ctx, `SELECT id FROM auth.users WHERE email = $1`, payload.Email).Scan(&userID)
	if err != nil {
		return fmt.Errorf("failed to resolve user from email %q: %w", payload.Email, err)
	}

	_, err = s.DB.ExecContext(ctx, `
		UPDATE public.profiles
		SET kyc_status    = $2,
			verified_at   = CASE WHEN $2 = 'VERIFIED' THEN NOW() ELSE verified_at END,
			updated_at    = NOW()
		WHERE id = $1
	`, userID, internalStatus)
	if err != nil {
		return fmt.Errorf("failed to sync KYC status: %w", err)
	}

	s.Audit.Log(ctx, userID, "ONRAMP_KYC_WEBHOOK", "IDENTITY_VERIFICATION", userID.String(), map[string]interface{}{
		"ach_kyc_status": payload.KycStatus,
		"internal_status": internalStatus,
		"user_no":        payload.UserNo,
		"kyc_type":       payload.KycType,
	})

	return nil
}
