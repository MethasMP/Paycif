package usecase

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"sort"
	"strings"
	"time"
)

const (
	achProdURL    = "https://openapi.alchemypay.org"
	achSandboxURL = "https://openapi-test.alchemypay.org"
)

var achHTTPClient = &http.Client{
	Timeout: 15 * time.Second,
	Transport: &http.Transport{
		MaxIdleConns:        50,
		MaxIdleConnsPerHost: 10,
		IdleConnTimeout:     90 * time.Second,
	},
}

// AlchemyPayAdapter is the on-ramp provider backed by Alchemy Pay.
type AlchemyPayAdapter struct {
	appID     string
	appSecret string
	baseURL   string
}

func NewAlchemyPayAdapter(appID, appSecret string, sandbox bool) *AlchemyPayAdapter {
	base := achProdURL
	if sandbox {
		base = achSandboxURL
	}
	return &AlchemyPayAdapter{appID: appID, appSecret: appSecret, baseURL: base}
}

// sign builds the HMAC-SHA256 signature required by ACH.
// Params are sorted alphabetically by key, concatenated as key=value&...,
// then signed with HMAC-SHA256 and Base64-encoded.
func (a *AlchemyPayAdapter) sign(params map[string]string) string {
	keys := make([]string, 0, len(params))
	for k := range params {
		keys = append(keys, k)
	}
	sort.Strings(keys)

	parts := make([]string, 0, len(keys))
	for _, k := range keys {
		if params[k] != "" {
			parts = append(parts, k+"="+params[k])
		}
	}
	raw := strings.Join(parts, "&")

	mac := hmac.New(sha256.New, []byte(a.appSecret))
	mac.Write([]byte(raw))
	sig := base64.StdEncoding.EncodeToString(mac.Sum(nil))
	return url.QueryEscape(sig)
}

// --- ACH response wrappers ---

type achResponse struct {
	Code    string          `json:"code"`
	Msg     string          `json:"msg"`
	Success bool            `json:"success"`
	Model   json.RawMessage `json:"model"`
}

func (r *achResponse) ok() bool { return r.Success && r.Code == "0" }

// --- CheckRegion ---

type RegionResult struct {
	Available bool
	Country   string
}

func (a *AlchemyPayAdapter) CheckRegion(ctx context.Context, ip string) (*RegionResult, error) {
	params := map[string]string{
		"appId": a.appID,
		"ip":    ip,
	}
	params["sign"] = a.sign(params)

	var resp achResponse
	if err := a.get(ctx, "/open/api/v1/merchant/ipCheck", params, &resp); err != nil {
		return nil, err
	}
	if !resp.ok() {
		return nil, fmt.Errorf("ACH ip check error %s: %s", resp.Code, resp.Msg)
	}

	var model struct {
		SupportBuy bool   `json:"supportBuy"`
		Country    string `json:"country"`
	}
	if err := json.Unmarshal(resp.Model, &model); err != nil {
		return nil, fmt.Errorf("ACH ip check parse error: %w", err)
	}
	return &RegionResult{Available: model.SupportBuy, Country: model.Country}, nil
}

// --- GetQuote ---

type QuoteResult struct {
	FiatAmount   string
	CryptoAmount string
	NetworkFee   string
	RampFee      string
	Price        string // crypto price in fiat
}

func (a *AlchemyPayAdapter) GetQuote(ctx context.Context, fiatAmount, fiatCurrency, crypto, network string) (*QuoteResult, error) {
	params := map[string]string{
		"appId":        a.appID,
		"fiatCurrency": fiatCurrency,
		"crypto":       crypto,
		"network":      network,
		"fiatAmount":   fiatAmount,
		"side":         "BUY",
	}
	params["sign"] = a.sign(params)

	var resp achResponse
	if err := a.get(ctx, "/open/api/v1/merchant/fiat/rateData", params, &resp); err != nil {
		return nil, err
	}
	if !resp.ok() {
		return nil, fmt.Errorf("ACH quote error %s: %s", resp.Code, resp.Msg)
	}

	var model struct {
		FiatAmount   string `json:"fiatAmount"`
		CryptoAmount string `json:"cryptoAmount"`
		NetworkFee   string `json:"networkFee"`
		RampFee      string `json:"rampFee"`
		Price        string `json:"price"`
	}
	if err := json.Unmarshal(resp.Model, &model); err != nil {
		return nil, fmt.Errorf("ACH quote parse error: %w", err)
	}
	return &QuoteResult{
		FiatAmount:   model.FiatAmount,
		CryptoAmount: model.CryptoAmount,
		NetworkFee:   model.NetworkFee,
		RampFee:      model.RampFee,
		Price:        model.Price,
	}, nil
}

// --- CreateOrder ---

type OnRampOrderParams struct {
	MerchantOrderNo string // our payout intent ID
	FiatCurrency    string // e.g. "USD"
	FiatAmount      string // e.g. "50.00"
	Crypto          string // "USDC"
	Network         string // "BASE"
	Address         string // pool wallet address (held by SQRIL/partner)
	Email           string // tourist email (pre-fill ACH KYC)
	RedirectURL     string // where ACH sends tourist after payment
	CallbackURL     string // our webhook endpoint
}

type OnRampOrderResult struct {
	WebURL string // redirect tourist here
}

func (a *AlchemyPayAdapter) CreateOrder(ctx context.Context, p OnRampOrderParams) (*OnRampOrderResult, error) {
	params := map[string]string{
		"appId":           a.appID,
		"merchantOrderNo": p.MerchantOrderNo,
		"fiatCurrency":    p.FiatCurrency,
		"fiatAmount":      p.FiatAmount,
		"crypto":          p.Crypto,
		"network":         p.Network,
		"address":         p.Address,
		"email":           p.Email,
		"redirectUrl":     p.RedirectURL,
		"callbackUrl":     p.CallbackURL,
	}
	params["sign"] = a.sign(params)

	var resp achResponse
	if err := a.post(ctx, "/open/merchant/api/v2", params, &resp); err != nil {
		return nil, err
	}
	if !resp.ok() {
		return nil, fmt.Errorf("ACH create order error %s: %s", resp.Code, resp.Msg)
	}

	var model struct {
		WebURL string `json:"webUrl"`
	}
	if err := json.Unmarshal(resp.Model, &model); err != nil {
		return nil, fmt.Errorf("ACH create order parse error: %w", err)
	}
	if model.WebURL == "" {
		return nil, fmt.Errorf("ACH create order returned empty webUrl")
	}
	return &OnRampOrderResult{WebURL: model.WebURL}, nil
}

// VerifyWebhookSignature checks the newSignature field from ACH webhook body.
// The string to be signed is constructed as: timestamp + requestMethod + requestPath + requestBody
// requestBody is a JSON string of sorted parameters excluding empty values, "signature", and "newSignature".
func (a *AlchemyPayAdapter) VerifyWebhookSignature(timestamp, method, requestPath, body string, receivedSig string) bool {
	// Parse JSON body to filter out empty values, signature, and newSignature, then sort
	var bodyMap map[string]interface{}
	if err := json.Unmarshal([]byte(body), &bodyMap); err != nil {
		return false
	}

	cleanMap := make(map[string]interface{})
	for k, v := range bodyMap {
		if k == "signature" || k == "newSignature" {
			continue
		}
		// Skip empty strings
		if str, ok := v.(string); ok && str == "" {
			continue
		}
		if v == nil {
			continue
		}
		cleanMap[k] = v
	}

	// In Go, mapping keys sorted in order is achieved by using a Sorted Map or TreeMap pattern.
	// Since json.Marshal on a map[string]interface{} in Go automatically sorts keys alphabetically,
	// marshaling cleanMap will produce a correctly sorted JSON body.
	sortedBytes, err := json.Marshal(cleanMap)
	if err != nil {
		return false
	}
	sortedBody := string(sortedBytes)

	// Construct the content string to sign
	content := timestamp + strings.ToUpper(method) + requestPath + sortedBody

	mac := hmac.New(sha256.New, []byte(a.appSecret))
	mac.Write([]byte(content))
	expectedSig := base64.StdEncoding.EncodeToString(mac.Sum(nil))

	return hmac.Equal([]byte(expectedSig), []byte(receivedSig))
}

// --- HTTP helpers ---

func (a *AlchemyPayAdapter) get(ctx context.Context, path string, params map[string]string, out interface{}) error {
	q := url.Values{}
	for k, v := range params {
		q.Set(k, v)
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, a.baseURL+path+"?"+q.Encode(), nil)
	if err != nil {
		return fmt.Errorf("ACH GET build error: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	return a.do(req, out)
}

func (a *AlchemyPayAdapter) post(ctx context.Context, path string, params map[string]string, out interface{}) error {
	body, _ := json.Marshal(params)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, a.baseURL+path, strings.NewReader(string(body)))
	if err != nil {
		return fmt.Errorf("ACH POST build error: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	return a.do(req, out)
}

func (a *AlchemyPayAdapter) do(req *http.Request, out interface{}) error {
	resp, err := achHTTPClient.Do(req)
	if err != nil {
		return fmt.Errorf("ACH request failed: %w", err)
	}
	defer resp.Body.Close()

	b, err := io.ReadAll(resp.Body)
	if err != nil {
		return fmt.Errorf("ACH read body error: %w", err)
	}
	if resp.StatusCode >= 500 {
		return fmt.Errorf("ACH server error %d: %s", resp.StatusCode, string(b))
	}
	return json.Unmarshal(b, out)
}
