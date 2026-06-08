package domain

import (
	"SmartSpend/internal/database"
	"SmartSpend/internal/domain/enum"
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

	prompt = fmt.Sprintf(`Based on the image receipt, generate a single unified JSON object. Available Categories list: %v. 
Output JSON Format:
{
  "title": "A concise title summarized in English",
  "price": 0.0,
  "category_id": 0,
  "type": "Expense",
  "city": "Name of the city",
  "address": "Street address line",
  "lat": 0.0,
  "lng": 0.0
}
Rules:
1. "price" must be a raw numeric float calculated as the final grand total.
2. Choose the most appropriate ID from the categories list provided above and map it to the "category_id" field.
3. Look closely at rows 3 to 6 starting from the top-most text of the receipt to extract the merchant name, city, and address.
4. Extrapolate an approximate lat and lng coordinate matching that merchant location address.
5. Strictly output ONLY raw JSON. No markdown blocks.`, categoryService.FindAll())
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

type GeminiReceiptPayload struct {
	Title      string  `json:"title"`
	Price      float64 `json:"price"`
	CategoryID *int64  `json:"category_id"`
	Type       string  `json:"type"`
	City       string  `json:"city"`
	Address    string  `json:"address"`
	Lat        float64 `json:"lat"`
	Lng        float64 `json:"lng"`
}

type OSMReverseResponse struct {
	DisplayName string `json:"display_name"`
	Address     struct {
		City    string `json:"city"`
		Town    string `json:"town"`
		Village string `json:"village"`
	} `json:"address"`
	Error string `json:"error"`
}

type IGeminiService interface {
	SendToGemini(extractedTextOCR string, imageString string) (*model.Transaction, *model.TransactionLocation, error)
}

type GeminiService struct {
	apiKey string
}

func NewGeminiService() *GeminiService {
	return &GeminiService{apiKey: os.Getenv("GEMINI_API_KEY")}
}

func (g *GeminiService) SendToGemini(extractedTextOCR string, imageString string) (*model.Transaction, *model.TransactionLocation, error) {
	g.apiKey = os.Getenv("GEMINI_API_KEY")
	if g.apiKey == "" {
		return nil, nil, fmt.Errorf("GEMINI_API_KEY environment variable is empty")
	}

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
		return nil, nil, err
	}

	req, err := http.NewRequest("POST", fmt.Sprintf("%s?key=%s", url, g.apiKey), bytes.NewBuffer(jsonPayload))
	if err != nil {
		return nil, nil, err
	}
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return nil, nil, err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, nil, err
	}

	if resp.StatusCode != http.StatusOK {
		return nil, nil, fmt.Errorf("Gemini API error status %d: %s", resp.StatusCode, string(body))
	}

	var geminiResp GeminiResponse
	if err := json.Unmarshal(body, &geminiResp); err != nil {
		return nil, nil, err
	}

	if len(geminiResp.Candidates) == 0 || len(geminiResp.Candidates[0].Content.Parts) == 0 {
		return nil, nil, fmt.Errorf("empty response from Gemini")
	}

	jsonText := geminiResp.Candidates[0].Content.Parts[0].Text
	jsonText = strings.TrimSpace(jsonText)
	if strings.HasPrefix(jsonText, "```") {
		jsonText = strings.TrimPrefix(jsonText, "```json")
		jsonText = strings.TrimPrefix(jsonText, "```")
		jsonText = strings.TrimSuffix(jsonText, "```")
		jsonText = strings.TrimSpace(jsonText)
	}

	var parsed GeminiReceiptPayload
	if err := json.Unmarshal([]byte(jsonText), &parsed); err != nil {
		return nil, nil, err
	}

	log.Printf("[Receipt OCR] --- RAW GEMINI EXTRACTION DETECTED ---")
	log.Printf("[Receipt OCR] Title: %s | Price: %.2f | Type: %s", parsed.Title, parsed.Price, parsed.Type)
	log.Printf("[Receipt OCR] Location Guess -> City: %s | Address: %s | Lat: %f | Lng: %f", parsed.City, parsed.Address, parsed.Lat, parsed.Lng)

	// Map clean Transaction model cleanly back
	tx := &model.Transaction{
		Title:      parsed.Title,
		Price:      parsed.Price,
		CategoryId: parsed.CategoryID,
		Type:       enum.TransactionType(parsed.Type),
	}

	var loc *model.TransactionLocation
	if parsed.Lat != 0 && parsed.Lng != 0 {
		loc = g.reverseGeocode(parsed.Lat, parsed.Lng)
	}

	return tx, loc, nil
}
func (g *GeminiService) reverseGeocode(lat, lng float64) *model.TransactionLocation {
	url := fmt.Sprintf("https://nominatim.openstreetmap.org/reverse?format=json&lat=%f&lon=%f", lat, lng)

	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		log.Printf("[Geocode] Error creating OSM request: %v", err)
		return &model.TransactionLocation{Lat: lat, Lng: lng}
	}

	req.Header.Set("User-Agent", "SmartSpendApp/1.0 (contact@yourdomain.com)")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil || resp.StatusCode != http.StatusOK {
		log.Printf("[Geocode] Error hitting OSM API: %v", err)
		return &model.TransactionLocation{Lat: lat, Lng: lng}
	}
	defer resp.Body.Close()

	var osmResp OSMReverseResponse
	if err := json.NewDecoder(resp.Body).Decode(&osmResp); err != nil || osmResp.Error != "" {
		log.Printf("[Geocode] OSM lookup unsuccessful. Error: %s", osmResp.Error)
		return &model.TransactionLocation{Lat: lat, Lng: lng}
	}

	resolvedCity := osmResp.Address.City
	if resolvedCity == "" {
		resolvedCity = osmResp.Address.Town
	}
	if resolvedCity == "" {
		resolvedCity = osmResp.Address.Village
	}

	extractedLoc := &model.TransactionLocation{
		Address: osmResp.DisplayName,
		City:    resolvedCity,
		Lat:     lat,
		Lng:     lng,
	}

	log.Printf("[Geocode] SUCCESS -> Formatted Address: %s | Resolved City: %s", extractedLoc.Address, extractedLoc.City)
	return extractedLoc
}
