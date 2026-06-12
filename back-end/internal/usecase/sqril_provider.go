package usecase

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

var sqrilHTTPClient = &http.Client{
	Timeout: 15 * time.Second,
	Transport: &http.Transport{
		MaxIdleConns:        100,
		MaxIdleConnsPerHost: 20,
		IdleConnTimeout:     90 * time.Second,
	},
}

type SqrilProvider struct {
	BaseURL      string
	ClientID     string
	ClientSecret string
	HTTPClient   *http.Client
}

func NewSqrilProvider(baseURL, clientID, clientSecret string) *SqrilProvider {
	return &SqrilProvider{
		BaseURL:      baseURL,
		ClientID:     clientID,
		ClientSecret: clientSecret,
		HTTPClient:   sqrilHTTPClient,
	}
}

func (s *SqrilProvider) GetName() string { return "sqril" }

// SQRIL Basic Auth helper
func (s *SqrilProvider) addAuthHeader(req *http.Request) {
	auth := s.ClientID + ":" + s.ClientSecret
	hash := base64.StdEncoding.EncodeToString([]byte(auth))
	req.Header.Add("Authorization", "Basic "+hash)
}

// DecodeQRResponse matches the SQRIL decodeQr response schema
type DecodeQRResponse struct {
	IsDynamic            bool                     `json:"is_dynamic"`
	IsBusiness           bool                     `json:"is_business"`
	Amount               int64                    `json:"amount"`
	Merchant             string                   `json:"merchant"`
	Country              string                   `json:"country"`
	TxID                 string                   `json:"tx_id"`
	Currency             string                   `json:"currency"`
	PartnerTransactionID string                   `json:"partner_transaction_id"`
	AmountUSD            float64                  `json:"amount_usd"`
	Fee                  float64                  `json:"fee"`
	PercentageFee        float64                  `json:"percentage_fee"`
	FixedFee             float64                  `json:"fixed_fee"`
	MissingFields        []map[string]interface{} `json:"missing_fields,omitempty"`
}

// DecodeQR invokes SQRIL /decodeQr
func (s *SqrilProvider) DecodeQR(ctx context.Context, qrString string, customerID string, partnerTxID string) (*DecodeQRResponse, error) {
	url := s.BaseURL + "/decodeQr"
	reqBody, err := json.Marshal(map[string]string{
		"qr_string":              qrString,
		"customer_id":            customerID,
		"payment_currency":       "THB",
		"partner_transaction_id": partnerTxID,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to marshal decode request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewBuffer(reqBody))
	if err != nil {
		return nil, fmt.Errorf("failed to create decode request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	s.addAuthHeader(req)

	resp, err := s.HTTPClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("decode request failed: %w", err)
	}
	defer resp.Body.Close()

	bodyBytes, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("decode returned status %d: %s", resp.StatusCode, string(bodyBytes))
	}

	var decodeResp DecodeQRResponse
	if err := json.Unmarshal(bodyBytes, &decodeResp); err != nil {
		return nil, fmt.Errorf("failed to parse decode response: %w", err)
	}

	return &decodeResp, nil
}

// GetQuotationResponse matches SQRIL /getQuotation response
type GetQuotationResponse struct {
	TxID          string    `json:"tx_id"`
	Amount        int64     `json:"amount"`
	Currency      string    `json:"currency"`
	ExchangeRate  float64   `json:"exchange_rate"`
	AmountUSD     float64   `json:"amount_usd"`
	Fee           float64   `json:"fee"`
	PercentageFee float64   `json:"percentage_fee"`
	FixedFee      float64   `json:"fixed_fee"`
	ExpiresAt     time.Time `json:"expires_at"`
}

// GetQuotation invokes SQRIL /getQuotation
func (s *SqrilProvider) GetQuotation(ctx context.Context, txID string, customerID string, amount int64) (*GetQuotationResponse, error) {
	url := s.BaseURL + "/getQuotation"
	bodyMap := map[string]interface{}{
		"tx_id":       txID,
		"customer_id": customerID,
	}
	if amount > 0 {
		bodyMap["amount"] = amount
	}

	reqBody, err := json.Marshal(bodyMap)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal quote request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewBuffer(reqBody))
	if err != nil {
		return nil, fmt.Errorf("failed to create quote request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	s.addAuthHeader(req)

	resp, err := s.HTTPClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("quote request failed: %w", err)
	}
	defer resp.Body.Close()

	bodyBytes, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("quote returned status %d: %s", resp.StatusCode, string(bodyBytes))
	}

	var quoteResp GetQuotationResponse
	if err := json.Unmarshal(bodyBytes, &quoteResp); err != nil {
		return nil, fmt.Errorf("failed to parse quote response: %w", err)
	}

	return &quoteResp, nil
}

// Payout executes a payout using SQRIL /executePayout
func (s *SqrilProvider) Payout(ctx context.Context, amount int64, currency string, recipientID string, recipientName string, reference string, providerTxID string, customerID string) (*PayoutResult, error) {
	if providerTxID == "" {
		return nil, fmt.Errorf("providerTxID is required for sqril payout")
	}

	// Call SQRIL /executePayout
	url := s.BaseURL + "/executePayout"
	reqBody, err := json.Marshal(map[string]interface{}{
		"tx_id":            providerTxID,
		"customer_id":      customerID,
		"amount_confirmed": amount,
		"currency":         currency,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to marshal execute request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewBuffer(reqBody))
	if err != nil {
		return nil, fmt.Errorf("failed to create execute request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Idempotency-Key", reference)
	s.addAuthHeader(req)

	resp, err := s.HTTPClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("execute payout request failed: %w", err)
	}
	defer resp.Body.Close()

	bodyBytes, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusAccepted && resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("execute payout returned status %d: %s", resp.StatusCode, string(bodyBytes))
	}

	var executeResp map[string]interface{}
	_ = json.Unmarshal(bodyBytes, &executeResp)

	statusStr, _ := executeResp["status"].(string)
	if statusStr == "" {
		statusStr = "PROCESSING"
	}

	return &PayoutResult{
		ExternalID: providerTxID,
		Status:     statusStr,
		RawMessage: string(bodyBytes),
	}, nil
}
