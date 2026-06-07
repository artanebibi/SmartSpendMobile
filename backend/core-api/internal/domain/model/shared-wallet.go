package model

import (
	"time"
)

type Wallet struct {
	ID         int64     `db:"id" json:"id"`
	CreatedBy  string    `db:"created_by" json:"created_by"`
	Name       string    `db:"name" json:"name"`
	InviteCode string    `db:"invite_code" json:"invite_code"`
	CreatedAt  time.Time `db:"created_at" json:"created_at"`
}

type WalletMember struct {
	ID       int64     `db:"id" json:"id"`
	WalletID int64     `db:"wallet_id" json:"wallet_id"`
	UserID   string    `db:"user_id" json:"user_id"`
	Role     string    `db:"role" json:"role"`
	JoinedAt time.Time `db:"joined_at" json:"joined_at"`
}

type WalletTransaction struct {
	ID            int64     `db:"id" json:"id"`
	WalletID      int64     `db:"wallet_id" json:"wallet_id"`
	TransactionID int       `db:"transaction_id" json:"transaction_id"`
	AddedAt       time.Time `db:"added_at" json:"added_at"`
}

type WalletTransactionSplit struct {
	ID         int64   `db:"id" json:"id"`
	WalletTxID int64   `db:"wallet_tx_id" json:"wallet_tx_id"`
	UserID     string  `db:"user_id" json:"user_id"`
	Share      float64 `db:"share" json:"share"`
}

type WalletSettlement struct {
	ID         int64     `db:"id" json:"id"`
	WalletID   int64     `db:"wallet_id" json:"wallet_id"`
	FromUserID string    `db:"from_user_id" json:"from_user_id"`
	ToUserID   string    `db:"to_user_id" json:"to_user_id"`
	Amount     float64   `db:"amount" json:"amount"`
	SettledAt  time.Time `db:"settled_at" json:"settled_at"`
}
