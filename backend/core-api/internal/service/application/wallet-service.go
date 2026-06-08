package application

import (
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"log"
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
	ErrAlreadyMember       = errors.New("already a member of this wallet")
	ErrNotOwner            = errors.New("only the owner can perform this action")
	ErrOwnerHasMembers     = errors.New("transfer ownership or disband the wallet before leaving")
	ErrWalletNotFound      = errors.New("wallet not found")
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

// --- Response types for wallet CRUD ---

type WalletSummary struct {
	model.Wallet
	TotalSpent  float64 `json:"total_spent"`
	MemberCount int     `json:"member_count"`
}

type WalletMemberDetail struct {
	UserID   string    `json:"user_id"`
	Role     string    `json:"role"`
	JoinedAt time.Time `json:"joined_at"`
}

type WalletDetail struct {
	model.Wallet
	Members      []*WalletMemberDetail                      `json:"members"`
	Transactions []*repository.WalletTransactionWithDetails `json:"transactions"`
}

// --- Interface ---

type IApplicationWalletService interface {
	// Wallet CRUD
	CreateWallet(callerID string, name string) (*model.Wallet, error)
	GetUserWallets(callerID string) ([]*WalletSummary, error)
	GetWalletDetail(walletID int64, callerID string) (*WalletDetail, error)
	JoinWallet(walletID int64, inviteCode string, callerID string) (*model.Wallet, error)
	JoinWalletByCode(inviteCode string, callerID string) (*model.Wallet, error)
	LeaveWallet(walletID int64, callerID string) error
	DeleteWallet(walletID int64, callerID string) error

	// Settlements
	RecordSettlement(walletID int64, callerID string, req *SettleRequest) (*model.WalletSettlement, error)

	// Expense linking
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

// --- Wallet CRUD implementations ---

func (s *ApplicationWalletService) CreateWallet(callerID string, name string) (*model.Wallet, error) {
	wallet := &model.Wallet{
		CreatedBy: callerID,
		Name:      name,
	}
	created, err := s.walletRepo.Create(wallet)
	if err != nil {
		return nil, err
	}
	if err := s.walletRepo.AddMember(created.ID, callerID, "owner"); err != nil {
		return nil, err
	}
	return created, nil
}

func (s *ApplicationWalletService) GetUserWallets(callerID string) ([]*WalletSummary, error) {
	wallets, err := s.walletRepo.FindByUser(callerID)
	if err != nil {
		return nil, err
	}

	summaries := make([]*WalletSummary, 0, len(wallets))
	for _, w := range wallets {
		members, err := s.walletRepo.GetMembers(w.ID)
		if err != nil {
			return nil, err
		}

		txs, err := s.walletRepo.GetWalletTransactions(w.ID)
		if err != nil {
			return nil, err
		}

		var totalSpent float64
		for _, wtx := range txs {
			totalSpent += wtx.Transaction.Price
		}

		summaries = append(summaries, &WalletSummary{
			Wallet:      *w,
			TotalSpent:  math.Round(totalSpent*100) / 100,
			MemberCount: len(members),
		})
	}
	return summaries, nil
}

func (s *ApplicationWalletService) GetWalletDetail(walletID int64, callerID string) (*WalletDetail, error) {
	isMember, err := s.walletRepo.IsMember(walletID, callerID)
	if err != nil {
		return nil, err
	}
	if !isMember {
		return nil, ErrNotMember
	}

	wallet, err := s.walletRepo.FindByID(walletID)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, ErrWalletNotFound
		}
		return nil, err
	}

	rawMembers, err := s.walletRepo.GetMembers(walletID)
	if err != nil {
		return nil, err
	}
	members := make([]*WalletMemberDetail, len(rawMembers))
	for i, m := range rawMembers {
		members[i] = &WalletMemberDetail{
			UserID:   m.UserID,
			Role:     m.Role,
			JoinedAt: m.JoinedAt,
		}
	}

	txs, err := s.walletRepo.GetWalletTransactions(walletID)
	if err != nil {
		return nil, err
	}

	return &WalletDetail{
		Wallet:       *wallet,
		Members:      members,
		Transactions: txs,
	}, nil
}

func (s *ApplicationWalletService) JoinWallet(walletID int64, inviteCode string, callerID string) (*model.Wallet, error) {
	wallet, err := s.walletRepo.FindByInviteCode(inviteCode)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, ErrWalletNotFound
		}
		return nil, ErrWalletNotFound
	}

	if wallet.ID != walletID {
		return nil, ErrWalletNotFound
	}

	already, err := s.walletRepo.IsMember(walletID, callerID)
	if err != nil {
		return nil, err
	}
	if already {
		return nil, ErrAlreadyMember
	}

	if err := s.walletRepo.AddMember(walletID, callerID, "member"); err != nil {
		return nil, err
	}
	return wallet, nil
}

func (s *ApplicationWalletService) JoinWalletByCode(inviteCode string, callerID string) (*model.Wallet, error) {
	wallet, err := s.walletRepo.FindByInviteCode(inviteCode)
	if err != nil {
		return nil, ErrWalletNotFound
	}

	already, err := s.walletRepo.IsMember(wallet.ID, callerID)
	if err != nil {
		return nil, err
	}
	if already {
		return nil, ErrAlreadyMember
	}

	if err := s.walletRepo.AddMember(wallet.ID, callerID, "member"); err != nil {
		return nil, err
	}
	return wallet, nil
}

func (s *ApplicationWalletService) LeaveWallet(walletID int64, callerID string) error {
	isMember, err := s.walletRepo.IsMember(walletID, callerID)
	if err != nil {
		return err
	}
	if !isMember {
		return ErrNotMember
	}

	role, err := s.walletRepo.GetMemberRole(walletID, callerID)
	if err != nil {
		return err
	}

	if role == "owner" {
		members, err := s.walletRepo.GetMembers(walletID)
		if err != nil {
			return err
		}
		if len(members) > 1 {
			return ErrOwnerHasMembers
		}
		// sole member — delete the whole wallet
		return s.walletRepo.Delete(walletID)
	}

	return s.walletRepo.RemoveMember(walletID, callerID)
}

func (s *ApplicationWalletService) DeleteWallet(walletID int64, callerID string) error {
	isMember, err := s.walletRepo.IsMember(walletID, callerID)
	if err != nil {
		return err
	}
	if !isMember {
		return ErrNotMember
	}

	role, err := s.walletRepo.GetMemberRole(walletID, callerID)
	if err != nil {
		return err
	}
	if role != "owner" {
		return ErrNotOwner
	}

	return s.walletRepo.Delete(walletID)
}

// --- Settlement implementation ---

type SettleRequest struct {
	FromUserID string  `json:"from_user_id"`
	ToUserID   string  `json:"to_user_id"`
	Amount     float64 `json:"amount"`
}

func (s *ApplicationWalletService) RecordSettlement(walletID int64, callerID string, req *SettleRequest) (*model.WalletSettlement, error) {
	// Caller membership
	isMember, err := s.walletRepo.IsMember(walletID, callerID)
	if err != nil {
		return nil, err
	}
	if !isMember {
		return nil, ErrNotMember
	}

	// Self-settlement guard
	if req.FromUserID == req.ToUserID {
		return nil, fmt.Errorf("from_user_id and to_user_id must not be the same")
	}

	// Amount guard
	if req.Amount <= 0 {
		return nil, fmt.Errorf("amount must be greater than zero")
	}

	// Caller must be a party to the settlement
	if callerID != req.FromUserID && callerID != req.ToUserID {
		return nil, fmt.Errorf("caller must be either from_user_id or to_user_id")
	}

	// Both parties must be wallet members
	fromMember, err := s.walletRepo.IsMember(walletID, req.FromUserID)
	if err != nil {
		return nil, err
	}
	if !fromMember {
		return nil, fmt.Errorf("from_user_id is not a member of this wallet")
	}

	toMember, err := s.walletRepo.IsMember(walletID, req.ToUserID)
	if err != nil {
		return nil, err
	}
	if !toMember {
		return nil, fmt.Errorf("to_user_id is not a member of this wallet")
	}

	settlement := &model.WalletSettlement{
		WalletID:   walletID,
		FromUserID: req.FromUserID,
		ToUserID:   req.ToUserID,
		Amount:     req.Amount,
	}
	if err := s.walletRepo.AddSettlement(settlement); err != nil {
		return nil, err
	}
	return settlement, nil
}

// --- Expense linking implementations ---

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

	splits, err := parseSplitWith(req.SplitWith, tx.Price)
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
	if math.Abs(total-tx.Price) > 0.01 {
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

	log.Printf("[Balance] wallet=%d members=%d txs=%d settlements=%d", walletID, len(members), len(txs), len(settlements))

	// Step 1: raw net balances
	for _, wtx := range txs {
		if len(wtx.Splits) == 0 {
			log.Printf("[Balance] skipping tx %d (no splits)", wtx.ID)
			continue // skip transactions with no recorded splits
		}
		log.Printf("[Balance] tx %d: payer=%s price=%.2f splits=%d", wtx.ID, wtx.Transaction.OwnerId, wtx.Transaction.Price, len(wtx.Splits))
		net[wtx.Transaction.OwnerId] += wtx.Transaction.Price
		for _, sp := range wtx.Splits {
			log.Printf("[Balance]   split user=%s share=%.2f", sp.UserID, sp.Share)
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
		log.Printf("[Balance] net[%s] = %.4f", uid, n)
		if n > epsilon {
			creditors = append(creditors, entry{uid, n})
		} else if n < -epsilon {
			debtors = append(debtors, entry{uid, -n})
		}
	}
	log.Printf("[Balance] creditors=%d debtors=%d", len(creditors), len(debtors))
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
