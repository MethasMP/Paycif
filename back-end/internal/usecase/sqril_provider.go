package usecase

import (
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"crypto/subtle"
	"database/sql"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"regexp"
	"strings"
	"time"

	"github.com/google/uuid"
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
	DB           *sql.DB
}

func NewSqrilProvider(baseURL, clientID, clientSecret string, db *sql.DB) *SqrilProvider {
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
		DB:           db,
	}
}

func (s *SqrilProvider) GetName() string { return "sqril" }

// SQRIL Basic Auth helper
func (s *SqrilProvider) addAuthHeader(req *http.Request) {
	auth := s.ClientID + ":" + s.ClientSecret
	hash := base64.StdEncoding.EncodeToString([]byte(auth))
	req.Header.Add("Authorization", "Basic "+hash)
}

var safeNameRegex = regexp.MustCompile(`[^a-zA-Z\s\-\.]`)

func sanitizeName(name string) string {
	cleaned := safeNameRegex.ReplaceAllString(name, "")
	cleaned = strings.TrimSpace(cleaned)
	if cleaned == "" {
		return "Tourist"
	}
	return cleaned
}

// getSenderDetails fetches sender profile and identity details to inject proactively into SQRIL requests
func (s *SqrilProvider) getSenderDetails(ctx context.Context, customerID string) map[string]interface{} {
	// Standard tourist safe fallbacks
	sender := map[string]interface{}{
		"name_first":           "Tourist",
		"name_last":            "Paycif",
		"phone":                "+12025550143",
		"email":                "tourist@paycif.com",
		"ic":                   "P99999999",
		"ic_type":              "PP",
		"country":              "US",
		"address":              "123 Tourist Street",
		"type":                 "INDIVIDUAL",
		"gender":               "M",
		"country_of_residence": "US",
	}

	userIDStr := strings.TrimPrefix(customerID, "cust_paycif_")
	userID, err := uuid.Parse(userIDStr)
	if err != nil || s.DB == nil {
		return sender
	}

	var fullName, username, idLast4 string
	err = s.DB.QueryRowContext(ctx, "SELECT COALESCE(full_name, ''), username, COALESCE(id_last_4, '') FROM profiles WHERE id = $1", userID).Scan(&fullName, &username, &idLast4)
	if err == nil {
		if fullName == "" {
			fullName = username
		}
		if fullName != "" {
			parts := strings.Fields(fullName)
			if len(parts) > 0 {
				sender["name_first"] = sanitizeName(parts[0])
			}
			if len(parts) > 1 {
				sender["name_last"] = sanitizeName(strings.Join(parts[1:], " "))
			} else {
				sender["name_last"] = "Tourist"
			}
		}
		if strings.Contains(username, "@") {
			sender["email"] = username
		} else if username != "" {
			sender["email"] = username + "@paycif.com"
		}
		if idLast4 != "" {
			sender["ic"] = "P" + idLast4 + "9999"
		}
	}

	// Fetch identity verification (sumsub/kyc tier 2)
	var passportEncrypted, nationality string
	err = s.DB.QueryRowContext(ctx, "SELECT passport_number, nationality FROM identity_verification WHERE user_id = $1 ORDER BY created_at DESC LIMIT 1", userID).Scan(&passportEncrypted, &nationality)
	if err == nil {
		if len(nationality) == 2 {
			sender["country"] = strings.ToUpper(nationality)
			sender["country_of_residence"] = strings.ToUpper(nationality)
		}
		if passportEncrypted != "" {
			keyStr := os.Getenv("ENCRYPTION_KEY")
			if len(keyStr) != 32 {
				log.Printf("⚠️ ENCRYPTION_KEY not 32 bytes, skipping passport decrypt")
			} else {
				cryptoSvc := &CryptoService{key: []byte(keyStr)}
				decrypted, decErr := cryptoSvc.Decrypt(passportEncrypted)
				if decErr != nil {
					log.Printf("⚠️ Failed to decrypt passport: %v", decErr)
				} else if decrypted != "" {
					sender["ic"] = decrypted
				}
			}
		}
	}

	return sender
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
		reqBody, err := json.Marshal(map[string]interface{}{
			"qr_string":              qrString,
			"customer_id":            customerID,
			"payment_currency":       "THB",
			"partner_transaction_id": partnerTxID,
			"sender":                 s.getSenderDetails(ctx, customerID),
			"transaction_reason":     "TOURISM/TRAVEL EXPENSES",
			"source_of_funds":        "PERSONAL SAVINGS",
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
		bodyBytes, err := io.ReadAll(resp.Body)
		if err != nil {
			return nil, fmt.Errorf("failed to read decode response body: %w", err)
		}
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

		bodyBytes, err := io.ReadAll(resp.Body)
		if err != nil {
			return nil, fmt.Errorf("failed to read quote response body: %w", err)
		}
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

// GetTransactionResponse matches SQRIL /getTransaction response
type GetTransactionResponse struct {
	Transaction struct {
		ID        string  `json:"id"`
		Status    string  `json:"status"`
		AmountUSD float64 `json:"amount_usd"`
		Fee       float64 `json:"fee"`
	} `json:"transaction"`
}

// GetTransaction retrieves a specific transaction by ID
func (s *SqrilProvider) GetTransaction(ctx context.Context, transactionID string) (*GetTransactionResponse, error) {
	if s.ClientID == "mock-client-id" {
		return &GetTransactionResponse{}, nil
	}

	result, err := s.cb.Execute(func() (interface{}, error) {
		url := fmt.Sprintf("%s/getTransaction?transaction_id=%s", s.BaseURL, transactionID)
		req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
		if err != nil {
			return nil, fmt.Errorf("failed to create getTransaction request: %w", err)
		}

		s.addAuthHeader(req)

		resp, err := s.HTTPClient.Do(req)
		if err != nil {
			return nil, fmt.Errorf("getTransaction request failed: %w", err)
		}
		defer resp.Body.Close()

		bodyBytes, err := io.ReadAll(resp.Body)
		if err != nil {
			return nil, fmt.Errorf("failed to read transaction response body: %w", err)
		}
		if resp.StatusCode != http.StatusOK {
			return nil, fmt.Errorf("getTransaction returned status %d: %s", resp.StatusCode, string(bodyBytes))
		}

		var txResp GetTransactionResponse
		if err := json.Unmarshal(bodyBytes, &txResp); err != nil {
			return nil, fmt.Errorf("failed to parse getTransaction response: %w", err)
		}

		return &txResp, nil
	})
	if err != nil {
		return nil, err
	}
	return result.(*GetTransactionResponse), nil
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

	// 🛡️ Pre-flight balance check: verify pool wallet has sufficient funds (USD)
	txDetails, err := s.GetTransaction(ctx, providerTxID)
	if err == nil && txDetails != nil && txDetails.Transaction.AmountUSD > 0 {
		requiredUSD := txDetails.Transaction.AmountUSD + txDetails.Transaction.Fee
		balances, balErr := s.GetAccountBalances(ctx)
		if balErr == nil && balances != nil {
			usdBalance, exists := balances.Balances["USD"]
			if exists {
				if usdBalance.Available < requiredUSD {
					return nil, fmt.Errorf("insufficient pool wallet balance: available %.4f USD, required %.4f USD", usdBalance.Available, requiredUSD)
				}
			}
		}
	}

	result, err := s.cb.Execute(func() (interface{}, error) {
		// Call SQRIL /executePayout
		url := s.BaseURL + "/executePayout"
		reqBody, err := json.Marshal(map[string]interface{}{
			"tx_id":                  providerTxID,
			"customer_id":            customerID,
			"amount_confirmed":       amount,
			"currency":               currency,
			"partner_transaction_id": reference,
			"sender":                 s.getSenderDetails(ctx, customerID),
			"transaction_reason":     "TOURISM/TRAVEL EXPENSES",
			"source_of_funds":        "PERSONAL SAVINGS",
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

		bodyBytes, err := io.ReadAll(resp.Body)
		if err != nil {
			return nil, fmt.Errorf("failed to read payout response body: %w", err)
		}
		if resp.StatusCode != http.StatusAccepted && resp.StatusCode != http.StatusOK {
			return nil, fmt.Errorf("execute payout returned status %d: %s", resp.StatusCode, string(bodyBytes))
		}

		var executeResp map[string]interface{}
		if err := json.Unmarshal(bodyBytes, &executeResp); err != nil {
			return nil, fmt.Errorf("failed to parse execute response JSON: %w (raw response: %s)", err, string(bodyBytes))
		}

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

// BalanceDetail matches the details of a currency balance returned by SQRIL
type BalanceDetail struct {
	Available float64 `json:"available"`
	Locked    float64 `json:"locked"`
	Total     float64 `json:"total"`
	Currency  string  `json:"currency"`
}

// AccountBalancesResponse matches the GET /getAccountBalances response schema
type AccountBalancesResponse struct {
	Balances map[string]BalanceDetail `json:"balances"`
}

// GetAccountBalances fetches the current pool wallet balances
func (s *SqrilProvider) GetAccountBalances(ctx context.Context) (*AccountBalancesResponse, error) {
	if s.ClientID == "mock-client-id" {
		return &AccountBalancesResponse{
			Balances: map[string]BalanceDetail{
				"USD": {
					Available: 10000.0,
					Locked:    0.0,
					Total:     10000.0,
					Currency:  "USD",
				},
			},
		}, nil
	}

	result, err := s.cb.Execute(func() (interface{}, error) {
		url := s.BaseURL + "/getAccountBalances"
		req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
		if err != nil {
			return nil, fmt.Errorf("failed to create getAccountBalances request: %w", err)
		}

		s.addAuthHeader(req)

		resp, err := s.HTTPClient.Do(req)
		if err != nil {
			return nil, fmt.Errorf("getAccountBalances request failed: %w", err)
		}
		defer resp.Body.Close()

		bodyBytes, err := io.ReadAll(resp.Body)
		if err != nil {
			return nil, fmt.Errorf("failed to read balances response body: %w", err)
		}
		if resp.StatusCode != http.StatusOK {
			return nil, fmt.Errorf("getAccountBalances returned status %d: %s", resp.StatusCode, string(bodyBytes))
		}

		var balResp AccountBalancesResponse
		if err := json.Unmarshal(bodyBytes, &balResp); err != nil {
			return nil, fmt.Errorf("failed to parse balances response: %w", err)
		}

		return &balResp, nil
	})
	if err != nil {
		return nil, err
	}
	return result.(*AccountBalancesResponse), nil
}

// VerifyWebhookSignature verifies the SQRIL webhook signature header X-SQRIL-Signature using HMAC-SHA256
func (s *SqrilProvider) VerifyWebhookSignature(payload []byte, signature string, secret string) bool {
	if signature == "" {
		return false
	}
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write(payload)
	expectedMAC := mac.Sum(nil)
	expectedSignature := base64.StdEncoding.EncodeToString(expectedMAC)

	return subtle.ConstantTimeCompare([]byte(signature), []byte(expectedSignature)) == 1
}
