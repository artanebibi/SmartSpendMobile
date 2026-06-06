package model

type TransactionLocation struct {
	ID            int64   `json:"id"`
	TransactionID int64   `json:"transaction_id"`
	Address       string  `json:"address"`
	City          string  `json:"city"`
	Lat           float64 `json:"lat"`
	Lng           float64 `json:"lng"`
}
