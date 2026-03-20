package service

import (
	"bytes"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strconv"
	"time"
)

type SumsubService struct {
	appToken  string
	secretKey string
	baseURL   string
	client    *http.Client
}

func NewSumsubService() *SumsubService {
	return &SumsubService{
		appToken:  os.Getenv("SUMSUB_APP_TOKEN"),
		secretKey: os.Getenv("SUMSUB_SECRET_KEY"),
		baseURL:   os.Getenv("SUMSUB_BASE_URL"),
		client:    &http.Client{Timeout: 10 * time.Second},
	}
}

func (s *SumsubService) signRequest(method, path string, body []byte) (string, string) {
	ts := strconv.FormatInt(time.Now().Unix(), 10)
	message := ts + method + path + string(body)

	h := hmac.New(sha256.New, []byte(s.secretKey))
	h.Write([]byte(message))
	sig := hex.EncodeToString(h.Sum(nil))

	return ts, sig
}

func (s *SumsubService) CreateApplicant(externalUserID, levelName string) (string, error) {
	path := "/resources/applicants?levelName=" + levelName
	url := s.baseURL + path
	method := "POST"

	payload := map[string]interface{}{
		"externalUserId": externalUserID,
	}
	body, _ := json.Marshal(payload)

	req, _ := http.NewRequest(method, url, bytes.NewBuffer(body))
	ts, sig := s.signRequest(method, path, body)

	req.Header.Set("X-App-Token", s.appToken)
	req.Header.Set("X-App-Access-Ts", ts)
	req.Header.Set("X-App-Access-Sig", sig)
	req.Header.Set("Content-Type", "application/json")

	resp, err := s.client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	respBody, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusCreated && resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("sumsub error: %s (status %d)", string(respBody), resp.StatusCode)
	}

	var result struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal(respBody, &result); err != nil {
		return "", err
	}

	return result.ID, nil
}

func (s *SumsubService) GenerateAccessToken(externalUserID, levelName string) (string, error) {
	path := fmt.Sprintf("/resources/accessTokens?userId=%s&levelName=%s", externalUserID, levelName)
	url := s.baseURL + path
	method := "POST"

	req, _ := http.NewRequest(method, url, nil)
	ts, sig := s.signRequest(method, path, []byte(""))

	req.Header.Set("X-App-Token", s.appToken)
	req.Header.Set("X-App-Access-Ts", ts)
	req.Header.Set("X-App-Access-Sig", sig)

	resp, err := s.client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	respBody, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("sumsub error: %s (status %d)", string(respBody), resp.StatusCode)
	}

	var result struct {
		Token string `json:"token"`
	}
	if err := json.Unmarshal(respBody, &result); err != nil {
		return "", err
	}

	return result.Token, nil
}

func (s *SumsubService) GetApplicantStatus(applicantID string) (string, error) {
	path := "/resources/applicants/" + applicantID + "/status"
	url := s.baseURL + path
	method := "GET"

	req, _ := http.NewRequest(method, url, nil)
	ts, sig := s.signRequest(method, path, []byte(""))

	req.Header.Set("X-App-Token", s.appToken)
	req.Header.Set("X-App-Access-Ts", ts)
	req.Header.Set("X-App-Access-Sig", sig)

	resp, err := s.client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	respBody, _ := io.ReadAll(resp.Body)
	var result struct {
		ReviewStatus string `json:"reviewStatus"`
	}
	if err := json.Unmarshal(respBody, &result); err != nil {
		return "", err
	}

	return result.ReviewStatus, nil
}

func (s *SumsubService) VerifyWebhookSignature(payload []byte, signature string) bool {
	h := hmac.New(sha256.New, []byte(s.secretKey))
	h.Write(payload)
	expectedSig := hex.EncodeToString(h.Sum(nil))
	return hmac.Equal([]byte(expectedSig), []byte(signature))
}
