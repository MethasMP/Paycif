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

	// 2. Persist the On-Ramp Customer ID in our DB
	_, err := s.DB.ExecContext(ctx, `
		INSERT INTO identity_verification (
			user_id, passport_number, full_name, nationality, 
			kyc_status, sumsub_applicant_id, updated_at
		)
		VALUES ($1, $2, $3, $4, 'PENDING_ONRAMP_VERIFICATION', $5, NOW())
		ON CONFLICT (user_id) DO UPDATE SET
			kyc_status = EXCLUDED.kyc_status,
			sumsub_applicant_id = EXCLUDED.sumsub_applicant_id,
			updated_at = NOW()
	`, dto.UserID, dto.PassportNumber, dto.FullName, dto.Nationality, onRampCustomerID)

	if err != nil {
		return "", fmt.Errorf("failed to register customer identity locally: %w", err)
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
		SELECT iv.kyc_status, p.kyc_tier, iv.updated_at, iv.verified_at
		FROM identity_verification iv
		JOIN profiles p ON iv.user_id = p.id
		WHERE iv.user_id = $1
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
	tx, err := s.DB.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	// 1. Update identity_verification status
	_, err = tx.ExecContext(ctx, `
		UPDATE identity_verification 
		SET kyc_status = $2, 
		    verified_at = CASE WHEN $2 = 'VERIFIED' THEN NOW() ELSE verified_at END,
		    updated_at = NOW()
		WHERE user_id = $1
	`, userID, status)
	if err != nil {
		return err
	}

	// 2. Update profile kyc_tier
	_, err = tx.ExecContext(ctx, `
		UPDATE profiles 
		SET kyc_tier = $2, 
		    updated_at = NOW()
		WHERE id = $1
	`, userID, tier)
	if err != nil {
		return err
	}

	if err := tx.Commit(); err != nil {
		return err
	}

	// 3. Log Audit
	s.Audit.Log(ctx, userID, "ONRAMP_KYC_SYNC_SUCCESS", "IDENTITY_VERIFICATION", userID.String(), map[string]interface{}{
		"status": status,
		"tier":   tier,
	})

	return nil
}
