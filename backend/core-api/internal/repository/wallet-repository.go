package repository

import (
	"database/sql"
	"fmt"
	"log"

	"SmartSpend/internal/database"
	"SmartSpend/internal/domain/model"
)

type WalletTransactionWithDetails struct {
	model.WalletTransaction
	Transaction model.Transaction               `json:"transaction"`
	Splits      []*model.WalletTransactionSplit `json:"splits"`
}

type WalletMemberWithDetails struct {
	UserID string
	Name   string
}

type IWalletRepository interface {
	Create(wallet *model.Wallet) (*model.Wallet, error)
	FindByID(walletID int64) (*model.Wallet, error)
	FindByUser(userID string) ([]*model.Wallet, error)
	FindByInviteCode(code string) (*model.Wallet, error)
	Delete(walletID int64) error

	AddMember(walletID int64, userID string, role string) error
	RemoveMember(walletID int64, userID string) error
	GetMembers(walletID int64) ([]*model.WalletMember, error)
	IsMember(walletID int64, userID string) (bool, error)
	GetMemberRole(walletID int64, userID string) (string, error)
	GetMembersWithDetails(walletID int64) ([]*WalletMemberWithDetails, error)

	AddWalletTransaction(walletTx *model.WalletTransaction, splits []*model.WalletTransactionSplit) error
	RemoveWalletTransaction(walletTxID int64) error
	GetWalletTransactions(walletID int64) ([]*WalletTransactionWithDetails, error)
	FindWalletTransactionByID(walletTxID int64) (*model.WalletTransaction, error)

	AddSettlement(settlement *model.WalletSettlement) error
	GetSettlements(walletID int64) ([]*model.WalletSettlement, error)
}

type databaseWalletRepository struct {
	db *sql.DB
}

func NewWalletRepository(s database.Service) IWalletRepository {
	return &databaseWalletRepository{
		db: s.DB(),
	}
}

// --- Wallets ---

func (d *databaseWalletRepository) Create(wallet *model.Wallet) (*model.Wallet, error) {
	err := d.db.QueryRow(
		"INSERT INTO wallets (created_by, name) VALUES ($1, $2) RETURNING id, created_by, name, invite_code, created_at",
		wallet.CreatedBy, wallet.Name,
	).Scan(&wallet.ID, &wallet.CreatedBy, &wallet.Name, &wallet.InviteCode, &wallet.CreatedAt)
	return wallet, err
}

func (d *databaseWalletRepository) FindByID(walletID int64) (*model.Wallet, error) {
	var w model.Wallet
	err := d.db.QueryRow("SELECT id, created_by, name, invite_code, created_at FROM wallets WHERE id = $1", walletID).
		Scan(&w.ID, &w.CreatedBy, &w.Name, &w.InviteCode, &w.CreatedAt)
	return &w, err
}

func (d *databaseWalletRepository) FindByUser(userID string) ([]*model.Wallet, error) {
	rows, err := d.db.Query(`
SELECT w.id, w.created_by, w.name, w.invite_code, w.created_at
FROM wallets w JOIN wallet_members wm ON w.id = wm.wallet_id WHERE wm.user_id = $1`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var wallets []*model.Wallet
	for rows.Next() {
		var w model.Wallet
		if err := rows.Scan(&w.ID, &w.CreatedBy, &w.Name, &w.InviteCode, &w.CreatedAt); err != nil {
			log.Println(err)
			continue
		}
		wallets = append(wallets, &w)
	}
	return wallets, nil
}

func (d *databaseWalletRepository) FindByInviteCode(code string) (*model.Wallet, error) {
	var w model.Wallet
	err := d.db.QueryRow("SELECT id, created_by, name, invite_code, created_at FROM wallets WHERE invite_code = $1", code).
		Scan(&w.ID, &w.CreatedBy, &w.Name, &w.InviteCode, &w.CreatedAt)
	return &w, err
}

func (d *databaseWalletRepository) Delete(walletID int64) error {
	_, err := d.db.Exec("DELETE FROM wallets WHERE id = $1", walletID)
	return err
}

// --- Members ---

func (d *databaseWalletRepository) AddMember(walletID int64, userID string, role string) error {
	_, err := d.db.Exec("INSERT INTO wallet_members (wallet_id, user_id, role) VALUES ($1, $2, $3)", walletID, userID, role)
	return err
}

func (d *databaseWalletRepository) RemoveMember(walletID int64, userID string) error {
	_, err := d.db.Exec("DELETE FROM wallet_members WHERE wallet_id = $1 AND user_id = $2", walletID, userID)
	return err
}

func (d *databaseWalletRepository) GetMembers(walletID int64) ([]*model.WalletMember, error) {
	rows, err := d.db.Query("SELECT id, wallet_id, user_id, role, joined_at FROM wallet_members WHERE wallet_id = $1", walletID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var members []*model.WalletMember
	for rows.Next() {
		var m model.WalletMember
		if err := rows.Scan(&m.ID, &m.WalletID, &m.UserID, &m.Role, &m.JoinedAt); err != nil {
			log.Println(err)
			continue
		}
		members = append(members, &m)
	}
	return members, nil
}

func (d *databaseWalletRepository) IsMember(walletID int64, userID string) (bool, error) {
	var exists bool
	err := d.db.QueryRow("SELECT EXISTS(SELECT 1 FROM wallet_members WHERE wallet_id = $1 AND user_id = $2)", walletID, userID).Scan(&exists)
	return exists, err
}

func (d *databaseWalletRepository) GetMemberRole(walletID int64, userID string) (string, error) {
	var role string
	err := d.db.QueryRow("SELECT role FROM wallet_members WHERE wallet_id = $1 AND user_id = $2", walletID, userID).Scan(&role)
	if err == sql.ErrNoRows {
		return "", nil
	}
	return role, err
}

// --- Transactions ---

func (d *databaseWalletRepository) AddWalletTransaction(walletTx *model.WalletTransaction, splits []*model.WalletTransactionSplit) error {
	tx, err := d.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	err = tx.QueryRow(
		"INSERT INTO wallet_transactions (wallet_id, transaction_id) VALUES ($1, $2) RETURNING id, added_at",
		walletTx.WalletID, walletTx.TransactionID,
	).Scan(&walletTx.ID, &walletTx.AddedAt)
	if err != nil {
		return err
	}

	for _, split := range splits {
		_, err = tx.Exec(
			"INSERT INTO wallet_transaction_splits (wallet_tx_id, user_id, share) VALUES ($1, $2, $3)",
			walletTx.ID, split.UserID, split.Share,
		)
		if err != nil {
			return err
		}
	}

	return tx.Commit()
}

func (d *databaseWalletRepository) RemoveWalletTransaction(walletTxID int64) error {
	_, err := d.db.Exec("DELETE FROM wallet_transactions WHERE id = $1", walletTxID)
	return err
}

func (d *databaseWalletRepository) FindWalletTransactionByID(walletTxID int64) (*model.WalletTransaction, error) {
	var wt model.WalletTransaction
	err := d.db.QueryRow(
		"SELECT id, wallet_id, transaction_id, added_at FROM wallet_transactions WHERE id = $1",
		walletTxID,
	).Scan(&wt.ID, &wt.WalletID, &wt.TransactionID, &wt.AddedAt)
	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("wallet transaction not found")
	}
	return &wt, err
}

func (d *databaseWalletRepository) GetWalletTransactions(walletID int64) ([]*WalletTransactionWithDetails, error) {
	// JOIN wallet_transactions and transactions
	query := `
		SELECT 
			wt.id, wt.wallet_id, wt.transaction_id, wt.added_at,
			t.id, t.title, t.price, t.date_made, t.owner_id, t.category_id, t.type
		FROM wallet_transactions wt
		JOIN transactions t ON wt.transaction_id = t.id
		WHERE wt.wallet_id = $1
	`
	rows, err := d.db.Query(query, walletID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var results []*WalletTransactionWithDetails
	for rows.Next() {
		var tx WalletTransactionWithDetails

		// Scan both wallet_transaction and transaction fields
		err := rows.Scan(
			&tx.ID, &tx.WalletID, &tx.TransactionID, &tx.AddedAt,
			&tx.Transaction.ID, &tx.Transaction.Title, &tx.Transaction.Price,
			&tx.Transaction.DateMade, &tx.Transaction.OwnerId,
			&tx.Transaction.CategoryId, &tx.Transaction.Type,
		)
		if err != nil {
			continue // In production, log this error
		}

		// Fetch the associated splits
		splitRows, err := d.db.Query(
			"SELECT id, wallet_tx_id, user_id, share FROM wallet_transaction_splits WHERE wallet_tx_id = $1",
			tx.ID,
		)
		if err != nil {
			continue
		}

		var splits []*model.WalletTransactionSplit
		for splitRows.Next() {
			var s model.WalletTransactionSplit
			if err := splitRows.Scan(&s.ID, &s.WalletTxID, &s.UserID, &s.Share); err == nil {
				splits = append(splits, &s)
			}
		}
		splitRows.Close()

		tx.Splits = splits
		results = append(results, &tx)
	}
	return results, nil
}

func (d *databaseWalletRepository) GetMembersWithDetails(walletID int64) ([]*WalletMemberWithDetails, error) {
	rows, err := d.db.Query(`
		SELECT wm.user_id, u.first_name || ' ' || u.last_name AS name
		FROM wallet_members wm
		JOIN users u ON wm.user_id = u.id
		WHERE wm.wallet_id = $1
	`, walletID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var members []*WalletMemberWithDetails
	for rows.Next() {
		var m WalletMemberWithDetails
		if err := rows.Scan(&m.UserID, &m.Name); err != nil {
			log.Println(err)
			continue
		}
		members = append(members, &m)
	}
	return members, nil
}

// --- Settlements ---

func (d *databaseWalletRepository) AddSettlement(settlement *model.WalletSettlement) error {
	return d.db.QueryRow(
		"INSERT INTO wallet_settlements (wallet_id, from_user_id, to_user_id, amount) VALUES ($1, $2, $3, $4) RETURNING id, settled_at",
		settlement.WalletID, settlement.FromUserID, settlement.ToUserID, settlement.Amount,
	).Scan(&settlement.ID, &settlement.SettledAt)
}

func (d *databaseWalletRepository) GetSettlements(walletID int64) ([]*model.WalletSettlement, error) {
	rows, err := d.db.Query("SELECT id, wallet_id, from_user_id, to_user_id, amount, settled_at FROM wallet_settlements WHERE wallet_id = $1", walletID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var settlements []*model.WalletSettlement
	for rows.Next() {
		var s model.WalletSettlement
		if err := rows.Scan(&s.ID, &s.WalletID, &s.FromUserID, &s.ToUserID, &s.Amount, &s.SettledAt); err != nil {
			log.Println(err)
			continue
		}
		settlements = append(settlements, &s)
	}
	return settlements, nil
}
