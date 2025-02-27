package database

import (
	"os"
	"testing"
)

func TestNewConnection(t *testing.T) {
	_, err := NewConnection("invalid connection")
	if err == nil {
		t.Errorf("Expecting an error")
	}

	db, err := NewConnection(os.Getenv("DATABASE_URL"))
	if err != nil {
		t.Errorf("Unexpected connection error %q", err.Error())
	}

	if db.connection == nil {
		t.Errorf("DB connection should be established")
	}

	if db.logger == nil {
		t.Errorf("DB logger should be initialized")
	}
}
