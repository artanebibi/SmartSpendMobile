package domain

import (
	"SmartSpend/internal/domain/model"
	"SmartSpend/internal/repository"
)

type ITransactionLocationService interface {
	Save(loc *model.TransactionLocation) error
}

type TransactionLocationService struct {
	repo repository.ITransactionLocationRepository
}

func NewTransactionLocationService(repo repository.ITransactionLocationRepository) *TransactionLocationService {
	return &TransactionLocationService{
		repo: repo,
	}
}

func (s *TransactionLocationService) Save(loc *model.TransactionLocation) error {
	return s.repo.Save(loc)
}
