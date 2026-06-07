package model

import "time"

type Saving struct {
	ID            int64     `json:"id"`
	Name          string    `json:"name"`
	OwnerId       string    `json:"owner_id"`
	Amount        float32   `json:"amount"`
	CurrentAmount float32   `json:"current_amount"`
	From          time.Time `json:"from"`
	To            time.Time `json:"to"`
}
