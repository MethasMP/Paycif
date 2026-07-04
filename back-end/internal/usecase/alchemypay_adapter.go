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
	achProdURL        = "https://openapi.alchemypay.org"
	achSandboxURL     = "https://openapi-test.alchemypay.org"
	achPageProdURL    = "https://ramp.alchemypay.org"
	achPageSandboxURL = "https://ramptest.alchemypay.org"
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
	appID       string
	appSecret   string
	baseURL     string
	pageBaseURL string
}

func NewAlchemyPayAdapter(appID, appSecret string, sandbox bool) *AlchemyPayAdapter {
	base := achProdURL
	pageBase := achPageProdURL
	if sandbox {
		base = achSandboxURL
		pageBase = achPageSandboxURL
	}
	return &AlchemyPayAdapter{appID: appID, appSecret: appSecret, baseURL: base, pageBaseURL: pageBase}
}

// GenerateManageURL builds a signed AlchemyPay Page Integration URL.
// Used by the Payment Settings screen so users can add/manage saved cards
// and digital wallets (Apple Pay, Google Pay) inside AlchemyPay's H5 widget.
// When token is provided the user skips email verification — payment methods
// saved in a previous session are pre-loaded.
func (a *AlchemyPayAdapter) GenerateManageURL(merchantOrderNo, token, callbackURL, redirectURL string) string {
	ts := fmt.Sprintf("%d", time.Now().UnixMilli())

	params := map[string]string{
		"appId":           a.appID,
		"timestamp":       ts,
		"merchantOrderNo": merchantOrderNo,
		"crypto":          "USDC",
		"network":         "BASE",
		"showTable":       "buy",
	}
	if token != "" {
		params["token"] = token
	}
	if callbackURL != "" {
		params["callbackUrl"] = callbackURL
	}
	if redirectURL != "" {
		params["redirectUrl"] = redirectURL
	}

	// Sort params alphabetically, build query string
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
	queryString := strings.Join(parts, "&")

	// Page Integration signature: timestamp + GET + /index/rampPageBuy?<sorted_params>
	requestPath := "/index/rampPageBuy?" + queryString
	signInput := ts + "GET" + requestPath

	mac := hmac.New(sha256.New, []byte(a.appSecret))
	mac.Write([]byte(signInput))
	sig := url.QueryEscape(base64.StdEncoding.EncodeToString(mac.Sum(nil)))

	return fmt.Sprintf("%s?%s&sign=%s", a.pageBaseURL, queryString, sig)
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

// --- GetToken (skip-email-verify) ---

type GetTokenResult struct {
	AccessToken string
	UserID      string // ACH internal encrypted user ID
}

// GetToken exchanges the user's email for a 10-day ACH accessToken.
// The token is passed as the `token` param in the ACH widget URL so users
// skip the email verification step entirely.
// Prerequisite: the user's email must already be verified on Paycif's side.
func (a *AlchemyPayAdapter) GetToken(ctx context.Context, email string) (*GetTokenResult, error) {
	timestamp := fmt.Sprintf("%d", time.Now().UnixMilli())
	path := "/open/api/v4/merchant/getToken"
	body := fmt.Sprintf(`{"email":%q}`, email)

	mac := hmac.New(sha256.New, []byte(a.appSecret))
	mac.Write([]byte(timestamp + "POST" + path + body))
	sig := base64.StdEncoding.EncodeToString(mac.Sum(nil))

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, a.baseURL+path, strings.NewReader(body))
	if err != nil {
		return nil, fmt.Errorf("ACH getToken build error: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("appid", a.appID)
	req.Header.Set("timestamp", timestamp)
	req.Header.Set("sign", sig)

	var resp achResponse
	if err := a.do(req, &resp); err != nil {
		return nil, err
	}
	if !resp.ok() {
		return nil, fmt.Errorf("ACH getToken error %s: %s", resp.Code, resp.Msg)
	}

	var model struct {
		ID          string `json:"id"`
		AccessToken string `json:"accessToken"`
	}
	if err := json.Unmarshal(resp.Model, &model); err != nil {
		return nil, fmt.Errorf("ACH getToken parse error: %w", err)
	}
	return &GetTokenResult{AccessToken: model.AccessToken, UserID: model.ID}, nil
}

// --- FiatList (payment methods + fees by country) ---

type FiatPaymentMethod struct {
	Currency    string  `json:"currency"`
	Country     string  `json:"country"`
	CountryName string  `json:"country_name"`
	PayWayCode  string  `json:"pay_way_code"`
	PayWayName  string  `json:"pay_way_name"`
	FixedFee    float64 `json:"fixed_fee"`
	FeeRate     float64 `json:"fee_rate"`
	PayMin      float64 `json:"pay_min"`
	PayMax      float64 `json:"pay_max"`
}

// FiatList returns all supported fiat currencies and their payment methods.
// Pass side="BUY" for on-ramp (default). Filter by country client-side.
func (a *AlchemyPayAdapter) FiatList(ctx context.Context, side string) ([]FiatPaymentMethod, error) {
	if side == "" {
		side = "BUY"
	}
	params := map[string]string{
		"appId": a.appID,
		"type":  side,
	}
	params["sign"] = a.sign(params)

	var resp achResponse
	if err := a.get(ctx, "/open/api/v4/merchant/fiat/list", params, &resp); err != nil {
		return nil, err
	}
	if !resp.ok() {
		return nil, fmt.Errorf("ACH fiat list error %s: %s", resp.Code, resp.Msg)
	}

	var models []struct {
		Currency    string  `json:"currency"`
		Country     string  `json:"country"`
		CountryName string  `json:"countryName"`
		PayWayCode  string  `json:"payWayCode"`
		PayWayName  string  `json:"payWayName"`
		FixedFee    float64 `json:"fixedFee"`
		FeeRate     float64 `json:"feeRate"`
		PayMin      float64 `json:"payMin"`
		PayMax      float64 `json:"payMax"`
	}
	if err := json.Unmarshal(resp.Model, &models); err != nil {
		return nil, fmt.Errorf("ACH fiat list parse error: %w", err)
	}

	out := make([]FiatPaymentMethod, len(models))
	for i, m := range models {
		out[i] = FiatPaymentMethod{
			Currency:    m.Currency,
			Country:     m.Country,
			CountryName: m.CountryName,
			PayWayCode:  m.PayWayCode,
			PayWayName:  m.PayWayName,
			FixedFee:    m.FixedFee,
			FeeRate:     m.FeeRate,
			PayMin:      m.PayMin,
			PayMax:      m.PayMax,
		}
	}
	return out, nil
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
