package models

import (
	"testing"

	"github.com/DATA-DOG/go-sqlmock"

	"github.com/getlago/lago/events-processor/tests"
)

func setupApiStore(t *testing.T) (*ApiStore, sqlmock.Sqlmock, func()) {
	mock, delete := tests.SetupMockStore(t)

	store := &ApiStore{
		db: mock.DB,
	}

	return store, mock.SQLMock, delete
}
