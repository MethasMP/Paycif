package usecase

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"strings"
	"sync/atomic"
	"time"

	"github.com/sony/gobreaker"
)

var (
	ipqsAPIKey  = os.Getenv("IPQUALITYSCORE_API_KEY")
	ipqsBaseURL = func() string {
		if v := os.Getenv("IPQUALITYSCORE_BASE_URL"); v != "" {
			return v
		}
		return "https://ipqualityscore.com/api/json/ip"
	}()
	ipqsStrictness = func() string {
		if v := os.Getenv("IPQUALITYSCORE_STRICTNESS"); v != "" {
			return v
		}
		return "1"
	}()
)

var consecutiveIPQSFailures int32

// IPQSResponse represents the response from IPQualityScore Proxy Detection API.
type IPQSResponse struct {
	Success            bool              `json:"success"`
	Message            string            `json:"message"`
	Proxy              bool              `json:"proxy"`
	VPN                bool              `json:"vpn"`
	ActiveVPN          bool              `json:"active_vpn"`
	TOR                bool              `json:"tor"`
	ActiveTOR          bool              `json:"active_tor"`
	RecentAbuse        bool              `json:"recent_abuse"`
	BotStatus          bool              `json:"bot_status"`
	FraudScore         float64           `json:"fraud_score"`
	CountryCode        string            `json:"country_code"`
	ISP                string            `json:"ISP"`
	ASN                int               `json:"ASN"`
	RequestID          string            `json:"request_id"`
	TransactionDetails *IPQSTransDetails `json:"transaction_details,omitempty"`
}

// IPQSTransDetails represents details returned when transaction data is passed to IPQS.
type IPQSTransDetails struct {
	RiskScore         float64  `json:"risk_score"`
	RiskFactors       []string `json:"risk_factors"`
	RecommendedAction string   `json:"recommended_action"` // approve, review, 3ds, deny
	ValidBillingEmail *bool    `json:"valid_billing_email,omitempty"`
	RiskyBillingPhone *bool    `json:"risky_billing_phone,omitempty"`
	IsPrepaidCard     *bool    `json:"is_prepaid_card,omitempty"`
}

// IPQSService handles IPQualityScore API calls with Circuit Breaker support.
type IPQSService struct {
	cb *gobreaker.CircuitBreaker
}

// NewIPQSService initializes IPQSService with gobreaker.
func NewIPQSService() *IPQSService {
	settings := gobreaker.Settings{
		Name:        "IPQualityScoreDetection",
		MaxRequests: 5,
		Interval:    10 * time.Second,
		Timeout:     30 * time.Second,
		ReadyToTrip: func(counts gobreaker.Counts) bool {
			failureRatio := float64(counts.TotalFailures) / float64(counts.Requests)
			return counts.Requests >= 3 && failureRatio >= 0.6
		},
	}

	return &IPQSService{
		cb: gobreaker.NewCircuitBreaker(settings),
	}
}

// IsSuspicious queries IPQS API to determine if an IP is high-risk/VPN/proxy/Tor/bot.
func (s *IPQSService) IsSuspicious(ctx context.Context, ip string, userAgent string, userLanguage string) (bool, *IPQSResponse, error) {
	if IsLocalIP(ip) {
		return false, nil, nil
	}

	result, err := s.cb.Execute(func() (interface{}, error) {
		apiKey := ipqsAPIKey
		if apiKey == "" {
			return nil, fmt.Errorf("IPQUALITYSCORE_API_KEY not set")
		}

		endpoint := fmt.Sprintf("%s/%s/%s", strings.TrimRight(ipqsBaseURL, "/"), url.PathEscape(apiKey), url.PathEscape(ip))

		queryParams := url.Values{}
		queryParams.Set("strictness", ipqsStrictness)
		queryParams.Set("allow_public_access_points", "true")

		if userAgent != "" {
			queryParams.Set("user_agent", userAgent)
		}
		if userLanguage != "" {
			queryParams.Set("user_language", userLanguage)
		}

		fullURL := fmt.Sprintf("%s?%s", endpoint, queryParams.Encode())

		req, err := http.NewRequestWithContext(ctx, http.MethodGet, fullURL, nil)
		if err != nil {
			return nil, err
		}

		resp, err := geoBlockHTTPClient.Do(req)
		if err != nil {
			return nil, err
		}
		defer resp.Body.Close()

		body, err := io.ReadAll(resp.Body)
		if err != nil {
			return nil, err
		}

		if resp.StatusCode != http.StatusOK {
			return nil, fmt.Errorf("ipqs returned status %d: %s", resp.StatusCode, string(body))
		}

		var ipqsResp IPQSResponse
		if err := json.Unmarshal(body, &ipqsResp); err != nil {
			return nil, fmt.Errorf("failed to unmarshal ipqs response: %w", err)
		}

		if !ipqsResp.Success {
			return nil, fmt.Errorf("ipqs lookup unsuccessful: %s", ipqsResp.Message)
		}

		// Determination logic based on IPQS best practices:
		// 1. Active VPN or Active Tor
		// 2. Fraud Score >= 90 (High risk / abusive)
		// 3. Bot Status confirmed
		// 4. Proxy status true AND Fraud Score >= 75
		suspicious := ipqsResp.ActiveVPN ||
			ipqsResp.ActiveTOR ||
			ipqsResp.BotStatus ||
			ipqsResp.FraudScore >= 90.0 ||
			(ipqsResp.Proxy && ipqsResp.FraudScore >= 75.0)

		return &struct {
			Suspicious bool
			Resp       *IPQSResponse
		}{
			Suspicious: suspicious,
			Resp:       &ipqsResp,
		}, nil
	})

	if err != nil {
		atomic.AddInt32(&consecutiveIPQSFailures, 1)
		return false, nil, err
	}

	atomic.StoreInt32(&consecutiveIPQSFailures, 0)
	res := result.(*struct {
		Suspicious bool
		Resp       *IPQSResponse
	})
	return res.Suspicious, res.Resp, nil
}

// TransactionScoreParams contains context data for scoring money transactions.
type TransactionScoreParams struct {
	IP              string
	UserAgent       string
	UserLanguage    string
	BillingEmail    string
	BillingPhone    string
	BillingCountry  string
	OrderAmount     float64
	CreditCardBin   string
	CreditCardLast4 string
	TransactionType string
}

// ScoreTransactionRisk performs contextual payment & transaction fraud scoring via IPQS.
func (s *IPQSService) ScoreTransactionRisk(ctx context.Context, params *TransactionScoreParams) (*IPQSResponse, error) {
	if IsLocalIP(params.IP) {
		return &IPQSResponse{Success: true, FraudScore: 0}, nil
	}

	result, err := s.cb.Execute(func() (interface{}, error) {
		apiKey := ipqsAPIKey
		if apiKey == "" {
			return nil, fmt.Errorf("IPQUALITYSCORE_API_KEY not set")
		}

		endpoint := fmt.Sprintf("%s/%s/%s", strings.TrimRight(ipqsBaseURL, "/"), url.PathEscape(apiKey), url.PathEscape(params.IP))
		queryParams := url.Values{}
		queryParams.Set("strictness", ipqsStrictness)
		queryParams.Set("allow_public_access_points", "true")

		if params.UserAgent != "" {
			queryParams.Set("user_agent", params.UserAgent)
		}
		if params.UserLanguage != "" {
			queryParams.Set("user_language", params.UserLanguage)
		}
		if params.BillingEmail != "" {
			queryParams.Set("billing_email", params.BillingEmail)
		}
		if params.BillingPhone != "" {
			queryParams.Set("billing_phone", params.BillingPhone)
		}
		if params.BillingCountry != "" {
			queryParams.Set("billing_country", params.BillingCountry)
		}
		if params.OrderAmount > 0 {
			queryParams.Set("order_amount", fmt.Sprintf("%.2f", params.OrderAmount))
		}
		if params.CreditCardBin != "" {
			queryParams.Set("credit_card_bin", params.CreditCardBin)
		}
		if params.CreditCardLast4 != "" {
			queryParams.Set("credit_card_last_four", params.CreditCardLast4)
		}
		if params.TransactionType != "" {
			queryParams.Set("transaction_type", params.TransactionType)
		}

		fullURL := fmt.Sprintf("%s?%s", endpoint, queryParams.Encode())
		req, err := http.NewRequestWithContext(ctx, http.MethodGet, fullURL, nil)
		if err != nil {
			return nil, err
		}

		resp, err := geoBlockHTTPClient.Do(req)
		if err != nil {
			return nil, err
		}
		defer resp.Body.Close()

		body, err := io.ReadAll(resp.Body)
		if err != nil {
			return nil, err
		}

		if resp.StatusCode != http.StatusOK {
			return nil, fmt.Errorf("ipqs transaction score status %d: %s", resp.StatusCode, string(body))
		}

		var ipqsResp IPQSResponse
		if err := json.Unmarshal(body, &ipqsResp); err != nil {
			return nil, fmt.Errorf("failed to unmarshal ipqs response: %w", err)
		}

		return &ipqsResp, nil
	})

	if err != nil {
		return nil, err
	}
	return result.(*IPQSResponse), nil
}
