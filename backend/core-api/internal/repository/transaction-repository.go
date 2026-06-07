package repository

import (
	"SmartSpend/internal/database"
	"SmartSpend/internal/domain/enum"
	"SmartSpend/internal/domain/model"
	"database/sql"
	"errors"
	"fmt"
	"log"
	"time"
)

type ITransactionRepository interface {
	FindAll(userId string, from time.Time, to time.Time) []model.Transaction
	FindById(id int64, userId string) (*model.Transaction, error)
	Save(transaction *model.Transaction) error
	Update(transaction model.Transaction, id int64) error
	Delete(id int64, userId string) error
}

type databaseTransactionRepository struct {
	db *sql.DB
}

func NewTransactionRepository(s database.Service) ITransactionRepository {
	return &databaseTransactionRepository{
		db: s.DB(),
	}
}

func (d *databaseTransactionRepository) Save(transaction *model.Transaction) error {
	log.Println("Saving transaction:", transaction.Title)

	if transaction.Price <= 0 {
		return errors.New("transaction price must be greater than zero")
	}

	tx, err := d.db.Begin()
	if err != nil {
		return err
	}
	defer func() {
		if err != nil {
			_ = tx.Rollback()
		}
	}()

	var categoryId *int64
	var balanceAdjustment float32

	if transaction.Type == enum.Income {
		categoryId = nil
		balanceAdjustment = transaction.Price
	} else {
		categoryId = transaction.CategoryId
		balanceAdjustment = -transaction.Price
	}

	err = tx.QueryRow(`
		INSERT INTO transactions (title, price, date_made, owner_id, category_id, type)
		VALUES ($1, $2, $3, $4, $5, $6) RETURNING id
	`, transaction.Title, transaction.Price, transaction.DateMade, transaction.OwnerId, categoryId, transaction.Type).Scan(&transaction.ID)

	if err != nil {
		return err
	}

	_, err = tx.Exec(`
		UPDATE users SET balance = balance + $1 WHERE id = $2
	`, balanceAdjustment, transaction.OwnerId)

	if err != nil {
		return err
	}

	return tx.Commit()
}

func (d *databaseTransactionRepository) Update(transaction model.Transaction, id int64) error {
	log.Println("Updating transaction:", transaction)

	if transaction.Price <= 0 {
		return errors.New("transaction price must be greater than zero")
	}

	tx, err := d.db.Begin()
	if err != nil {
		return err
	}
	defer func() {
		if err != nil {
			_ = tx.Rollback()
		}
	}()

	var oldPrice float32
	var oldType string
	var ownerId string
	err = tx.QueryRow(`SELECT price, type, owner_id FROM transactions WHERE id = $1`, id).Scan(&oldPrice, &oldType, &ownerId)
	if err != nil {
		return err
	}

	var categoryId *int64
	if transaction.Type == enum.Expense {
		categoryId = transaction.CategoryId
	}

	_, err = tx.Exec(
		`UPDATE transactions
         SET title = $1, price = $2, date_made = $3, category_id = $4, "type" = $5
         WHERE id = $6`,
		transaction.Title, transaction.Price, transaction.DateMade,
		categoryId, transaction.Type, id,
	)
	if err != nil {
		return err
	}

	var balanceAdjustment float32
	if oldType == "Expense" {
		balanceAdjustment += oldPrice
	} else if oldType == "Income" {
		balanceAdjustment -= oldPrice
	}

	if transaction.Type == "Expense" {
		balanceAdjustment -= transaction.Price
	} else if transaction.Type == "Income" {
		balanceAdjustment += transaction.Price
	}

	_, err = tx.Exec(`
		UPDATE users SET balance = balance + $1 WHERE id = $2
	`, balanceAdjustment, ownerId)

	if err != nil {
		return err
	}

	return tx.Commit()
}

func (d *databaseTransactionRepository) Delete(id int64, userId string) error {
	tx, err := d.db.Begin()
	if err != nil {
		return err
	}
	defer func() {
		if err != nil {
			_ = tx.Rollback()
		}
	}()

	var tPrice float32
	var tType string

	err = tx.QueryRow(`SELECT price, type FROM transactions WHERE id = $1 AND owner_id = $2`, id, userId).Scan(&tPrice, &tType)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			err = fmt.Errorf("transaction not found")
		}
		return err
	}

	_, err = tx.Exec("DELETE FROM transactions WHERE id = $1 AND owner_id = $2", id, userId)
	if err != nil {
		return err
	}

	var balanceAdjustment float32
	if tType == "Expense" {
		balanceAdjustment += tPrice
	} else if tType == "Income" {
		balanceAdjustment -= tPrice
	}

	_, err = tx.Exec(`
		UPDATE users SET balance = balance + $1 WHERE id = $2
	`, balanceAdjustment, userId)

	if err != nil {
		return err
	}

	return tx.Commit()
}

func (d *databaseTransactionRepository) FindAll(userId string, from time.Time, to time.Time) []model.Transaction {
	rows, err := d.db.Query(`
       SELECT id, title, price, date_made, owner_id, category_id, "type"
       FROM transactions
       WHERE owner_id = $1
         AND date_made >= $2
         AND date_made <= $3
       ORDER BY date_made ASC
    `, userId, from, to)

	if err != nil {
		return nil
	}
	defer rows.Close()

	var transactions []model.Transaction
	for rows.Next() {
		var t model.Transaction
		if err := rows.Scan(&t.ID, &t.Title, &t.Price, &t.DateMade, &t.OwnerId, &t.CategoryId, &t.Type); err != nil {
			log.Println(err)
			continue
		}
		transactions = append(transactions, t)
	}
	return transactions
}

func (d *databaseTransactionRepository) FindById(id int64, userId string) (*model.Transaction, error) {
	row := d.db.QueryRow(
		`SELECT * FROM transactions WHERE id = $1 and owner_id = $2`,
		id, userId,
	)

	var transaction model.Transaction
	err := row.Scan(
		&transaction.ID,
		&transaction.Title,
		&transaction.Price,
		&transaction.DateMade,
		&transaction.OwnerId,
		&transaction.CategoryId,
		&transaction.Type,
	)

	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, fmt.Errorf("transaction not found")
		}
		return nil, fmt.Errorf("failed to scan transaction: %v", err)
	}

	return &transaction, nil
}
