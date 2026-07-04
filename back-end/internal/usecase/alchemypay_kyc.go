package usecase

import (
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"time"
)

const (
	achKYCSandboxURL    = "https://sbx-user-api.alchemytech.cc"
	achKYCProductionURL = "https://pro-user-api.alchemytech.cc"

	achKYCRegisterPath   = "/open/api/user/core/register"
	achKYCStatusPath     = "/open/api/user/core/getKycStatusInfo"
	achKYCUserInfoPath   = "/open/api/user/core/queryUserInfo"
)

// Alchemy Pay kycStatus values returned in API and webhook.
const (
	AchKycApproved          = 1
	AchKycPermanentRejected = 2
	AchKycTemporaryRejected = 3
)

// AlchemyPayKYCClient calls the Alchemy Pay user/KYC API.
type AlchemyPayKYCClient struct {
	baseURL    string
	appKey     string
	secretKey  string
	merchantNo string
	httpClient *http.Client
}

// NewAlchemyPayKYCClient creates a client for the Alchemy Pay KYC API.
func NewAlchemyPayKYCClient(appKey, secretKey, merchantNo string, sandbox bool) *AlchemyPayKYCClient {
	baseURL := achKYCProductionURL
	if sandbox {
		baseURL = achKYCSandboxURL
	}
	return &AlchemyPayKYCClient{
		baseURL:    baseURL,
		appKey:     appKey,
		secretKey:  secretKey,
		merchantNo: merchantNo,
		httpClient: &http.Client{Timeout: 15 * time.Second},
	}
}

// sign computes HMAC-SHA256(timestamp+METHOD+path+body, secretKey) encoded as Base64.
func (c *AlchemyPayKYCClient) sign(timestamp, method, path, body string) string {
	msg := timestamp + method + path + body
	mac := hmac.New(sha256.New, []byte(c.secretKey))
	mac.Write([]byte(msg))
	return base64.StdEncoding.EncodeToString(mac.Sum(nil))
}

func (c *AlchemyPayKYCClient) doRequest(ctx context.Context, method, path string, payload interface{}) ([]byte, error) {
	var bodyBytes []byte
	var err error
	if payload != nil {
		bodyBytes, err = json.Marshal(payload)
		if err != nil {
			return nil, fmt.Errorf("marshal payload: %w", err)
		}
	}

	ts := strconv.FormatInt(time.Now().UnixMilli(), 10)
	sig := c.sign(ts, method, path, string(bodyBytes))

	req, err := http.NewRequestWithContext(ctx, method, c.baseURL+path, bytes.NewBuffer(bodyBytes))
	if err != nil {
		return nil, fmt.Errorf("create request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("ach-access-key", c.appKey)
	req.Header.Set("ach-access-timestamp", ts)
	req.Header.Set("ach-access-sign", sig)

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("http request: %w", err)
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("read response: %w", err)
	}
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("alchemy pay KYC returned HTTP %d: %s", resp.StatusCode, string(respBody))
	}
	return respBody, nil
}

type achEnvelope struct {
	Code    interface{}            `json:"code"`
	Msg     string                 `json:"msg"`
	Model   interface{}            `json:"model"`
	TraceID string                 `json:"traceId"`
	Success bool                   `json:"success"`
	Error   bool                   `json:"error"`
}

func (r *achEnvelope) codeIsZero() bool {
	switch v := r.Code.(type) {
	case float64:
		return v == 0
	case string:
		return v == "0"
	}
	return false
}

// AchKycStatusResult holds the parsed KYC status from Alchemy Pay.
type AchKycStatusResult struct {
	UserNo      string
	KycStatus   int
	KycLevel    int
	ApplicantID string
	FirstName   string
	LastName    string
	Country     string
}

func (c *AlchemyPayKYCClient) RegisterUser(ctx context.Context, email, kycPlatform, kycType, callbackURL, redirectURL string) (string, error) {
	// 🧪 Developer Mock Mode: If using mock keys, return empty URL to simulate instant auto-verification bypass
	if c.appKey == "mock-alchemy-app-id" || c.secretKey == "mock-alchemy-app-secret" || c.merchantNo == "mock-alchemy-app-secret" {
		return "", nil
	}

	payload := map[string]string{
		"merchantNo":  c.merchantNo,
		"email":       email,
		"kycPlatform": kycPlatform,
		"kycType":     kycType,
		"callbackUrl": callbackURL,
	}
	if redirectURL != "" {
		payload["redirectUrl"] = redirectURL
	}

	body, err := c.doRequest(ctx, http.MethodPost, achKYCRegisterPath, payload)
	if err != nil {
		return "", err
	}

	var env achEnvelope
	if err := json.Unmarshal(body, &env); err != nil {
		return "", fmt.Errorf("parse register response: %w", err)
	}

	// code 2002 = already registered; still return success so caller can proceed
	if !env.Success && !env.codeIsZero() {
		codeStr := fmt.Sprintf("%v", env.Code)
		if codeStr == "2002" {
			return "", nil // user already registered — not an error
		}
		return "", fmt.Errorf("alchemy pay register: %s (code %v)", env.Msg, env.Code)
	}

	kycURL, _ := env.Model.(string)
	return kycURL, nil
}

// GetKycStatus calls /open/api/user/core/getKycStatusInfo.
// Returns nil result (no error) when the user is not yet registered.
func (c *AlchemyPayKYCClient) GetKycStatus(ctx context.Context, email, kycType, kycPlatform string) (*AchKycStatusResult, error) {
	// 🧪 Developer Mock Mode: If using mock keys, mock successful verification status
	if c.appKey == "mock-alchemy-app-id" || c.secretKey == "mock-alchemy-app-secret" {
		return &AchKycStatusResult{
			UserNo:      "mock-userno-123",
			KycStatus:   AchKycApproved,
			KycLevel:    1,
			ApplicantID: "mock-applicant-123",
			FirstName:   "John",
			LastName:    "Doe",
			Country:     "TH",
		}, nil
	}

	body, err := c.doRequest(ctx, http.MethodPost, achKYCStatusPath, map[string]string{
		"email":       email,
		"kycType":     kycType,
		"kycPlatform": kycPlatform,
	})
	if err != nil {
		return nil, err
	}

	var env achEnvelope
	if err := json.Unmarshal(body, &env); err != nil {
		return nil, fmt.Errorf("parse kyc status response: %w", err)
	}

	// code 2003 = user not registered
	if !env.Success {
		codeStr := fmt.Sprintf("%v", env.Code)
		if codeStr == "2003" {
			return nil, nil
		}
		return nil, fmt.Errorf("alchemy pay kyc status: %s (code %v)", env.Msg, env.Code)
	}

	if env.Model == nil {
		return nil, nil
	}

	model, _ := env.Model.(map[string]interface{})
	result := &AchKycStatusResult{}
	if v, ok := model["userNo"].(string); ok {
		result.UserNo = v
	}
	if v, ok := model["kycStatus"].(float64); ok {
		result.KycStatus = int(v)
	}
	if v, ok := model["kycLevel"].(float64); ok {
		result.KycLevel = int(v)
	}
	if v, ok := model["applicantId"].(string); ok {
		result.ApplicantID = v
	}
	if v, ok := model["firstName"].(string); ok {
		result.FirstName = v
	}
	if v, ok := model["lastName"].(string); ok {
		result.LastName = v
	}
	if v, ok := model["country"].(string); ok {
		result.Country = v
	}
	return result, nil
}

// AchKycStatusToInternal maps Alchemy Pay kycStatus (1/2/3) to our internal string.
func AchKycStatusToInternal(achStatus int) string {
	switch achStatus {
	case AchKycApproved:
		return "VERIFIED"
	case AchKycPermanentRejected:
		return "REJECTED"
	case AchKycTemporaryRejected:
		return "PENDING_RESUBMISSION"
	default:
		return "PENDING"
	}
}

// AppKey returns the configured app key (used to check whether the client is configured).
func (c *AlchemyPayKYCClient) AppKey() string { return c.appKey }

// VerifyWebhookSignature validates the HMAC-SHA256 signature on Alchemy Pay callbacks.
func (c *AlchemyPayKYCClient) VerifyWebhookSignature(timestamp, method, path, body, signature string) bool {
	expected := c.sign(timestamp, method, path, body)
	return hmac.Equal([]byte(expected), []byte(signature))
}

// AchWebhookPayload is the callback payload sent by Alchemy Pay after KYC completion.
type AchWebhookPayload struct {
	UserNo          string `json:"userNo"`
	Email           string `json:"email"`
	MerchantNo      string `json:"merchantNo"`
	SubMerchantNo   string `json:"subMerchantNo"`
	KycLevel        int    `json:"kycLevel"`
	KycStatus       int    `json:"kycStatus"` // 1=approved, 2=permanent reject, 3=temp reject
	KycType         string `json:"kycType"`
	FirstName       string `json:"firstName"`
	LastName        string `json:"lastName"`
	Dob             string `json:"dob"`
	Gender          string `json:"gender"`
	Country         string `json:"country"`
	IdDocType       string `json:"idDocType"`
	ValidUntil      string `json:"validUntil"`
	ApplicantID     string `json:"applicantId"`
	KycFailJson     string `json:"kycFailJson"`
}

// AchUserInfoResult holds detailed user info from Alchemy Pay.
type AchUserInfoResult struct {
	UserNum             string                   `json:"userNum"`
	DocumentInfoList    []map[string]interface{} `json:"documentInfoList"`
	AddressInfoList     []map[string]interface{} `json:"addressInfoList"`
	NameHistoryInfoList []map[string]interface{} `json:"nameHistoryInfoList"`
	ExtendInfoList      []map[string]interface{} `json:"extendInfoList"`
}

// QueryUserInfo calls /open/api/user/core/queryUserInfo
func (c *AlchemyPayKYCClient) QueryUserInfo(ctx context.Context, userNum string) (*AchUserInfoResult, error) {
	payload := map[string]string{
		"userNum":    userNum,
		"merchantNo": c.merchantNo,
	}
	body, err := c.doRequest(ctx, http.MethodPost, achKYCUserInfoPath, payload)
	if err != nil {
		return nil, err
	}

	var env achEnvelope
	if err := json.Unmarshal(body, &env); err != nil {
		return nil, fmt.Errorf("parse query user info response: %w", err)
	}

	if !env.Success {
		return nil, fmt.Errorf("alchemy pay query user info: %s (code %v)", env.Msg, env.Code)
	}

	if env.Model == nil {
		return nil, nil
	}

	modelBytes, _ := json.Marshal(env.Model)
	var result AchUserInfoResult
	if err := json.Unmarshal(modelBytes, &result); err != nil {
		return nil, fmt.Errorf("parse model user info: %w", err)
	}

	return &result, nil
}
