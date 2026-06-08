package handlers

import (
	"errors"
	"net/http"
	"strconv"

	"SmartSpend/internal/service/application"

	"github.com/gin-gonic/gin"
)

// isMemberGuard checks that callerID is a member of walletID.
// Returns false and writes 403 if the check fails.
func isMemberGuard(c *gin.Context, walletID int64, callerID string) bool {
	ok, err := walletRepository.IsMember(walletID, callerID)
	if err != nil || !ok {
		c.JSON(http.StatusForbidden, gin.H{"error": "forbidden: not a member of this wallet"})
		return false
	}
	return true
}

func (s *Server) CreateWallet(c *gin.Context) {
	_, callerID := getUserFromDatabase(c)

	var body struct {
		Name string `json:"name" binding:"required"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "name is required"})
		return
	}

	wallet, err := applicationWalletService.CreateWallet(callerID, body.Name)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, gin.H{"data": wallet})
}

func (s *Server) GetUserWallets(c *gin.Context) {
	_, callerID := getUserFromDatabase(c)

	summaries, err := applicationWalletService.GetUserWallets(callerID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"data": summaries})
}

func (s *Server) GetWalletDetail(c *gin.Context) {
	walletID, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid wallet id"})
		return
	}

	_, callerID := getUserFromDatabase(c)

	if !isMemberGuard(c, walletID, callerID) {
		return
	}

	detail, err := applicationWalletService.GetWalletDetail(walletID, callerID)
	if err != nil {
		switch {
		case errors.Is(err, application.ErrNotMember):
			c.JSON(http.StatusForbidden, gin.H{"error": err.Error()})
		case errors.Is(err, application.ErrWalletNotFound):
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
		default:
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		}
		return
	}

	c.JSON(http.StatusOK, gin.H{"data": detail})
}

func (s *Server) JoinWallet(c *gin.Context) {
	walletID, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid wallet id"})
		return
	}

	_, callerID := getUserFromDatabase(c)

	var body struct {
		InviteCode string `json:"invite_code" binding:"required"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invite_code is required"})
		return
	}

	wallet, err := applicationWalletService.JoinWallet(walletID, body.InviteCode, callerID)
	if err != nil {
		switch {
		case errors.Is(err, application.ErrWalletNotFound):
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
		case errors.Is(err, application.ErrAlreadyMember):
			c.JSON(http.StatusConflict, gin.H{"error": err.Error()})
		default:
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		}
		return
	}

	c.JSON(http.StatusOK, gin.H{"data": wallet})
}

func (s *Server) JoinWalletByCode(c *gin.Context) {
	_, callerID := getUserFromDatabase(c)

	var body struct {
		InviteCode string `json:"invite_code" binding:"required"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invite_code is required"})
		return
	}

	wallet, err := applicationWalletService.JoinWalletByCode(body.InviteCode, callerID)
	if err != nil {
		switch {
		case errors.Is(err, application.ErrWalletNotFound):
			c.JSON(http.StatusNotFound, gin.H{"error": "invalid invite code"})
		case errors.Is(err, application.ErrAlreadyMember):
			c.JSON(http.StatusConflict, gin.H{"error": err.Error()})
		default:
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		}
		return
	}

	c.JSON(http.StatusOK, gin.H{"data": wallet})
}

func (s *Server) LeaveWallet(c *gin.Context) {
	walletID, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid wallet id"})
		return
	}

	_, callerID := getUserFromDatabase(c)

	if !isMemberGuard(c, walletID, callerID) {
		return
	}

	if err := applicationWalletService.LeaveWallet(walletID, callerID); err != nil {
		switch {
		case errors.Is(err, application.ErrNotMember):
			c.JSON(http.StatusForbidden, gin.H{"error": err.Error()})
		case errors.Is(err, application.ErrOwnerHasMembers):
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		default:
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		}
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "left wallet successfully"})
}

func (s *Server) DeleteWallet(c *gin.Context) {
	walletID, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid wallet id"})
		return
	}

	_, callerID := getUserFromDatabase(c)

	if !isMemberGuard(c, walletID, callerID) {
		return
	}

	if err := applicationWalletService.DeleteWallet(walletID, callerID); err != nil {
		switch {
		case errors.Is(err, application.ErrNotMember):
			c.JSON(http.StatusForbidden, gin.H{"error": err.Error()})
		case errors.Is(err, application.ErrNotOwner):
			c.JSON(http.StatusForbidden, gin.H{"error": err.Error()})
		default:
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		}
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "wallet deleted successfully"})
}

func (s *Server) SettleWallet(c *gin.Context) {
	walletID, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid wallet id"})
		return
	}

	_, callerID := getUserFromDatabase(c)

	var req application.SettleRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body"})
		return
	}

	settlement, err := applicationWalletService.RecordSettlement(walletID, callerID, &req)
	if err != nil {
		switch {
		case errors.Is(err, application.ErrNotMember):
			c.JSON(http.StatusForbidden, gin.H{"error": err.Error()})
		default:
			// Validation errors (self-settle, amount <= 0, non-party, non-member parties)
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		}
		return
	}

	c.JSON(http.StatusCreated, gin.H{"data": settlement})
}

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
