package dto

import "time"

type SavingDto struct {
	ID            int64      `json:"id"`
	Name          *string    `json:"name"`
	Amount        *float32   `json:"amount"`
	CurrentAmount *float32   `json:"current_amount"`
	From          *time.Time `json:"from"`
	To            *time.Time `json:"to"`
}
