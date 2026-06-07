package repository

import (
	"SmartSpend/internal/database"
	"SmartSpend/internal/domain/model"
	"database/sql"
	"log"
)

type ITransactionLocationRepository interface {
	Save(loc *model.TransactionLocation) error
}

type databaseTransactionLocationRepository struct {
	db *sql.DB
}

func NewTransactionLocationRepository(s database.Service) ITransactionLocationRepository {
	return &databaseTransactionLocationRepository{
		db: s.DB(),
	}
}

func (r *databaseTransactionLocationRepository) Save(loc *model.TransactionLocation) error {
	query := `INSERT INTO transaction_location (transaction_id, address, city, lat, lng) 
              VALUES ($1, $2, $3, $4, $5) RETURNING id`
		
	err := r.db.QueryRow(query, loc.TransactionID, loc.Address, loc.City, loc.Lat, loc.Lng).Scan(&loc.ID)
	if err != nil {
		log.Printf("Failed to insert transaction location: %v", err)
		return err
	}
	return nil
}
