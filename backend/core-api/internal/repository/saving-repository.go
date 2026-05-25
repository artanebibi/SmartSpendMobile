package repository

import (
	"SmartSpend/internal/database"
	"SmartSpend/internal/domain/model"
	"database/sql"
	"errors"
	"fmt"
	"log"
	"time"
)

type ISavingRepository interface {
	FindAll(userId string, from time.Time, to time.Time) []model.Saving
	FindById(id int64, userId string) (*model.Saving, error)
	Save(saving model.Saving) error
	Update(saving model.Saving, id int64) error
	Delete(id int64, userId string) error
}

type databaseSavingRepository struct {
	db *sql.DB
}

func NewSavingRepository(s database.Service) ISavingRepository {
	return &databaseSavingRepository{db: s.DB()}
}

func (d *databaseSavingRepository) FindAll(userId string, from time.Time, to time.Time) []model.Saving {
	rows, err := d.db.Query(`
		SELECT id, name, owner_id, amount, current_amount, "from", "to"
		FROM savings
		WHERE owner_id = $1 AND "from" >= $2 AND "from" <= $3
		ORDER BY "from" ASC
	`, userId, from, to)

	if err != nil {
		return nil
	}
	defer rows.Close()

	var savings []model.Saving
	for rows.Next() {
		var t model.Saving
		if err := rows.Scan(&t.ID, &t.Name, &t.OwnerId, &t.Amount, &t.CurrentAmount, &t.From, &t.To); err != nil {
			log.Println(err)
			continue
		}
		savings = append(savings, t)
	}
	return savings
}

func (d *databaseSavingRepository) FindById(id int64, userId string) (*model.Saving, error) {
	row := d.db.QueryRow(
		`SELECT id, name, owner_id, amount, current_amount, "from", "to" FROM savings WHERE id = $1 and owner_id = $2`,
		id, userId,
	)

	var saving model.Saving
	err := row.Scan(&saving.ID, &saving.Name, &saving.OwnerId, &saving.Amount, &saving.CurrentAmount, &saving.From, &saving.To)

	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, fmt.Errorf("saving not found")
		}
		return nil, fmt.Errorf("failed to scan saving: %v", err)
	}
	return &saving, nil
}

func (d *databaseSavingRepository) Save(saving model.Saving) error {
	tx, err := d.db.Begin()
	if err != nil {
		return err
	}
	defer func() {
		if err != nil {
			_ = tx.Rollback()
		}
	}()

	// 1. Insert Saving
	_, err = tx.Exec(`
		INSERT INTO savings (name, owner_id, amount, current_amount, "from", "to")
		VALUES ($1, $2, $3, $4, $5, $6)
	`, saving.Name, saving.OwnerId, saving.Amount, saving.CurrentAmount, saving.From, saving.To)
	if err != nil {
		return err
	}

	// 2. Deduct initial savings from user balance
	if saving.CurrentAmount > 0 {
		_, err = tx.Exec(`UPDATE users SET balance = balance - $1 WHERE id = $2`, saving.CurrentAmount, saving.OwnerId)
		if err != nil {
			return err
		}
	}

	return tx.Commit()
}

func (d *databaseSavingRepository) Update(saving model.Saving, id int64) error {
	tx, err := d.db.Begin()
	if err != nil {
		return err
	}
	defer func() {
		if err != nil {
			_ = tx.Rollback()
		}
	}()

	// 1. Get old data and lock the row to avoid race conditions
	var oldCurrent float32
	var oldOwnerID string
	err = tx.QueryRow(`
		SELECT current_amount, owner_id 
		FROM savings 
		WHERE id = $1 
		FOR UPDATE`,
		id,
	).Scan(&oldCurrent, &oldOwnerID)

	if err != nil {
		return err
	}

	// Calculate exactly how much extra money is moving into savings
	// If positive: money moves from user balance -> savings (balance drops)
	// If negative: money moves from savings -> user balance (balance rises)
	diff := saving.CurrentAmount - oldCurrent

	// 2. Perform the update
	_, err = tx.Exec(`
		UPDATE savings
		SET name = $1, amount = $2, current_amount = $3, "from" = $4, "to" = $5
		WHERE id = $6
	`, saving.Name, saving.Amount, saving.CurrentAmount, saving.From, saving.To, id)
	if err != nil {
		return err
	}

	// 3. Deduct the difference from the user's liquid account balance
	if diff != 0 {
		_, err = tx.Exec(`
			UPDATE users 
			SET balance = balance - $1 
			WHERE id = $2`,
			diff, oldOwnerID,
		)
		if err != nil {
			return err
		}
	}

	return tx.Commit()
}

func (d *databaseSavingRepository) Delete(id int64, userId string) error {
	tx, err := d.db.Begin()
	if err != nil {
		return err
	}
	defer func() {
		if err != nil {
			_ = tx.Rollback()
		}
	}()

	// 1. Fetch to get current_amount
	var currentAmount float32
	err = tx.QueryRow(`SELECT current_amount FROM savings WHERE id = $1 AND owner_id = $2`, id, userId).Scan(&currentAmount)
	if err != nil {
		return err
	}

	// 2. Delete Saving
	_, err = tx.Exec("DELETE FROM savings WHERE id = $1 AND owner_id = $2", id, userId)
	if err != nil {
		return err
	}

	// 3. Refund saved money back to liquid user balance
	if currentAmount > 0 {
		_, err = tx.Exec("UPDATE users SET balance = balance + $1 WHERE id = $2", currentAmount, userId)
		if err != nil {
			return err
		}
	}

	return tx.Commit()
}
