package usecase

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
)

// KYCService handles integration with the On-Ramp's KYC / Identity Verification flows.
type KYCService struct {
	DB    *sql.DB
	Audit *AuditService
}

// NewKYCService creates a new KYCService.
func NewKYCService(db *sql.DB, audit *AuditService) *KYCService {
	return &KYCService{
		DB:    db,
		Audit: audit,
	}
}

// OnRampCustomerDTO represents the customer details to register with the On-Ramp.
type OnRampCustomerDTO struct {
	UserID         uuid.UUID
	FullName       string
	PassportNumber string
	Nationality    string
}

// OnRampKycStatus holds verification status details from the On-Ramp.
type OnRampKycStatus struct {
	UserID      uuid.UUID `json:"user_id"`
	KycStatus   string    `json:"kyc_status"` // e.g. "UNVERIFIED", "PENDING", "VERIFIED"
	KycTier     string    `json:"kyc_tier"`   // e.g. "tier0", "tier1", "tier2"
	UpdatedAt   time.Time `json:"updated_at"`
	ConfirmedAt *time.Time `json:"confirmed_at,omitempty"`
}

// RegisterOnRampCustomer mocks the registration of a customer with Alchemy Pay / MoonPay delegated KYC.
func (s *KYCService) RegisterOnRampCustomer(ctx context.Context, dto OnRampCustomerDTO) (string, error) {
	// 1. Simulate API Call to On-Ramp Partner (e.g. Alchemy Pay POST /external/customer/register)
	// Alchemy Pay creates a profile mapping our userID to their KYC systems.
	onRampCustomerID := "onramp_cust_" + dto.UserID.String()

	// 2. Persist the On-Ramp Customer ID and last 4 of ID in our DB inside public.profiles
	res, err := s.DB.ExecContext(ctx, `
		UPDATE public.profiles
		SET kyc_status = 'PENDING_ONRAMP_VERIFICATION',
			external_customer_id = $2,
			full_name = COALESCE(NULLIF($3, ''), full_name),
			id_last_4 = RIGHT($4, 4),
			updated_at = NOW()
		WHERE id = $1
	`, dto.UserID, onRampCustomerID, dto.FullName, dto.PassportNumber)

	if err != nil {
		return "", fmt.Errorf("failed to register customer identity locally: %w", err)
	}

	rows, err := res.RowsAffected()
	if err == nil && rows == 0 {
		return "", fmt.Errorf("failed to register customer identity locally: profile not found")
	}

	// 3. Log Audit
	s.Audit.Log(ctx, dto.UserID, "ONRAMP_CUSTOMER_REGISTERED", "IDENTITY_VERIFICATION", dto.UserID.String(), map[string]interface{}{
		"onramp_customer_id": onRampCustomerID,
		"nationality":        dto.Nationality,
	})

	return onRampCustomerID, nil
}

// GetOnRampKycStatus retrieves verification status of the user.
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

// SyncOnRampKycStatus updates verification status received via On-Ramp Webhook / Webhook callback.
func (s *KYCService) SyncOnRampKycStatus(ctx context.Context, userID uuid.UUID, status string, tier string) error {
	_, err := s.DB.ExecContext(ctx, `
		UPDATE public.profiles
		SET kyc_status = $2,
			kyc_tier = $3,
			verified_at = CASE WHEN $2 = 'VERIFIED' THEN NOW() ELSE verified_at END,
			updated_at = NOW()
		WHERE id = $1
	`, userID, status, tier)
	if err != nil {
		return fmt.Errorf("failed to sync onramp KYC status: %w", err)
	}

	// Log Audit
	s.Audit.Log(ctx, userID, "ONRAMP_KYC_SYNC_SUCCESS", "IDENTITY_VERIFICATION", userID.String(), map[string]interface{}{
		"status": status,
		"tier":   tier,
	})

	return nil
}
