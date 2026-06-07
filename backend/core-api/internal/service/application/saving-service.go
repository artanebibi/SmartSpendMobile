package application

import (
	"SmartSpend/internal/domain/dto"
	"SmartSpend/internal/domain/model"
	"SmartSpend/internal/repository"
	"fmt"
	"time"
)

type IApplicationSavingService interface {
	FindAll(userId string, from time.Time, to time.Time) []dto.SavingDto
	FindById(id int64, userId string) (*dto.SavingDto, error)
	Save(savingDto *dto.SavingDto) error
	CreateOrUpdate(savingDto *dto.SavingDto, userId string) (error, string)
	Delete(savingDto *dto.SavingDto, userId string) error
}

type ApplicationSavingService struct {
	savingRepository repository.ISavingRepository
}

func NewApplicationSavingService(repo repository.ISavingRepository) *ApplicationSavingService {
	return &ApplicationSavingService{
		savingRepository: repo,
	}
}

func mapToDtoSaving(s model.Saving) dto.SavingDto {
	return dto.SavingDto{
		ID:            s.ID,
		Name:          &s.Name,
		Amount:        &s.Amount,
		CurrentAmount: &s.CurrentAmount,
		From:          &s.From,
		To:            &s.To,
	}
}

func mapToModelSaving(dto *dto.SavingDto) model.Saving {
	s := model.Saving{
		ID:     dto.ID,
		Amount: *dto.Amount,
		From:   *dto.From,
		To:     *dto.To,
	}
	if dto.Name != nil {
		s.Name = *dto.Name
	}
	if dto.CurrentAmount != nil {
		s.CurrentAmount = *dto.CurrentAmount
	}
	return s
}

func (s *ApplicationSavingService) FindAll(userId string, from time.Time, to time.Time) []dto.SavingDto {
	savings := s.savingRepository.FindAll(userId, from, to)
	result := make([]dto.SavingDto, len(savings))
	for i, tx := range savings {
		result[i] = mapToDtoSaving(tx)
	}
	return result
}

func (s *ApplicationSavingService) FindById(id int64, userId string) (*dto.SavingDto, error) {
	tx, err := s.savingRepository.FindById(id, userId)
	if err != nil {
		return nil, err
	}
	savingDto := mapToDtoSaving(*tx)
	return &savingDto, nil
}

func (s *ApplicationSavingService) Save(savingDto *dto.SavingDto) error {
	tx := mapToModelSaving(savingDto)
	if tx.From.IsZero() {
		tx.From = time.Now()
	}
	return s.savingRepository.Save(tx)
}

func (s *ApplicationSavingService) CreateOrUpdate(savingDto *dto.SavingDto, userId string) (error, string) {
	if savingDto.ID != 0 { // Update process
		existing, err := s.savingRepository.FindById(savingDto.ID, userId)
		if err != nil {
			return err, "Saving goal not found"
		}

		// Hydrate existing model data with incoming partial patch fields
		saving := *existing

		if savingDto.Name != nil {
			saving.Name = *savingDto.Name
		}
		if savingDto.Amount != nil {
			saving.Amount = *savingDto.Amount
		}
		if savingDto.CurrentAmount != nil {
			saving.CurrentAmount = *savingDto.CurrentAmount
		}
		if savingDto.From != nil {
			saving.From = *savingDto.From
		}
		if savingDto.To != nil {
			saving.To = *savingDto.To
		}

		// Execute update with fully hydrated model payload
		err = s.savingRepository.Update(saving, saving.ID)
		if err != nil {
			return err, err.Error()
		}
		return nil, fmt.Sprintf("Saving with id %d updated successfully", saving.ID)

	} else { // Create process
		if savingDto.Name == nil {
			return fmt.Errorf("name is required"), "Name is required for new saving"
		}
		if savingDto.Amount == nil {
			return fmt.Errorf("amount is required"), "Amount is required for new saving"
		}
		if savingDto.From == nil {
			return fmt.Errorf("from is required"), "From date is required for new saving"
		}
		if savingDto.To == nil {
			return fmt.Errorf("to is required"), "To date is required for new saving"
		}

		saving := model.Saving{
			OwnerId: userId,
			Name:    *savingDto.Name,
			Amount:  *savingDto.Amount,
			From:    *savingDto.From,
			To:      *savingDto.To,
		}

		if savingDto.CurrentAmount != nil {
			saving.CurrentAmount = *savingDto.CurrentAmount
		}

		err := s.savingRepository.Save(saving)
		if err != nil {
			return err, err.Error()
		}
		return nil, "Saving successfully created."
	}
}

func (s *ApplicationSavingService) Delete(savingDto *dto.SavingDto, userId string) error {
	return s.savingRepository.Delete(savingDto.ID, userId)
}
