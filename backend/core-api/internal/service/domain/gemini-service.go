package domain

import (
	"SmartSpend/internal/database"
	"SmartSpend/internal/domain/model"
	"SmartSpend/internal/repository"
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strings"
)

var (
	database_          database.Service               = database.New()
	categoryRepository repository.ICategoryRepository = repository.NewCategoryRepository(database_)
	categoryService    ICategoryService               = NewCategoryService(categoryRepository)

	prompt = fmt.Sprintf(`Based on the image receipt, generate a single Transaction JSON object. Available Categories list: %v. Output Format Profile:
{
  "id": 0,
  "title": "A concise title summarized in English",
  "price": 0.0,
  "date_made": "2026-01-01T00:00:00Z",
  "owner_id": "",
  "category_id": 0,
  "type": "Expense"
}
Rules:
1. "price" must be a raw numeric float calculated as the final grand total. Do not wrap it in quotes.
2. Choose the most appropriate ID from the categories list provided above and map it to the "category_id" field as an integer.
3. Do not let your model fail to prioritize a semantically correct and common product name over a literal, but flawed, character transcription.`, categoryService.FindAll())
)

type GeminiResponse struct {
	Candidates []Candidate `json:"candidates"`
}

type Candidate struct {
	Content Content `json:"content"`
}

type Content struct {
	Parts []Part `json:"parts"`
}

type Part struct {
	Text string `json:"text"`
}

type IGeminiService interface {
	SendToGemini(extractedTextOCR string, imageString string) (*model.Transaction, error)
}

type GeminiService struct {
	apiKey string
}

func NewGeminiService() *GeminiService {
	apiKey := os.Getenv("GEMINI_API_KEY")
	if apiKey == "" {
		log.Println("GEMINI_API_KEY is empty!")
	}
	return &GeminiService{apiKey: apiKey}
}

func (g *GeminiService) SendToGemini(extractedTextOCR string, imageString string) (*model.Transaction, error) {
	url := "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent"

	payload := map[string]interface{}{
		"contents": []map[string]interface{}{
			{
				"parts": []map[string]interface{}{
					{"text": prompt},
					{
						"inlineData": map[string]string{
							"mimeType": "image/jpeg",
							"data":     imageString,
						},
					},
				},
			},
		},
		"generationConfig": map[string]interface{}{
			"responseMimeType": "application/json",
		},
	}

	jsonPayload, err := json.Marshal(payload)
	if err != nil {
		return nil, err
	}

	req, err := http.NewRequest("POST", fmt.Sprintf("%s?key=%s", url, g.apiKey), bytes.NewBuffer(jsonPayload))
	if err != nil {
		return nil, err
	}

	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("Gemini API returned server error status %d: %s", resp.StatusCode, string(body))
	}

	var geminiResp GeminiResponse
	if err := json.Unmarshal(body, &geminiResp); err != nil {
		return nil, fmt.Errorf("failed to unmarshal Gemini API response structure: %w", err)
	}

	if len(geminiResp.Candidates) == 0 {
		return nil, fmt.Errorf("Gemini API returned zero execution candidates. Full body log: %s", string(body))
	}

	if len(geminiResp.Candidates[0].Content.Parts) == 0 {
		return nil, fmt.Errorf("Gemini candidate content returned empty parts array. Full body log: %s", string(body))
	}

	jsonText := geminiResp.Candidates[0].Content.Parts[0].Text
	jsonText = strings.TrimSpace(jsonText)

	if strings.HasPrefix(jsonText, "```") {
		jsonText = strings.TrimPrefix(jsonText, "```json")
		jsonText = strings.TrimPrefix(jsonText, "```")
		jsonText = strings.TrimSuffix(jsonText, "```")
		jsonText = strings.TrimSpace(jsonText)
	}

	var tx model.Transaction
	if err := json.Unmarshal([]byte(jsonText), &tx); err != nil {
		return nil, fmt.Errorf("failed to unmarshal extracted JSON text to your transaction model. Raw output: %s | Error: %w", jsonText, err)
	}

	return &tx, nil
}
