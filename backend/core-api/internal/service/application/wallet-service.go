package application

import (
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"sort"
	"time"

	"SmartSpend/internal/domain/enum"
	"SmartSpend/internal/domain/model"
	"SmartSpend/internal/repository"

	"github.com/jackc/pgx/v5/pgconn"
)

var (
	ErrNotMember           = errors.New("not a member of this wallet")
	ErrTransactionNotFound = errors.New("transaction not found")
	ErrNotExpense          = errors.New("only expense transactions can be linked to a wallet")
	ErrEmptySplit          = errors.New("split_with must not be empty")
	ErrShareMismatch       = errors.New("sum of shares must equal transaction price")
	ErrAlreadyLinked       = errors.New("transaction already linked to this wallet")
	ErrWalletTxNotFound    = errors.New("wallet transaction not found")
)

type SplitEntry struct {
	UserID string  `json:"user_id"`
	Share  float64 `json:"share"`
}

type LinkExpenseRequest struct {
	TransactionID int64           `json:"transaction_id"`
	SplitWith     json.RawMessage `json:"split_with"`
}

type WalletExpenseResponse struct {
	ID            int64        `json:"id"`
	WalletID      int64        `json:"wallet_id"`
	TransactionID int          `json:"transaction_id"`
	AddedAt       time.Time    `json:"added_at"`
	Splits        []SplitEntry `json:"splits"`
}

type MemberBalance struct {
	UserID     string  `json:"user_id"`
	Name       string  `json:"name"`
	NetBalance float64 `json:"net_balance"`
}

type SuggestedSettlement struct {
	FromUserID string  `json:"from_user_id"`
	ToUserID   string  `json:"to_user_id"`
	Amount     float64 `json:"amount"`
}

type BalanceResult struct {
	Members              []MemberBalance       `json:"members"`
	SuggestedSettlements []SuggestedSettlement `json:"suggested_settlements"`
}

type IApplicationWalletService interface {
	LinkExpense(walletID int64, callerID string, req *LinkExpenseRequest) (*WalletExpenseResponse, error)
	UnlinkExpense(walletID int64, walletTxID int64, callerID string) error
	ComputeBalances(walletID int64, callerID string) (*BalanceResult, error)
}

type ApplicationWalletService struct {
	walletRepo      repository.IWalletRepository
	transactionRepo repository.ITransactionRepository
}

func NewApplicationWalletService(walletRepo repository.IWalletRepository, transactionRepo repository.ITransactionRepository) *ApplicationWalletService {
	return &ApplicationWalletService{
		walletRepo:      walletRepo,
		transactionRepo: transactionRepo,
	}
}

func (s *ApplicationWalletService) LinkExpense(walletID int64, callerID string, req *LinkExpenseRequest) (*WalletExpenseResponse, error) {
	isMember, err := s.walletRepo.IsMember(walletID, callerID)
	if err != nil {
		return nil, err
	}
	if !isMember {
		return nil, ErrNotMember
	}

	tx, err := s.transactionRepo.FindById(req.TransactionID, callerID)
	if err != nil {
		return nil, ErrTransactionNotFound
	}

	if tx.Type != enum.Expense {
		return nil, ErrNotExpense
	}

	splits, err := parseSplitWith(req.SplitWith, float64(tx.Price))
	if err != nil {
		return nil, err
	}
	if len(splits) == 0 {
		return nil, ErrEmptySplit
	}

	members, err := s.walletRepo.GetMembers(walletID)
	if err != nil {
		return nil, err
	}
	memberSet := make(map[string]bool, len(members))
	for _, m := range members {
		memberSet[m.UserID] = true
	}
	for _, sp := range splits {
		if !memberSet[sp.UserID] {
			return nil, fmt.Errorf("user %s is not a member of this wallet", sp.UserID)
		}
	}

	var total float64
	for _, sp := range splits {
		total += sp.Share
	}
	if math.Abs(total-float64(tx.Price)) > 0.01 {
		return nil, ErrShareMismatch
	}

	walletTx := &model.WalletTransaction{
		WalletID:      walletID,
		TransactionID: int(tx.ID),
	}
	splitModels := make([]*model.WalletTransactionSplit, len(splits))
	for i, sp := range splits {
		splitModels[i] = &model.WalletTransactionSplit{
			UserID: sp.UserID,
			Share:  sp.Share,
		}
	}

	if err := s.walletRepo.AddWalletTransaction(walletTx, splitModels); err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			return nil, ErrAlreadyLinked
		}
		return nil, err
	}

	respSplits := make([]SplitEntry, len(splits))
	for i, sp := range splits {
		respSplits[i] = SplitEntry{UserID: sp.UserID, Share: sp.Share}
	}
	return &WalletExpenseResponse{
		ID:            walletTx.ID,
		WalletID:      walletTx.WalletID,
		TransactionID: walletTx.TransactionID,
		AddedAt:       walletTx.AddedAt,
		Splits:        respSplits,
	}, nil
}

func (s *ApplicationWalletService) UnlinkExpense(walletID int64, walletTxID int64, callerID string) error {
	isMember, err := s.walletRepo.IsMember(walletID, callerID)
	if err != nil {
		return err
	}
	if !isMember {
		return ErrNotMember
	}

	wt, err := s.walletRepo.FindWalletTransactionByID(walletTxID)
	if err != nil {
		return ErrWalletTxNotFound
	}
	if wt.WalletID != walletID {
		return ErrWalletTxNotFound
	}

	return s.walletRepo.RemoveWalletTransaction(walletTxID)
}

func (s *ApplicationWalletService) ComputeBalances(walletID int64, callerID string) (*BalanceResult, error) {
	isMember, err := s.walletRepo.IsMember(walletID, callerID)
	if err != nil {
		return nil, err
	}
	if !isMember {
		return nil, ErrNotMember
	}

	members, err := s.walletRepo.GetMembersWithDetails(walletID)
	if err != nil {
		return nil, err
	}

	txs, err := s.walletRepo.GetWalletTransactions(walletID)
	if err != nil {
		return nil, err
	}

	settlements, err := s.walletRepo.GetSettlements(walletID)
	if err != nil {
		return nil, err
	}

	nameMap := make(map[string]string, len(members))
	net := make(map[string]float64, len(members))
	for _, m := range members {
		nameMap[m.UserID] = m.Name
		net[m.UserID] = 0
	}

	// Step 1: raw net balances
	for _, wtx := range txs {
		net[wtx.Transaction.OwnerId] += float64(wtx.Transaction.Price)
		for _, sp := range wtx.Splits {
			net[sp.UserID] -= sp.Share
		}
	}

	// Step 2: apply recorded settlements
	for _, stl := range settlements {
		net[stl.FromUserID] += stl.Amount
		net[stl.ToUserID] -= stl.Amount
	}

	memberBalances := make([]MemberBalance, 0, len(members))
	for _, m := range members {
		memberBalances = append(memberBalances, MemberBalance{
			UserID:     m.UserID,
			Name:       nameMap[m.UserID],
			NetBalance: math.Round(net[m.UserID]*100) / 100,
		})
	}

	// Step 3: greedy minimum-transactions algorithm
	const epsilon = 0.005
	type entry struct {
		userID string
		amount float64
	}
	var creditors, debtors []entry
	for uid, n := range net {
		if n > epsilon {
			creditors = append(creditors, entry{uid, n})
		} else if n < -epsilon {
			debtors = append(debtors, entry{uid, -n})
		}
	}
	sort.Slice(creditors, func(i, j int) bool { return creditors[i].amount > creditors[j].amount })
	sort.Slice(debtors, func(i, j int) bool { return debtors[i].amount > debtors[j].amount })

	suggestions := make([]SuggestedSettlement, 0)
	ci, di := 0, 0
	for ci < len(creditors) && di < len(debtors) {
		transfer := math.Min(creditors[ci].amount, debtors[di].amount)
		suggestions = append(suggestions, SuggestedSettlement{
			FromUserID: debtors[di].userID,
			ToUserID:   creditors[ci].userID,
			Amount:     math.Round(transfer*100) / 100,
		})
		creditors[ci].amount -= transfer
		debtors[di].amount -= transfer
		if creditors[ci].amount < epsilon {
			ci++
		}
		if debtors[di].amount < epsilon {
			di++
		}
	}

	return &BalanceResult{
		Members:              memberBalances,
		SuggestedSettlements: suggestions,
	}, nil
}

func parseSplitWith(raw json.RawMessage, price float64) ([]SplitEntry, error) {
	var full []SplitEntry
	if err := json.Unmarshal(raw, &full); err == nil && len(full) > 0 && full[0].UserID != "" {
		return full, nil
	}

	var userIDs []string
	if err := json.Unmarshal(raw, &userIDs); err == nil && len(userIDs) > 0 {
		equalShare := price / float64(len(userIDs))
		result := make([]SplitEntry, len(userIDs))
		for i, uid := range userIDs {
			result[i] = SplitEntry{UserID: uid, Share: equalShare}
		}
		return result, nil
	}

	return nil, fmt.Errorf("invalid split_with format")
}
