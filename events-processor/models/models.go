package models

import (
	"github.com/getlago/lago/events-processor/config/database"
)

const ERROR_NOT_FOUND string = "record not found"

type ApiStore struct {
	db *database.DB
}

func NewApiStore(db *database.DB) *ApiStore {
	return &ApiStore{
		db: db,
	}
}
