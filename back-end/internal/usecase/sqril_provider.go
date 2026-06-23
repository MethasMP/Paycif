package usecase

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/sony/gobreaker"
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
	cb           *gobreaker.CircuitBreaker
}

func NewSqrilProvider(baseURL, clientID, clientSecret string) *SqrilProvider {
	cbSettings := gobreaker.Settings{
		Name:        "SQRILProviderBreaker",
		MaxRequests: 5,
		Interval:    60 * time.Second,
		Timeout:     30 * time.Second,
		ReadyToTrip: func(counts gobreaker.Counts) bool {
			failureRatio := float64(counts.TotalFailures) / float64(counts.Requests)
			return counts.Requests >= 3 && failureRatio >= 0.6
		},
	}
	return &SqrilProvider{
		BaseURL:      baseURL,
		ClientID:     clientID,
		ClientSecret: clientSecret,
		HTTPClient:   sqrilHTTPClient,
		cb:           gobreaker.NewCircuitBreaker(cbSettings),
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
	DepositAddress       string                   `json:"deposit_address,omitempty"`
	MissingFields        []map[string]interface{} `json:"missing_fields,omitempty"`
}

// DecodeQR invokes SQRIL /decodeQr
func (s *SqrilProvider) DecodeQR(ctx context.Context, qrString string, customerID string, partnerTxID string) (*DecodeQRResponse, error) {
	if s.ClientID == "mock-client-id" {
		amount := int64(1000) // Default 10.00 THB
		merchant := "Mock Merchant"
		if strings.Contains(qrString, "TESCO") {
			amount = 85
			merchant = "Tesco Lotus"
		} else if strings.Contains(qrString, "DONATION") {
			amount = 4300
			merchant = "UNICEF Donation"
		} else if strings.Contains(qrString, "103866388") || strings.HasPrefix(qrString, "0002010102113067") {
			amount = 300
			merchant = "CPF Store"
		} else if strings.Contains(qrString, "0105560010595") || strings.HasPrefix(qrString, "0002010102113070") {
			amount = 400
			merchant = "Smart Shop"
		} else if strings.Contains(qrString, "16260181X") {
			amount = 17822
			merchant = "Lim Shop"
		} else if strings.Contains(qrString, "S HOTEL") || strings.Contains(qrString, "6201.78") {
			amount = 178
			merchant = "S Hotel"
		} else if strings.Contains(qrString, "70000.00") {
			amount = 7000000
			merchant = "Lim Trend Emporium"
		}

		return &DecodeQRResponse{
			IsDynamic:            false,
			IsBusiness:           true,
			Amount:               amount,
			Merchant:             merchant,
			Country:              "TH",
			TxID:                 "mock_tx_" + partnerTxID,
			Currency:             "THB",
			PartnerTransactionID: partnerTxID,
			AmountUSD:            float64(amount) / 35.0 / 100.0,
			Fee:                  0.0,
		}, nil
	}

	result, err := s.cb.Execute(func() (interface{}, error) {
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
	})
	if err != nil {
		return nil, err
	}
	return result.(*DecodeQRResponse), nil
}

// GetQuotationResponse matches SQRIL /getQuotation response
type GetQuotationResponse struct {
	TxID           string    `json:"tx_id"`
	Amount         int64     `json:"amount"`
	Currency       string    `json:"currency"`
	ExchangeRate   float64   `json:"exchange_rate"`
	AmountUSD      float64   `json:"amount_usd"`
	Fee            float64   `json:"fee"`
	PercentageFee  float64   `json:"percentage_fee"`
	FixedFee       float64   `json:"fixed_fee"`
	ExpiresAt      time.Time `json:"expires_at"`
	DepositAddress string    `json:"deposit_address,omitempty"`
}

// GetQuotation invokes SQRIL /getQuotation
func (s *SqrilProvider) GetQuotation(ctx context.Context, txID string, customerID string, amount int64) (*GetQuotationResponse, error) {
	if s.ClientID == "mock-client-id" {
		finalAmt := amount
		if finalAmt <= 0 {
			finalAmt = 1000
		}
		return &GetQuotationResponse{
			TxID:         txID,
			Amount:       finalAmt,
			Currency:     "THB",
			ExchangeRate: 0.0285,
			AmountUSD:    float64(finalAmt) / 35.0 / 100.0,
			ExpiresAt:    time.Now().Add(10 * time.Minute),
		}, nil
	}

	result, err := s.cb.Execute(func() (interface{}, error) {
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
	})
	if err != nil {
		return nil, err
	}
	return result.(*GetQuotationResponse), nil
}

// Payout executes a payout using SQRIL /executePayout
func (s *SqrilProvider) Payout(ctx context.Context, amount int64, currency string, recipientID string, recipientName string, reference string, providerTxID string, customerID string) (*PayoutResult, error) {
	if s.ClientID == "mock-client-id" {
		return &PayoutResult{
			ExternalID: providerTxID,
			Status:     "SUCCESS",
			RawMessage: `{"status":"SUCCESS","message":"Mocked SQRIL Payout Successful"}`,
		}, nil
	}

	if providerTxID == "" {
		return nil, fmt.Errorf("providerTxID is required for sqril payout")
	}

	result, err := s.cb.Execute(func() (interface{}, error) {
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
	})
	if err != nil {
		return nil, err
	}
	return result.(*PayoutResult), nil
}
