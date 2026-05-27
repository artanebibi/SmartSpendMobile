package handlers

import (
	"SmartSpend/internal/domain/dto"
	"bytes"
	"encoding/base64"
	"fmt"
	"image"
	"image/jpeg"
	"io"
	"log"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
)

func (s *Server) GetAllTransactions(c *gin.Context) {
	fromStr := c.Query("from")
	toStr := c.Query("to")

	var from, to time.Time
	var err error

	if fromStr == "" {
		from = time.Time{}
	} else {
		from, err = parseFlexibleTime(fromStr)
		if err != nil {
			log.Printf("Failed to parse 'from': %s, error: %v", fromStr, err)
			c.JSON(400, gin.H{"error": "invalid 'from' date format"})
			return
		}
	}

	if toStr == "" {
		to = time.Now()
	} else {
		to, err = parseFlexibleTime(toStr)
		if err != nil {
			log.Printf("Failed to parse 'to': %s, error: %v", toStr, err)
			c.JSON(400, gin.H{"error": "invalid 'to' date format"})
			return
		}
	}

	if !from.IsZero() && !to.IsZero() && from.After(to) {
		c.JSON(400, gin.H{"error": "'from' date cannot be after 'to' date"})
		return
	}

	_, userId := getUserFromDatabase(c)
	transactions := applicationTransactionService.FindAll(userId, from, to)

	c.JSON(200, gin.H{"data": transactions})
}

func (s *Server) GetTransactionByID(c *gin.Context) {
	id := c.Param("id")
	idInteger, err := strconv.ParseInt(id, 10, 64)
	if err != nil {
		c.JSON(400, gin.H{"error": "invalid id"})
		return
	}
	_, userId := getUserFromDatabase(c)
	transaction, err := applicationTransactionService.FindById(idInteger, userId)

	if err != nil {
		c.JSON(400, gin.H{"error": err.Error()})
		return
	}

	c.JSON(200, gin.H{"data": transaction})
	return
}

func (s *Server) SaveTransaction(c *gin.Context) {
	var t dto.TransactionDto
	if err := c.ShouldBindJSON(&t); err != nil {
		c.JSON(400, gin.H{"error": err.Error()})
		return
	}

	_, userId := getUserFromDatabase(c)
	err, message := applicationTransactionService.CreateOrUpdate(&t, userId)

	if err != nil {
		c.JSON(500, gin.H{"error": message})
	} else {
		c.JSON(200, gin.H{
			"message": message,
		})
	}
	return
}

func (s *Server) UpdateTransaction(c *gin.Context) {
	var t dto.TransactionDto
	if err := c.ShouldBindJSON(&t); err != nil {
		c.JSON(400, gin.H{"error": err.Error()})
		return
	}

	_, userId := getUserFromDatabase(c)
	id, _ := strconv.ParseInt(c.Param("id"), 10, 64)
	t.ID = id
	err, message := applicationTransactionService.CreateOrUpdate(&t, userId)

	if err != nil {
		c.JSON(500, gin.H{"error": message})
	} else {
		c.JSON(200, gin.H{
			"message": message,
		})
	}
	return
}

func (s *Server) DeleteTransaction(c *gin.Context) {
	id, _ := strconv.ParseInt(c.Param("id"), 10, 64)
	_, userId := getUserFromDatabase(c)

	t, err_ := applicationTransactionService.FindById(id, userId)
	if err_ != nil {
		c.JSON(400, gin.H{"error": err_.Error()})
	}
	err := applicationTransactionService.Delete(t, userId)

	if err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
	} else {
		c.JSON(200, gin.H{
			"message": "Transaction deleted successfully",
		})
	}
	return
}

func imageToBase64(img image.Image) (string, error) {
	var buf bytes.Buffer
	if err := jpeg.Encode(&buf, img, nil); err != nil {
		return "", err
	}
	return base64.StdEncoding.EncodeToString(buf.Bytes()), nil
}

func (s *Server) SaveFromReceipt(c *gin.Context) {
	_, userId := getUserFromDatabase(c)

	file, header, err := c.Request.FormFile("image")
	if err != nil {
		log.Printf("[Receipt OCR] ERROR - Failed to get image file from form: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"error": fmt.Sprintf("Failed to get image file: %v", err)})
		return
	}
	defer file.Close()
	log.Printf("[Receipt OCR] Received photo. (Size: %d bytes)", header.Size)

	var imgBuffer bytes.Buffer
	teeReader := io.TeeReader(file, &imgBuffer)

	img, format, err := image.Decode(teeReader)
	if err != nil {
		log.Printf("[Receipt OCR] ERROR - Image decoding failed: %v. (Check if image format package is imported)", err)
		c.JSON(http.StatusBadRequest, gin.H{"error": fmt.Sprintf("Failed to decode image: %v", err)})
		return
	}
	log.Printf("[Receipt OCR] Image decoded successfully. Image format: %s", format)

	base64Image, err := imageToBase64(img)
	if err != nil {
		log.Printf("[Receipt OCR] ERROR - Base64 encoding failed: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("Failed to encode image to Base64: %v", err)})
		return
	}
	log.Println("[Receipt OCR] Sending to Gemini...")
	tx, err := geminiService.SendToGemini("", base64Image)
	if err != nil {
		log.Printf("[Receipt OCR] ERROR - Gemini Service: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("Gemini service error: %v", err)})
		return
	}

	if tx == nil {
		log.Println("[Receipt OCR] ERROR - Gemini returned an empty transaction from receipt")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Gemini service returned empty transaction data"})
		return
	}

	tx.OwnerId = userId
	tx.DateMade = time.Now()

	log.Printf("[Receipt OCR] SUCCESS - Gemini parsed transaction successfully!")

	c.JSON(http.StatusOK, tx)
}
