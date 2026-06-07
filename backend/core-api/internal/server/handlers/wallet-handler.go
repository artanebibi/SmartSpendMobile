package handlers

import (
	"errors"
	"net/http"
	"strconv"

	"SmartSpend/internal/service/application"

	"github.com/gin-gonic/gin"
)

func (s *Server) LinkWalletExpense(c *gin.Context) {
	walletID, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid wallet id"})
		return
	}

	_, callerID := getUserFromDatabase(c)

	var req application.LinkExpenseRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body"})
		return
	}

	result, err := applicationWalletService.LinkExpense(walletID, callerID, &req)
	if err != nil {
		switch {
		case errors.Is(err, application.ErrAlreadyLinked):
			c.JSON(http.StatusConflict, gin.H{"error": err.Error()})
		case errors.Is(err, application.ErrNotMember):
			c.JSON(http.StatusForbidden, gin.H{"error": err.Error()})
		default:
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		}
		return
	}

	c.JSON(http.StatusOK, gin.H{"data": result})
}

func (s *Server) UnlinkWalletExpense(c *gin.Context) {
	walletID, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid wallet id"})
		return
	}

	walletTxID, err := strconv.ParseInt(c.Param("walletTxId"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid wallet transaction id"})
		return
	}

	_, callerID := getUserFromDatabase(c)

	if err := applicationWalletService.UnlinkExpense(walletID, walletTxID, callerID); err != nil {
		switch {
		case errors.Is(err, application.ErrNotMember):
			c.JSON(http.StatusForbidden, gin.H{"error": err.Error()})
		case errors.Is(err, application.ErrWalletTxNotFound):
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
		default:
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		}
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "wallet transaction removed"})
}

func (s *Server) GetWalletBalances(c *gin.Context) {
	walletID, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid wallet id"})
		return
	}

	_, callerID := getUserFromDatabase(c)

	result, err := applicationWalletService.ComputeBalances(walletID, callerID)
	if err != nil {
		switch {
		case errors.Is(err, application.ErrNotMember):
			c.JSON(http.StatusForbidden, gin.H{"error": err.Error()})
		default:
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to compute balances"})
		}
		return
	}

	c.JSON(http.StatusOK, gin.H{"data": result})
}
